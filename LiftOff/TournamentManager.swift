// TournamentManager.swift
// Picksy
//
// Manages weekly group tournaments (3–10 players).
// Metric: cumulative screen time (seconds) — lower is better.
// Late joiners receive a penalty equal to the current group average,
// keeping the leaderboard fair for early participants.

import Foundation

// MARK: - Models

enum TournamentStatus: String, Codable {
    case active    = "active"
    case completed = "completed"
}

struct TournamentRecord: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    let inviteCode: String
    let createdBy: String
    let startsAt: Date
    let endsAt: Date
    var status: TournamentStatus
    let maxParticipants: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inviteCode      = "invite_code"
        case createdBy       = "created_by"
        case startsAt        = "starts_at"
        case endsAt          = "ends_at"
        case status
        case maxParticipants = "max_participants"
        case createdAt       = "created_at"
    }

    var isExpired: Bool { endsAt.timeIntervalSinceNow <= 0 }
    var daysRemaining: Int { max(0, Int(ceil(endsAt.timeIntervalSinceNow / 86400))) }
}

struct TournamentParticipant: Codable, Identifiable, Equatable {
    let id: String
    let tournamentId: String
    let deviceId: String
    var displayName: String
    var totalScreenTimeSeconds: Int
    var penaltySeconds: Int
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tournamentId             = "tournament_id"
        case deviceId                 = "device_id"
        case displayName              = "display_name"
        case totalScreenTimeSeconds   = "total_screen_time_seconds"
        case penaltySeconds           = "penalty_seconds"
        case joinedAt                 = "joined_at"
    }

    /// The score used for ranking — lower is better.
    var effectiveScore: Int { totalScreenTimeSeconds + penaltySeconds }

    var isMe: Bool { deviceId == TournamentManager.shared.myDeviceID }

    /// Rank-friendly formatted score (e.g. "3h 20m")
    var formattedScore: String { formatDuration(effectiveScore) }
}

// MARK: - TournamentManager

@Observable
class TournamentManager {

    static let shared = TournamentManager()

    var activeTournaments: [TournamentRecord] = []
    var participantsByTournament: [String: [TournamentParticipant]] = [:]
    var isLoading = false
    var errorMessage: String? = nil

