// DuelManager.swift
// Picksy
//
// Manages same-day Pickup Duels between anonymous friend pairs.
// Winner = fewer pickups at 23:59 local time.
//
// PRIVACY MODEL: only anonymous device UUIDs travel to Supabase.
// No email, no real name — display names are whatever the user chose.

import Foundation

// MARK: - Supporting types

enum DuelStatus: String, Codable {
    case pending   = "pending"
    case active    = "active"
    case completed = "completed"
    case declined  = "declined"
}

struct DuelRecord: Codable, Identifiable {
    let id: String
    let challengerId: String
    let opponentId: String
    let challengerName: String
    let opponentName: String
    var status: DuelStatus
    var startedAt: Date?
    var endsAt: Date?
    var challengerPickups: Int
    var opponentPickups: Int
    var winnerId: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case challengerId    = "challenger_id"
        case opponentId      = "opponent_id"
        case challengerName  = "challenger_name"
        case opponentName    = "opponent_name"
        case status
        case startedAt       = "started_at"
        case endsAt          = "ends_at"
        case challengerPickups = "challenger_pickups"
        case opponentPickups   = "opponent_pickups"
        case winnerId        = "winner_id"
        case createdAt       = "created_at"
    }

    // MARK: Convenience

    var amChallenger: Bool { challengerId == DuelManager.shared.myDeviceID }
    var amOpponent:   Bool { opponentId   == DuelManager.shared.myDeviceID }

    var myPickups:    Int  { amChallenger ? challengerPickups : opponentPickups }
    var theirPickups: Int  { amChallenger ? opponentPickups   : challengerPickups }

    var myName:    String  { amChallenger ? challengerName : opponentName }
    var theirName: String  { amChallenger ? opponentName   : challengerName }

    var iWon: Bool {
        guard status == .completed, let winner = winnerId else { return false }
        return winner == DuelManager.shared.myDeviceID
    }
    var iLost: Bool {
        guard status == .completed, let winner = winnerId else { return false }
        return winner != DuelManager.shared.myDeviceID && winner != "tie"
    }
    var isTie: Bool { winnerId == "tie" }

    /// Seconds remaining until the duel ends. Negative if expired.
    var secondsRemaining: TimeInterval {
        guard let end = endsAt else { return 0 }
        return end.timeIntervalSinceNow
    }

    var isExpired: Bool { secondsRemaining <= 0 }
}

// MARK: - DuelManager

@Observable
class DuelManager {

    static let shared = DuelManager()

    // MARK: Published state
    /// The current active (or just-completed) duel for any pair.
    var activeDuel: DuelRecord?       = nil
    /// An incoming pending invite (I am the opponent).
    var pendingInvite: DuelRecord?    = nil
    /// A duel I sent that is still waiting for acceptance.
    var sentPendingDuel: DuelRecord?  = nil
    /// Completed duels from the last 7 days, newest first.
    var duelHistory: [DuelRecord]     = []

    // MARK: Rate limiting
    /// Minimum seconds between actual network polls (prevents timer pile-ups)
    private let pollInterval: TimeInterval = 12
    private var lastPollDate: Date = .distantPast
    /// Last pickup count successfully pushed to Supabase (avoids redundant PATCHes)
    private var lastSyncedPickups: Int = -1

    // MARK: Private
    private static let supabaseURL     = "https://igbtosqmtdrxzmoblvpp.supabase.co"
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let str = try dec.singleValueContainer().decode(String.self)
            // Try fractional-seconds ISO8601 first (Supabase default), then plain
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

    private init() {}

    // MARK: - Public API

    /// Creates a new pending duel and sends the opponent a push notification.
    func createDuel(
        opponent: RegisteredPair,
        myName: String,
        myCurrentPickups: Int
    ) async {
        let url = URL(string: "\(Self.supabaseURL)/rest/v1/duels")!
        let body: [String: Any] = [
            "challenger_id":      myDeviceID,
            "opponent_id":        opponent.deviceID,
            "challenger_name":    myName.isEmpty ? "A friend" : myName,
            "opponent_name":      opponent.name.isEmpty ? "A friend" : opponent.name,
            "status":             "pending"
        ]

        var req = makeRequest(url: url, method: "POST")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 201,
              let records = try? decoder.decode([DuelRecord].self, from: data),
              let created = records.first
        else {
            print("[Duel] ❌ Failed to create duel")
            return
        }

        await MainActor.run { sentPendingDuel = created }
        print("[Duel] ✅ Duel created: \(created.id.prefix(8))…")

        // Push notification to opponent
        await sendPush(
            toDeviceID: opponent.deviceID,
            title: "⚔️ \(myName.isEmpty ? "A friend" : myName) challenges you!",
            body: "Open Picksy to accept the duel — whoever uses their phone less wins."
        )
    }

