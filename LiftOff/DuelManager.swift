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

struct DuelRecord: Codable, Identifiable, Equatable {
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
    var challengerScreenTime: Int   // seconds
    var opponentScreenTime: Int     // seconds
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
        case challengerPickups    = "challenger_pickups"
        case opponentPickups      = "opponent_pickups"
        case challengerScreenTime = "challenger_screen_time"
        case opponentScreenTime   = "opponent_screen_time"
        case winnerId        = "winner_id"
        case createdAt       = "created_at"
    }

    // MARK: Convenience

    var amChallenger: Bool { challengerId == DuelManager.shared.myDeviceID }
    var amOpponent:   Bool { opponentId   == DuelManager.shared.myDeviceID }

    var myPickups:    Int  { amChallenger ? challengerPickups : opponentPickups }
    var theirPickups: Int  { amChallenger ? opponentPickups   : challengerPickups }

    var myScreenTime:    Int { amChallenger ? challengerScreenTime : opponentScreenTime }
    var theirScreenTime: Int { amChallenger ? opponentScreenTime   : challengerScreenTime }

    // Picksy Score: lower = better. pickups + screen_time_minutes × 5
    // Screen time weighted 5× because prolonged use is the real problem.
    var myScore:    Int { myPickups + (myScreenTime / 60) * 5 }
    var theirScore: Int { theirPickups + (theirScreenTime / 60) * 5 }

    var myName:       String { amChallenger ? challengerName : opponentName }
    var theirName:    String { amChallenger ? opponentName   : challengerName }
    var theirDeviceID: String { amChallenger ? opponentId    : challengerId }

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
    /// All currently active duels (one per friend pair, same day).
    var activeDuels: [DuelRecord]     = []
    /// Convenience: the first active duel, for backward-compat with DI / LiftOffApp code.
    var activeDuel: DuelRecord?       { activeDuels.first }
    /// Completed duels from the last 7 days, newest first.
    var duelHistory: [DuelRecord]     = []

    // MARK: Rate limiting
    /// Minimum seconds between polls when no duel is active.
    private let pollInterval: TimeInterval = 12
    /// During an active duel we poll every 5 s so scores feel near-realtime.
    private var effectivePollInterval: TimeInterval {
        activeDuels.isEmpty ? pollInterval : 5.0
    }
    private var lastPollDate: Date = .distantPast
    /// Last pickup count successfully pushed to Supabase (avoids redundant PATCHes)
    private var lastSyncedPickups: Int = -1

    /// Duel IDs currently being finalized — prevents duplicate push notifications
    /// when multiple concurrent polls both see the same expired duel.
    private var finalizingDuelIDs: Set<String> = []

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

    /// Creates a new duel, starts it immediately, and notifies the opponent.
    func createDuel(
        opponent: RegisteredPair,
        myName: String,
        myCurrentPickups: Int
    ) async {
        let now      = Date()
        let cal      = Calendar.current
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: now)
                       ?? now.addingTimeInterval(86_399)

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let url = URL(string: "\(Self.supabaseURL)/rest/v1/duels")!
        let body: [String: Any] = [
            "challenger_id":      myDeviceID,
            "opponent_id":        opponent.deviceID,
            "challenger_name":    myName.isEmpty ? "A friend" : myName,
            "opponent_name":      opponent.name.isEmpty ? "A friend" : opponent.name,
            "status":             "active",
            "started_at":         isoFrac.string(from: now),
            "ends_at":            isoFrac.string(from: endOfDay),
            "challenger_pickups": myCurrentPickups
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

        await MainActor.run {
            if !activeDuels.contains(where: { $0.id == created.id }) {
                activeDuels.append(created)
            }
            lastSyncedPickups = -1
        }
        print("[Duel] ✅ Duel started: \(created.id.prefix(8))…")

        // Sync pickup count immediately since we're now active
        await updateMyPickups(myCurrentPickups)

        // Push notification to opponent
        let name = myName.isEmpty ? "A friend" : myName
        await sendPush(
            toDeviceID: opponent.deviceID,
            title: "⚔️ \(name) started a duel with you!",
            body: "You're in — fewer pickups by midnight wins 🏆 Open Picksy to see the score."
        )

        // Silent push so the opponent's app wakes up immediately in the background
        // and uploads their current pickup count — otherwise we'd see 0 until they open the app.
        await sendPush(toDeviceID: opponent.deviceID, title: "", body: "", silent: true)
    }

    /// Cancels a specific active duel. Sets status → "declined" so it disappears from both players' polls.
    func cancelActiveDuel(_ duel: DuelRecord) async {
        guard duel.status == .active else { return }
        let urlStr = "\(Self.supabaseURL)/rest/v1/duels?id=eq.\(duel.id)"
        var req = makeRequest(url: URL(string: urlStr)!, method: "PATCH")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["status": "declined"])

        _ = try? await URLSession.shared.data(for: req)

        await MainActor.run {
            activeDuels.removeAll { $0.id == duel.id }
            if activeDuels.isEmpty {
                NotificationCenter.default.post(name: .picksyDuelFinalized, object: nil)
            }
        }
        print("[Duel] 🚫 Active duel cancelled: \(duel.id.prefix(8))…")
    }

    /// Updates my pickup count + screen time across ALL active duels.
    // H8 fix: @MainActor ensures lastSyncedPickups and activeDuels are read/written
    // on the correct actor, preventing data races between concurrent callers.
    @MainActor
    func updateMyPickups(_ pickups: Int, screenTimeSeconds: Int = 0) async {
        guard !activeDuels.isEmpty else { return }
        // Skip if nothing changed — avoids hammering Supabase on every timer tick
        guard pickups != lastSyncedPickups else { return }
        lastSyncedPickups = pickups

        for duel in activeDuels where duel.status == .active {
            let pickupsField    = duel.amChallenger ? "challenger_pickups"     : "opponent_pickups"
            let screenTimeField = duel.amChallenger ? "challenger_screen_time" : "opponent_screen_time"
            let urlStr = "\(Self.supabaseURL)/rest/v1/duels?id=eq.\(duel.id)"
            var req = makeRequest(url: URL(string: urlStr)!, method: "PATCH")
            req.setValue("return=representation", forHTTPHeaderField: "Prefer")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                pickupsField:    pickups,
                screenTimeField: screenTimeSeconds
            ])

            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let records = try? decoder.decode([DuelRecord].self, from: data),
               let updated = records.first {
                await MainActor.run {
                    activeDuels = activeDuels.map { $0.id == updated.id ? updated : $0 }
                }
            }
        }
    }

    /// Polls Supabase for duel state. Call on app foreground and periodically.
    /// Rate-limited: at most one real network request per `pollInterval` seconds,
    /// enforced atomically on MainActor so concurrent Tasks can't race through.
    func poll() async {
        // Atomic check+set on MainActor prevents concurrent Tasks from all passing
        let proceed = await MainActor.run { () -> Bool in
            let now = Date()
            // Use shorter interval during active duels for near-realtime score updates
            guard now.timeIntervalSince(self.lastPollDate) >= self.effectivePollInterval else { return false }
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

        let previouslyHadActiveDuel = await MainActor.run { !activeDuels.isEmpty }

        // All currently active duels I'm part of
        let myActiveDuels = freshDuels.filter { $0.status == .active }

        await MainActor.run {
            activeDuels = myActiveDuels

            // History: all completed duels, newest first
            duelHistory = freshDuels
                .filter { $0.status == .completed }
                .sorted { $0.createdAt > $1.createdAt }
        }

        // If we just discovered active duels for the first time, sync our pickup count.
        // The lastSyncedPickups guard in updateMyPickups prevents redundant PATCHes.
        // Must use the app-group suite — DataStore writes there, not to UserDefaults.standard.
        if !myActiveDuels.isEmpty, !previouslyHadActiveDuel {
            let suite = UserDefaults(suiteName: "group.fotiospongas.picksy") ?? UserDefaults.standard
            let pickups = suite.integer(forKey: "todayPickups")
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
        // Guard against concurrent finalization of the same duel.
        // Without this, two polls arriving within milliseconds of midnight both see
        // status=active+expired and both call finalizeDuel → duplicate notifications.
        let alreadyFinalizing = await MainActor.run {
            if finalizingDuelIDs.contains(duel.id) { return true }
            finalizingDuelIDs.insert(duel.id)
            return false
        }
        guard !alreadyFinalizing else {
            print("[Duel] ⏭ Already finalizing \(duel.id.prefix(8))… — skipping duplicate")
            return
        }

        // Use Picksy Score: pickups + (screen_time_minutes × 5). Lower = better.
        let challengerScore = duel.challengerPickups + (duel.challengerScreenTime / 60) * 5
        let opponentScore   = duel.opponentPickups   + (duel.opponentScreenTime   / 60) * 5
        let winner: String
        if challengerScore < opponentScore {
            winner = duel.challengerId
        } else if opponentScore < challengerScore {
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

        // Only the challenger sends push notifications — prevents both devices from
        // independently calling finalizeDuel at midnight and sending duplicate pushes.
        guard duel.amChallenger else {
            print("[Duel] ⏭ Opponent side — skipping push (challenger will notify)")
            return
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

        // Remove from in-progress set — finalization complete
        await MainActor.run { finalizingDuelIDs.remove(duel.id) }
    }

    func sendTaunt(to duel: DuelRecord, tauntText: String, myName: String) async {
        let name = myName.isEmpty ? "A friend" : myName
        await sendPush(toDeviceID: duel.theirDeviceID, title: "\(name) 😤", body: tauntText)
        print("[Duel] 😤 Taunt sent to \(duel.theirName)")
    }

    func sendNudge(toDeviceID: String, text: String, senderName: String) async {
        let name = senderName.isEmpty ? "A friend" : senderName
        await sendPush(toDeviceID: toDeviceID, title: "\(name) 👋", body: text)
        print("[Duel] 👋 Nudge sent to \(toDeviceID.prefix(8))…")
    }

    private func sendPush(toDeviceID: String, title: String, body: String, silent: Bool = false) async {
        guard let fnURL = URL(string: "\(Self.supabaseURL)/functions/v1/send-message") else { return }
        var payload: [String: Any] = [
            "device_id": toDeviceID,
            "title":     title,
            "body":      body
        ]
        if silent { payload["silent"] = true }
        var req = makeRequest(url: fnURL, method: "POST")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await URLSession.shared.data(for: req)
        print("[Duel] 📤 \(silent ? "Silent" : "Alert") push sent to \(toDeviceID.prefix(8))…")
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
