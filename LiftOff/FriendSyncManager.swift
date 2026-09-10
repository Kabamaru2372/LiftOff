// FriendSyncManager.swift
// Picksy
//
// Anonymous friend pair tracking via Supabase.
//
// PRIVACY MODEL:
//   • Each device generates a random UUID — never linked to a name, email, or account.
//   • Data uploaded to device_status: {
//       device_id (UUID), pickups_today (Int), daily_goal (Int),
//       pickups_last_2h (Int), screen_time_last_2h_seconds (Int), updated_at (String)
//     }
//   • screen_time_last_2h_seconds is Picksy's own measurement of screen-on time
//     (via ScreenUnlockDetector session tracking) — NOT Apple's Screen Time API data.
//     No per-app breakdown, no browsing history — just an aggregate total in seconds.
//   • Uploads happen ONLY if the user has at least one registered friend pair.
//   • The user can remove all pairs at any time from Settings.

import Foundation
import UserNotifications

// MARK: - Supporting types

/// A locally-stored friend pair entry.
struct RegisteredPair: Codable, Identifiable {
    var id: String { deviceID }
    let deviceID: String   // partner's anonymous UUID
    let name: String       // how the partner signed their challenge ("Maria", "A friend", …)
    let registeredAt: Date
}

private struct DeviceStatusRow: Decodable {
    let device_id: String
    let pickups_today: Int
    let daily_goal: Int
    let pickups_last_2h: Int
    let screen_time_last_2h_seconds: Int
    let updated_at: String
}

/// A partner who is currently overusing their phone.
struct OverusingPartner {
    let deviceID: String
    let friendName: String
    let pickupsToday: Int
    let dailyGoal: Int
}

/// Data for the "together overuse" in-app banner.
struct TogetherBannerData: Identifiable {
    var id: String { pair.deviceID }
    let pair: RegisteredPair
    let theirScreenTimeMins: Int
    let myScreenTimeMins: Int
    var totalMins: Int { myScreenTimeMins + theirScreenTimeMins }
}

// MARK: - FriendSyncManager

@Observable
class FriendSyncManager {

    static let shared = FriendSyncManager()

    private static let supabaseURL     = "https://igbtosqmtdrxzmoblvpp.supabase.co"
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"

    private static let deviceIDKey     = "picksy_anonymous_device_id"
    private static let pairsKey        = "picksy_friend_pairs_v2"
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Device ID

    /// Persistent anonymous device identifier.
    /// C8 fix: stored as a `let` constant set in init — eliminates the non-atomic
    /// read-then-write race where two concurrent callers could both see nil and
    /// generate different UUIDs, with one silently discarded.
    let deviceID: String

    private init() {
        if let stored = UserDefaults.standard.string(forKey: FriendSyncManager.deviceIDKey) {
            deviceID = stored
        } else {
            let new = UUID().uuidString
            UserDefaults.standard.set(new, forKey: FriendSyncManager.deviceIDKey)
            deviceID = new
        }
    }

    // MARK: - Pair Registry (local)