    /// Accepts an incoming pending duel. Sets status → active, starts the timer.
    func acceptDuel(_ duel: DuelRecord, myName: String) async {
        let now    = Date()
        let cal    = Calendar.current
        // ends_at = 23:59:59 local time today
        let endOfDay = cal.date(
            bySettingHour: 23, minute: 59, second: 59, of: now
        ) ?? now.addingTimeInterval(86_399)

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let body: [String: Any] = [
            "status":        "active",
            "started_at":    isoFrac.string(from: now),
            "ends_at":       isoFrac.string(from: endOfDay),
            "opponent_name": myName.isEmpty ? "A friend" : myName
        ]

        let urlStr = "\(Self.supabaseURL)/rest/v1/duels?id=eq.\(duel.id)"
        var req = makeRequest(url: URL(string: urlStr)!, method: "PATCH")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let records = try? decoder.decode([DuelRecord].self, from: data),
              let updated = records.first
        else {
            print("[Duel] ❌ Failed to accept duel")
            return
        }

        await MainActor.run {
            activeDuel   = updated
            pendingInvite = nil
        }
        print("[Duel] ✅ Duel accepted, ends \(isoFrac.string(from: endOfDay))")

        await sendPush(
            toDeviceID: duel.challengerId,
            title: "✅ \(myName.isEmpty ? "Your friend" : myName) accepted the duel!",
            body: "The Pickup Duel has started — whoever uses their phone less today wins."
        )
    }

    /// Declines an incoming pending duel.
    func declineDuel(_ duel: DuelRecord) async {
        let urlStr = "\(Self.supabaseURL)/rest/v1/duels?id=eq.\(duel.id)"
        var req = makeRequest(url: URL(string: urlStr)!, method: "PATCH")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["status": "declined"])

        _ = try? await URLSession.shared.data(for: req)

