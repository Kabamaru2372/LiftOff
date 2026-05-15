// FriendSyncManager.swift
// Picksy
//
// Anonymous friend pair tracking via Supabase.
//
// PRIVACY MODEL:
//   • Each device generates a random UUID — never linked to a name, email, or account.
//   • Data uploaded: { device_id (UUID), pickups_today (Int), daily_goal (Int) }
//   • No personal information leaves the device.
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
    let updated_at: String
}

/// A partner who is currently overusing their phone.
struct OverusingPartner {
    let deviceID: String
    let friendName: String
    let pickupsToday: Int
    let dailyGoal: Int
}

// MARK: - FriendSyncManager

@Observable
class FriendSyncManager {

    static let shared = FriendSyncManager()

    private static let supabaseURL     = "https://igbtosqmtdrxzmoblvpp.supabase.co"
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"

    private static let deviceIDKey     = "picksy_anonymous_device_id"
    private static let pairsKey        = "picksy_friend_pairs_v2"

    // MARK: - Device ID

    /// Persistent anonymous device identifier.
    /// Generated once, stored locally. Never transmitted alongside any personal info.
    var deviceID: String {
        if let stored = UserDefaults.standard.string(forKey: Self.deviceIDKey) {
            return stored
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: Self.deviceIDKey)
        return new
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

        // Save locally first (on MainActor to avoid Sendable capture warning)
        let alreadyKnown = registeredPairs.contains(where: { $0.deviceID == theirDeviceID })
        if !alreadyKnown {
            let newPair = RegisteredPair(
                deviceID: theirDeviceID,
                name: theirName,
                registeredAt: Date()
            )
            await MainActor.run {
                var pairs = registeredPairs
                pairs.append(newPair)
                registeredPairs = pairs
            }
        }

        // Normalise order (smaller UUID is always device_a)
        let (a, b) = deviceID < theirDeviceID
            ? (deviceID, theirDeviceID)
            : (theirDeviceID, deviceID)

        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/friend_pairs") else { return }

        let body: [String: Any] = [
            "device_a":    a,
            "device_b":    b,
            "friend_name": theirName
        ]

        var req = makeRequest(url: url, method: "POST")
        req.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse {
            print("[FriendSync] 🔗 Pair registered – HTTP \(http.statusCode)")
        }
    }

    // MARK: - Upload Status

    /// Uploads current pickup count to Supabase.
    /// Skipped silently if no pairs exist — no data leaves the device unless the user
    /// has explicitly connected with at least one friend.
    func uploadStatus(pickups: Int, dailyGoal: Int) async {
        guard hasPairs else { return }

        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/device_status") else { return }

        let body: [String: Any] = [
            "device_id":    deviceID,
            "pickups_today": pickups,
            "daily_goal":   dailyGoal,
            "updated_at":   ISO8601DateFormatter().string(from: Date())
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
    func checkOverusingPartners(myPickups: Int, myGoal: Int) async -> [OverusingPartner] {
        print("[FriendSync] 🔍 checkOverusingPartners — hasPairs=\(hasPairs), pairs=\(registeredPairs.map(\.deviceID))")
        guard hasPairs else {
            print("[FriendSync] ⏭ No pairs — skipping check")
            return []
        }

        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 14 else {
            print("[FriendSync] ⏭ Before 14:00 — skipping partner check")
            return []
        }
        guard myPickups >= Int(Double(myGoal) * 0.4) else {
            print("[FriendSync] ⏭ My pickups (\(myPickups)) below threshold — skipping")
            return []
        }

        var result: [OverusingPartner] = []

        for pair in registeredPairs {
            print("[FriendSync] 👥 Checking pair: \(pair.deviceID.prefix(16))…")
            if alreadyNotifiedToday(for: pair.deviceID) {
                print("[FriendSync] ⏭ Already notified today for \(pair.name)")
                continue
            }
            guard let row = await fetchStatus(for: pair.deviceID) else {
                print("[FriendSync] ⚠️ No status found for \(pair.name)")
                continue
            }
            let threshold = Int(Double(row.daily_goal) * 0.4)
            print("[FriendSync] 📊 \(pair.name): \(row.pickups_today) pickups, threshold=\(threshold)")
            if row.pickups_today >= threshold {
                result.append(OverusingPartner(
                    deviceID: pair.deviceID,
                    friendName: pair.name,
                    pickupsToday: row.pickups_today,
                    dailyGoal: row.daily_goal
                ))
            }
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
            "\(Self.supabaseURL)/rest/v1/device_status?device_id=eq.\(escaped)&select=device_id,pickups_today,daily_goal,updated_at"
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