    private static let supabaseURL     = "https://igbtosqmtdrxzmoblvpp.supabase.co"
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let str = try dec.singleValueContainer().decode(String.self)
            let frac = ISO8601DateFormatter()
            frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = frac.date(from: str) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(
                in: try dec.singleValueContainer(),
                debugDescription: "Cannot decode date: \(str)"
            )
        }
        return d
    }()

    var myDeviceID: String { FriendSyncManager.shared.deviceID }

    private var lastSyncedScreenTime: Int = -1
    private var lastPollDate: Date = .distantPast
    private let pollInterval: TimeInterval = 60

    private init() {}

    // MARK: - Public API

    /// Creates a new 7-day tournament and returns it.
    @MainActor
    func createTournament(name: String, myName: String) async -> TournamentRecord? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let code = generateInviteCode()
        let now  = Date()
        let ends = now.addingTimeInterval(7 * 24 * 3600)

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let body: [String: Any] = [
            "name":             name,
            "invite_code":      code,
            "created_by":       myDeviceID,
            "starts_at":        isoFrac.string(from: now),
            "ends_at":          isoFrac.string(from: ends),
            "max_participants": 10
        ]

        var req = makeRequest(url: URL(string: "\(Self.supabaseURL)/rest/v1/tournaments")!, method: "POST")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 201,
              let records = try? decoder.decode([TournamentRecord].self, from: data),
              let tournament = records.first
        else {
            errorMessage = "Failed to create tournament."
            return nil
        }

        // Join as first participant (no penalty for creator)
        let joined = await joinAsParticipant(tournamentId: tournament.id, myName: myName, penalty: 0)
        guard joined else {
            errorMessage = "Created tournament but failed to join it."
            return nil
        }

        activeTournaments.append(tournament)
        await syncScreenTime(DuelManager.suiteBestScreenTimeSecs())
        let initialParticipants = await fetchParticipants(tournamentId: tournament.id)
        participantsByTournament[tournament.id] = initialParticipants
        print("[Tournament] ✅ Created: \(tournament.inviteCode)")
        return tournament
    }

    /// Joins an existing tournament by invite code.
    @MainActor
    func joinTournament(code: String, myName: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let clean = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Fetch tournament by code
        var comps = URLComponents(string: "\(Self.supabaseURL)/rest/v1/tournaments")!
        comps.queryItems = [
            URLQueryItem(name: "invite_code", value: "eq.\(clean)"),
            URLQueryItem(name: "status",      value: "eq.active")
        ]
        guard let url = comps.url else { return false }

        var req = makeRequest(url: url, method: "GET")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let records = try? decoder.decode([TournamentRecord].self, from: data),
              let tournament = records.first
        else {
            errorMessage = "Tournament not found. Check the code and try again."
            return false
        }

        // Check not already joined
        let myID = myDeviceID
        let participants = await fetchParticipants(tournamentId: tournament.id)
        if participants.contains(where: { $0.deviceId == myID }) {
            errorMessage = "You're already in this tournament!"
            return false
        }

        // Check capacity
        if participants.count >= tournament.maxParticipants {
            errorMessage = "This tournament is full (\(tournament.maxParticipants) players max)."
            return false
        }

        // Penalty = current group average screen time (fair handicap for late joiners)
        let penalty = participants.isEmpty ? 0 :
            participants.map(\.totalScreenTimeSeconds).reduce(0, +) / participants.count

        let joined = await joinAsParticipant(tournamentId: tournament.id, myName: myName, penalty: penalty)
        guard joined else {
            errorMessage = "Failed to join tournament."
            return false
        }

        if !activeTournaments.contains(where: { $0.id == tournament.id }) {
            activeTournaments.append(tournament)
        }
        await syncScreenTime(DuelManager.suiteBestScreenTimeSecs())
        let updatedParticipants = await fetchParticipants(tournamentId: tournament.id)
        participantsByTournament[tournament.id] = updatedParticipants
        print("[Tournament] ✅ Joined: \(tournament.inviteCode), penalty=\(penalty)s")
        return true
    }

    /// Syncs today's screen time to all active tournaments.
    @MainActor
    func syncScreenTime(_ seconds: Int) async {
        let secs = max(seconds, DuelManager.suiteBestScreenTimeSecs())
        guard secs != lastSyncedScreenTime else { return }
        lastSyncedScreenTime = secs

        for tournament in activeTournaments where tournament.status == .active && !tournament.isExpired {
            let urlStr = "\(Self.supabaseURL)/rest/v1/tournament_participants"
                + "?tournament_id=eq.\(tournament.id)&device_id=eq.\(myDeviceID)"
            var req = makeRequest(url: URL(string: urlStr)!, method: "PATCH")
            req.setValue("return=representation", forHTTPHeaderField: "Prefer")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "total_screen_time_seconds": secs
            ])
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    /// Polls for updated leaderboards. Rate-limited to once per minute.
    func poll() async {
        let proceed = await MainActor.run { () -> Bool in
            guard Date().timeIntervalSince(lastPollDate) >= pollInterval else { return false }
            lastPollDate = Date()
            return true
        }
        guard proceed else { return }

        let myID = myDeviceID

        // Fetch tournaments where I'm a participant
        var comps = URLComponents(string: "\(Self.supabaseURL)/rest/v1/tournament_participants")!
        comps.queryItems = [
            URLQueryItem(name: "device_id", value: "eq.\(myID)"),
            URLQueryItem(name: "select",    value: "tournament_id")
        ]

        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(for: makeRequest(url: url, method: "GET")),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else { return }

        let myTournamentIDs = rows.compactMap { $0["tournament_id"] }
        guard !myTournamentIDs.isEmpty else { return }

        // Fetch those tournaments
        let idList = myTournamentIDs.joined(separator: ",")
        var tComps = URLComponents(string: "\(Self.supabaseURL)/rest/v1/tournaments")!
        tComps.queryItems = [
            URLQueryItem(name: "id",     value: "in.(\(idList))"),
            URLQueryItem(name: "status", value: "eq.active"),
            URLQueryItem(name: "order",  value: "created_at.desc")
        ]

        guard let tURL = tComps.url,
              let (tData, _) = try? await URLSession.shared.data(for: makeRequest(url: tURL, method: "GET")),
              let tournaments = try? decoder.decode([TournamentRecord].self, from: tData)
        else { return }

        // Fetch participants for each tournament
        var collected: [String: [TournamentParticipant]] = [:]
        for tournament in tournaments {
            collected[tournament.id] = await fetchParticipants(tournamentId: tournament.id)
        }
        let allParticipants = collected

        await MainActor.run {
            activeTournaments = tournaments
            participantsByTournament = allParticipants
        }

        // Finalize expired tournaments
        for tournament in tournaments where tournament.isExpired {
            await finalizeTournament(tournament)
        }

        print("[Tournament] 🔄 Poll: \(tournaments.count) active tournament(s)")
    }

    // MARK: - Private

    private func joinAsParticipant(tournamentId: String, myName: String, penalty: Int) async -> Bool {
        let body: [String: Any] = [
            "tournament_id":  tournamentId,
            "device_id":      myDeviceID,
            "display_name":   myName.isEmpty ? "A friend" : myName,
            "penalty_seconds": penalty
        ]
        var req = makeRequest(url: URL(string: "\(Self.supabaseURL)/rest/v1/tournament_participants")!, method: "POST")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse
        else { return false }
        return http.statusCode == 201
    }

    private func fetchParticipants(tournamentId: String) async -> [TournamentParticipant] {
        var comps = URLComponents(string: "\(Self.supabaseURL)/rest/v1/tournament_participants")!
        comps.queryItems = [
            URLQueryItem(name: "tournament_id", value: "eq.\(tournamentId)"),
            URLQueryItem(name: "order",         value: "total_screen_time_seconds.asc")
        ]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(for: makeRequest(url: url, method: "GET")),
              let participants = try? decoder.decode([TournamentParticipant].self, from: data)
        else { return [] }
        return participants
    }

    private func finalizeTournament(_ tournament: TournamentRecord) async {
        var req = makeRequest(
            url: URL(string: "\(Self.supabaseURL)/rest/v1/tournaments?id=eq.\(tournament.id)")!,
            method: "PATCH"
        )
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["status": "completed"])
        _ = try? await URLSession.shared.data(for: req)

        await MainActor.run {
            activeTournaments.removeAll { $0.id == tournament.id }
        }
        print("[Tournament] 🏁 Finalized: \(tournament.name)")

        // Notify all participants
        let participants = await fetchParticipants(tournamentId: tournament.id)
        let sorted = participants.sorted { $0.effectiveScore < $1.effectiveScore }
        guard let winner = sorted.first else { return }

        for (index, participant) in sorted.enumerated() {
            let title: String
            let body: String
            if participant.deviceId == winner.deviceId {
                title = "🏆 You won \(tournament.name)!"
                body  = "You had the least screen time this week. Well done!"
            } else {
                let rank = index + 1
                title = "Tournament over — you finished #\(rank)"
                body  = "\(winner.displayName) won \(tournament.name) this week!"
            }
            await sendPush(toDeviceID: participant.deviceId, title: title, body: body)
        }
    }

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let part  = String((0..<6).map { _ in chars.randomElement()! })
        return "\(part.prefix(3))-\(part.suffix(3))"
    }

    private func sendPush(toDeviceID: String, title: String, body: String) async {
        guard let url = URL(string: "\(Self.supabaseURL)/functions/v1/send-message") else { return }
        let payload: [String: Any] = ["device_id": toDeviceID, "title": title, "body": body]
        var req = makeRequest(url: url, method: "POST")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await URLSession.shared.data(for: req)
    }

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        return req
    }
}

// MARK: - Helpers

private func formatDuration(_ seconds: Int) -> String {
    let s = max(0, seconds)
    if s < 60 { return "0m" }
    let h = s / 3600
    let m = (s % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}