        await MainActor.run { pendingInvite = nil }
        print("[Duel] 🚫 Duel declined: \(duel.id.prefix(8))…")
    }

    /// Cancels a pending duel that I sent (before the opponent accepts).
    func cancelSentDuel(_ duel: DuelRecord) async {
        let urlStr = "\(Self.supabaseURL)/rest/v1/duels?id=eq.\(duel.id)"
        var req = makeRequest(url: URL(string: urlStr)!, method: "PATCH")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["status": "declined"])

        _ = try? await URLSession.shared.data(for: req)

        await MainActor.run { sentPendingDuel = nil }
        print("[Duel] ❌ Sent duel cancelled: \(duel.id.prefix(8))…")
    }

    /// Updates my pickup count in the active duel. Called on every pickup event.
    func updateMyPickups(_ pickups: Int) async {
        guard let duel = activeDuel, duel.status == .active else { return }
        // Skip if nothing changed — avoids hammering Supabase on every timer tick
        guard pickups != lastSyncedPickups else { return }
        lastSyncedPickups = pickups

        let field = duel.amChallenger ? "challenger_pickups" : "opponent_pickups"
        let urlStr = "\(Self.supabaseURL)/rest/v1/duels?id=eq.\(duel.id)"
        var req = makeRequest(url: URL(string: urlStr)!, method: "PATCH")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [field: pickups])

        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, http.statusCode == 200,
           let records = try? decoder.decode([DuelRecord].self, from: data),
           let updated = records.first {
            await MainActor.run { activeDuel = updated }
        }
    }

    /// Polls Supabase for duel state. Call on app foreground and periodically.
    /// Rate-limited: at most one real network request per `pollInterval` seconds,
    /// enforced atomically on MainActor so concurrent Tasks can't race through.
    func poll() async {
        // Atomic check+set on MainActor prevents concurrent Tasks from all passing
        let proceed = await MainActor.run { () -> Bool in
            let now = Date()
            guard now.timeIntervalSince(self.lastPollDate) >= self.pollInterval else { return false }
            self.lastPollDate = now   // claim the slot before any other Task can
            return true
        }
        guard proceed else { return }

        let myID = myDeviceID

        // Fetch non-declined duels involving me, created in the last 2 days
        // Use URLComponents for safe encoding of the or() filter
        guard var comps = URLComponents(string: "\(Self.supabaseURL)/rest/v1/duels") else { return }

        // 7 days ago in ISO8601 (covers history shown in Stats)
        let cutoff = ISO8601DateFormatter()
        cutoff.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let since = cutoff.string(from: Date().addingTimeInterval(-7 * 24 * 3600))

        comps.queryItems = [
            URLQueryItem(name: "or",         value: "(challenger_id.eq.\(myID),opponent_id.eq.\(myID))"),
            URLQueryItem(name: "status",     value: "neq.declined"),
            URLQueryItem(name: "created_at", value: "gte.\(since)"),
            URLQueryItem(name: "order",      value: "created_at.desc"),
            URLQueryItem(name: "limit",      value: "20")
        ]

        guard let pollURL = comps.url else { return }

        var pollReq = makeRequest(url: pollURL, method: "GET")
        pollReq.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, _) = try? await URLSession.shared.data(for: pollReq),
              let duels = try? decoder.decode([DuelRecord].self, from: data)
        else {
            print("[Duel] ⚠️ Poll failed")
            return
        }

        let activeCount = duels.filter { $0.status == .active }.count
        print("[Duel] 🔄 Poll: \(duels.count) record(s) total (\(activeCount) active)")

        // Finalize any expired active duels
        for duel in duels where duel.status == .active && duel.isExpired {
            await finalizeDuel(duel)
        }

        // Re-fetch after potential finalization
        let pollReq2 = makeRequest(url: pollURL, method: "GET")
        guard let (data2, _) = try? await URLSession.shared.data(for: pollReq2),
              let freshDuels = try? decoder.decode([DuelRecord].self, from: data2)
        else { return }

        let todayStart = Calendar.current.startOfDay(for: Date())

        let myActiveDuel = freshDuels.first { d -> Bool in
            if d.status == .active { return true }
            if d.status == .completed { return d.createdAt >= todayStart }
            return false
        }

        let previouslyHadActiveDuel = await MainActor.run { activeDuel?.status == .active }

        await MainActor.run {
            activeDuel = myActiveDuel

            // Incoming pending invite (I am the opponent)
            pendingInvite = freshDuels.first {
                $0.status == .pending && $0.opponentId == myID
            }

            // My sent pending duel (I am the challenger)
            sentPendingDuel = freshDuels.first {
                $0.status == .pending && $0.challengerId == myID
            }

            // History: all completed duels, newest first
            duelHistory = freshDuels
                .filter { $0.status == .completed }
                .sorted { $0.createdAt > $1.createdAt }
        }

        // If we just discovered an active duel for the first time, sync our pickup count.
        // The lastSyncedPickups guard in updateMyPickups prevents redundant PATCHes.
        if myActiveDuel?.status == .active, !previouslyHadActiveDuel {
            let pickups = UserDefaults.standard.integer(forKey: "todayPickups")
            await updateMyPickups(pickups)
        }
    }

    /// Bypasses rate limiting and forces an immediate poll.
    /// Use only from background wake-up handlers (e.g. silent push) where
    /// we need fresh duel state before updating the Live Activity.
    func forcePoll() async {
        await MainActor.run { self.lastPollDate = .distantPast }
        await poll()
    }

    // MARK: - Private

    private func finalizeDuel(_ duel: DuelRecord) async {
        let winner: String
        if duel.challengerPickups < duel.opponentPickups {
            winner = duel.challengerId
        } else if duel.opponentPickups < duel.challengerPickups {
            winner = duel.opponentId
        } else {
            winner = "tie"
        }

        let urlStr = "\(Self.supabaseURL)/rest/v1/duels?id=eq.\(duel.id)"
        var req = makeRequest(url: URL(string: urlStr)!, method: "PATCH")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "status":    "completed",
            "winner_id": winner
        ])
        _ = try? await URLSession.shared.data(for: req)
        print("[Duel] 🏁 Finalized: winner=\(winner.prefix(8))…")

        // Notify LiftOffApp to clear the duel state from the Dynamic Island.
        // DuelManager can't access LiveActivityManager directly (no singleton),
        // so we use NotificationCenter as the bridge.
        await MainActor.run {
            NotificationCenter.default.post(name: .picksyDuelFinalized, object: nil)
        }

        // Notify both players
        if winner == "tie" {
            await sendPush(toDeviceID: duel.challengerId, title: "🤝 It's a tie!", body: "You and \(duel.opponentName) are equally disciplined today.")
            await sendPush(toDeviceID: duel.opponentId,   title: "🤝 It's a tie!", body: "You and \(duel.challengerName) are equally disciplined today.")
        } else {
            let loserId    = winner == duel.challengerId ? duel.opponentId    : duel.challengerId
            let winnerName = winner == duel.challengerId ? duel.challengerName : duel.opponentName
            let loserName  = winner == duel.challengerId ? duel.opponentName  : duel.challengerName
            await sendPush(toDeviceID: winner,  title: "🏆 You won the duel!", body: "You picked up less than \(loserName) today. Nice discipline!")
            await sendPush(toDeviceID: loserId, title: "📱 Duel over",          body: "\(winnerName) used their phone less than you today. Try again tomorrow!")
        }
    }

    private func sendPush(toDeviceID: String, title: String, body: String) async {
        guard let fnURL = URL(string: "\(Self.supabaseURL)/functions/v1/send-message") else { return }
        let payload: [String: Any] = [
            "device_id": toDeviceID,
            "title":     title,
            "body":      body
        ]
        var req = makeRequest(url: fnURL, method: "POST")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await URLSession.shared.data(for: req)
        print("[Duel] 📤 Push sent to \(toDeviceID.prefix(8))…")
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