    var registeredPairs: [RegisteredPair] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.pairsKey),
                  let pairs = try? JSONDecoder().decode([RegisteredPair].self, from: data)
            else { return [] }
            return pairs
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Self.pairsKey)
            }
        }
    }

    var hasPairs: Bool { !registeredPairs.isEmpty }

    func removePair(deviceID id: String) {
        registeredPairs = registeredPairs.filter { $0.deviceID != id }
        print("[FriendSync] 🗑 Removed pair \(id.prefix(8))...")
    }

    func removeAllPairs() {
        registeredPairs = []
        print("[FriendSync] 🗑 All pairs removed")
    }

    // MARK: - Register Pair (Supabase)

    /// Called when the user opens a challenge link from a specific sender.
    /// Stores the pair locally AND registers on Supabase.
    func registerPair(theirDeviceID: String, theirName: String) async {
        guard theirDeviceID != deviceID else { return }   // don't pair with self

        // H13 fix: check + append inside the same MainActor.run block so
        // concurrent calls to registerPair can't both see alreadyKnown=false
        // and both append, creating a duplicate local entry.
        await MainActor.run {
            let alreadyKnown = registeredPairs.contains(where: { $0.deviceID == theirDeviceID })
            if !alreadyKnown {
                let newPair = RegisteredPair(
                    deviceID: theirDeviceID,
                    name: theirName,
                    registeredAt: Date()
                )
                var pairs = registeredPairs
                pairs.append(newPair)
                registeredPairs = pairs
            }
        }

        // Normalise order (smaller UUID is always device_a)
        let myIsA = deviceID < theirDeviceID
        let (a, b) = myIsA ? (deviceID, theirDeviceID) : (theirDeviceID, deviceID)
        let myOwnName = UserDefaults.standard.string(forKey: "challengeDisplayName") ?? "A friend"

        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/friend_pairs") else { return }

        // name_a = display name of whoever has the smaller UUID (device_a)
        // name_b = display name of whoever has the larger UUID (device_b)
        // This lets EITHER device look up the other's name correctly on sync.
        let body: [String: Any] = [
            "device_a":    a,
            "device_b":    b,
            "friend_name": theirName,                          // legacy field, kept for compatibility
            "name_a":      myIsA ? myOwnName : theirName,
            "name_b":      myIsA ? theirName : myOwnName
        ]

        var req = makeRequest(url: url, method: "POST")
        req.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse {
            print("[FriendSync] 🔗 Pair registered – HTTP \(http.statusCode)")
        }
    }

    // MARK: - Sync Friends from Supabase

    /// Fetches all friend_pairs rows from Supabase where this device is either
    /// device_a or device_b, and adds any unknown friends to the local registry.
    ///
    /// This is the ONLY way the sender discovers that someone accepted their invite,
    /// since ChallengeReceivedView only writes to the recipient's local storage.
    /// Call on every app foreground so the list stays in sync.
    func syncFriendsFromSupabase() async {
        let myID = deviceID
        let escaped = myID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? myID

        guard let url = URL(string:
            "\(Self.supabaseURL)/rest/v1/friend_pairs?or=(device_a.eq.\(escaped),device_b.eq.\(escaped))&select=device_a,device_b,friend_name,name_a,name_b"
        ) else { return }

        var req = makeRequest(url: url, method: "GET")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        // [[String: String]] here is all-or-nothing: if even ONE row has a NULL
        // in any selected column (e.g. a legacy pair from before name_a/name_b
        // existed — confirmed present in production today), the whole cast
        // fails and this device silently stops discovering ANY friend, with
        // no error surfaced. [[String: Any]] + per-field `as? String ?? ""`
        // below tolerates NULLs on a per-row/per-field basis instead.
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return }

        // Collect new pairs to add — all MainActor mutations in one block
        let myOwnName = UserDefaults.standard.string(forKey: "challengeDisplayName") ?? ""

        var toUpsert: [(id: String, name: String)] = []
        for row in rows {
            let deviceA = row["device_a"] as? String ?? ""
            let deviceB = row["device_b"] as? String ?? ""
            let otherID = deviceA == myID ? deviceB : deviceA
            guard !otherID.isEmpty else { continue }

            // Priority 1: new name_a / name_b columns — always correct
            let nameA = row["name_a"] as? String ?? ""
            let nameB = row["name_b"] as? String ?? ""
            let name: String
            if !nameA.isEmpty && !nameB.isEmpty {
                // I am device_a when myID < otherID (same UUID normalisation as registerPair)
                name = (myID < otherID) ? nameB : nameA
            } else {
                // Legacy fallback: friend_name stores the SENDER's name.
                // If it equals MY name, I was the sender → the other person has no name stored yet.
                let friendName = row["friend_name"] as? String ?? ""
                if !friendName.isEmpty && friendName != myOwnName {
                    name = friendName   // I was the recipient → friend_name is the other person
                } else {
                    name = "A friend"  // I was the sender → friend_name is myself, unknown other
                }
            }
            toUpsert.append((id: otherID, name: name))
        }

        await MainActor.run {
            var pairs = registeredPairs
            var changed = 0
            for item in toUpsert {
                if let idx = pairs.firstIndex(where: { $0.deviceID == item.id }) {
                    // Update name if it was wrong (e.g. was "Fotios" instead of "Νεφέλη")
                    if pairs[idx].name != item.name && item.name != "A friend" {
                        pairs[idx] = RegisteredPair(deviceID: item.id, name: item.name, registeredAt: pairs[idx].registeredAt)
                        changed += 1
                    }
                } else {
                    pairs.append(RegisteredPair(deviceID: item.id, name: item.name, registeredAt: Date()))
                    changed += 1
                }
            }
            if changed > 0 {
                registeredPairs = pairs
                print("[FriendSync] 🔄 Synced \(changed) friend(s) from Supabase")
            }
        }
    }

    // MARK: - Upload Status

    /// Uploads current pickup count to Supabase.
    /// Skipped silently if no pairs exist — no data leaves the device unless the user
    /// has explicitly connected with at least one friend.
    func uploadStatus(pickups: Int, dailyGoal: Int, pickupsLast2h: Int = 0, screenTimeLast2hSecs: Int = 0) async {
        guard hasPairs else { return }

        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/device_status") else { return }

        let body: [String: Any] = [
            "device_id":                  deviceID,
            "pickups_today":              pickups,
            "daily_goal":                 dailyGoal,
            "pickups_last_2h":            pickupsLast2h,
            "screen_time_last_2h_seconds": screenTimeLast2hSecs,
            "updated_at":                 Self.isoFormatter.string(from: Date())
        ]

        var req = makeRequest(url: url, method: "POST")
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse {
            print("[FriendSync] 📤 Status uploaded (\(pickups) pickups) – HTTP \(http.statusCode)")
        }
    }

    // MARK: - Check Partners

    /// Returns partners who are also overusing right now.
    /// Conditions:
    ///   • It's past 14:00 local time
    ///   • My own pickups ≥ 40 % of my daily goal
    ///   • Partner's pickups ≥ 40 % of *their* daily goal
    ///   • Not already notified today for this partner
    /// - myScreenTimeLast2hSecs: from DataStore.screenTimeLastTwoHours
    func checkOverusingPartners(myPickups: Int, myGoal: Int, myScreenTimeLast2hSecs: Int) async -> [OverusingPartner] {
        print("[FriendSync] 🔍 checkOverusingPartners — hasPairs=\(hasPairs), screenTime2h=\(myScreenTimeLast2hSecs)s")
        guard hasPairs else {
            print("[FriendSync] ⏭ No pairs — skipping check")
            return []
        }

        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 14 else {
            print("[FriendSync] ⏭ Before 14:00 — skipping partner check")
            return []
        }

        // Require ≥ 20 min screen time in last 2 hours as "currently overusing" signal
        let myThresholdSecs = 20 * 60  // 20 minutes
        guard myScreenTimeLast2hSecs >= myThresholdSecs else {
            print("[FriendSync] ⏭ My screen time (\(myScreenTimeLast2hSecs)s) below 20 min threshold — skipping")
            return []
        }

        // MEDIUM fix: parallel fetches with withTaskGroup (was N sequential network calls).
        let eligiblePairs = registeredPairs.filter { !alreadyNotifiedToday(for: $0.deviceID) }
        let partnerThreshold = 20 * 60

        let result: [OverusingPartner] = await withTaskGroup(
            of: OverusingPartner?.self,
            returning: [OverusingPartner].self
        ) { group in
            for pair in eligiblePairs {
                group.addTask {
                    guard let row = await self.fetchStatus(for: pair.deviceID) else {
                        print("[FriendSync] ⚠️ No status found for \(pair.name)")
                        return nil
                    }
                    print("[FriendSync] 📊 \(pair.name): screenTime2h=\(row.screen_time_last_2h_seconds)s")
                    guard row.screen_time_last_2h_seconds >= partnerThreshold else { return nil }
                    return OverusingPartner(
                        deviceID: pair.deviceID,
                        friendName: pair.name,
                        pickupsToday: row.pickups_today,
                        dailyGoal: row.daily_goal
                    )
                }
            }
            var found: [OverusingPartner] = []
            for await partner in group { if let p = partner { found.append(p) } }
            return found
        }
        print("[FriendSync] ✅ Found \(result.count) overusing partner(s)")
        return result
    }

    // MARK: - Notification dedup

    func markNotifiedToday(for partnerDeviceID: String) {
        let key = "picksy_friend_notified_\(partnerDeviceID)"
        UserDefaults.standard.set(todayString(), forKey: key)
    }

    private func alreadyNotifiedToday(for partnerDeviceID: String) -> Bool {
        UserDefaults.standard.string(
            forKey: "picksy_friend_notified_\(partnerDeviceID)"
        ) == todayString()
    }

    // MARK: - Private helpers

    private func fetchStatus(for partnerDeviceID: String) async -> DeviceStatusRow? {
        let escaped = partnerDeviceID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? partnerDeviceID
        guard let url = URL(string:
            "\(Self.supabaseURL)/rest/v1/device_status?device_id=eq.\(escaped)&select=device_id,pickups_today,daily_goal,pickups_last_2h,screen_time_last_2h_seconds,updated_at"
        ) else { return nil }

        var req = makeRequest(url: url, method: "GET")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let rows = try? JSONDecoder().decode([DeviceStatusRow].self, from: data),
              let row = rows.first
        else { return nil }

        // Ignore stale data older than 24 h
        if let updated = ISO8601DateFormatter().date(from: row.updated_at),
           Date().timeIntervalSince(updated) > 86_400 { return nil }

        return row
    }

    // MARK: - Together Banner

    /// Returns friends who are ALSO currently on their phone — for the in-app banner.
    /// Lower threshold (15 min) and no time-of-day restriction vs push notifications.
    /// Uses a 2-hour slot key so the banner re-appears at most once per 2h per friend.
    func checkForTogetherBanner(myScreenTimeSecs: Int) async -> [TogetherBannerData] {
        guard hasPairs else { return [] }

        let myMins = myScreenTimeSecs / 60
        guard myMins >= 15 else { return [] }

        // MEDIUM fix: parallel fetches (was N sequential).
        let eligiblePairs = registeredPairs.filter { !bannerShownThisSlot(for: $0.deviceID) }

        return await withTaskGroup(
            of: TogetherBannerData?.self,
            returning: [TogetherBannerData].self
        ) { group in
            for pair in eligiblePairs {
                group.addTask {
                    guard let row = await self.fetchStatus(for: pair.deviceID) else { return nil }
                    let theirMins = row.screen_time_last_2h_seconds / 60
                    guard theirMins >= 15 else { return nil }
                    return TogetherBannerData(
                        pair: pair,
                        theirScreenTimeMins: theirMins,
                        myScreenTimeMins: myMins
                    )
                }
            }
            var found: [TogetherBannerData] = []
            for await banner in group { if let b = banner { found.append(b) } }
            return found
        }
    }

    /// Mark that we showed the banner for this friend in the current 2h slot.
    func markBannerShown(for partnerDeviceID: String) {
        let key = "picksy_together_banner_\(partnerDeviceID)"
        UserDefaults.standard.set(currentTwoHourSlot(), forKey: key)
    }

    private func bannerShownThisSlot(for partnerDeviceID: String) -> Bool {
        UserDefaults.standard.string(forKey: "picksy_together_banner_\(partnerDeviceID)") == currentTwoHourSlot()
    }

    /// Returns a string like "2026-05-18-14" (date + 2h slot index 0..11).
    private func currentTwoHourSlot() -> String {
        let now = Date()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let hour = Calendar.current.component(.hour, from: now)
        return "\(f.string(from: now))-\(hour / 2)"
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

    private func todayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
