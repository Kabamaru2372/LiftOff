// ChallengeManager.swift
// Picksy
//
// Handles encoding/decoding of weekly challenge deep links.
// No backend — data travels only when the user explicitly taps Share.
//
// URL format: picksy://challenge?d=<base64url-encoded JSON>

import Foundation

// MARK: - Challenge Payload

struct ChallengePayload: Codable, Identifiable {
    // Identifiable so it works with .sheet(item:)
    var id: String { "\(name)-\(sentAt)" }

    let name: String           // sender display name ("A friend" if blank)
    let weekly: [Int]          // last 7 days of pickups (Mon → Sun)
    let streak: Int
    let goal: Int
    let sentAt: TimeInterval   // Unix timestamp — helps recipient see how fresh the data is
    var senderDeviceID: String? // Anonymous UUID for optional friend pairing (never personal info)
}

// MARK: - Challenge Manager

enum ChallengeManager {

    private static let scheme   = "picksy"
    private static let host     = "challenge"
    private static let webBase  = "https://fotiospongas.dev/challenge"

    // MARK: - Encode

    /// Generates a shareable `https://fotiospongas.dev/challenge?d=…` URL.
    /// If the recipient has Picksy installed the web page opens the app directly.
    /// If not, they are redirected to the App Store.
    static func buildURL(
        displayName: String,
        weeklyPickups: [Int],
        streak: Int,
        dailyGoal: Int
    ) -> URL? {
        let name = displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "A friend"
            : displayName.trimmingCharacters(in: .whitespaces)

        let payload = ChallengePayload(
            name: name,
            weekly: weeklyPickups,
            streak: streak,
            goal: dailyGoal,
            sentAt: Date().timeIntervalSince1970,
            senderDeviceID: FriendSyncManager.shared.deviceID
        )

        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        let b64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // Build HTTPS share link — web page handles app redirect + App Store fallback
        var comps = URLComponents(string: webBase)
        comps?.queryItems = [URLQueryItem(name: "d", value: b64)]
        return comps?.url
    }

    /// Internal deep link used when the app is already installed (e.g. from Universal Links).
    static func buildDeepLink(from b64: String) -> URL? {
        var comps = URLComponents()
        comps.scheme = scheme
        comps.host   = host
        comps.queryItems = [URLQueryItem(name: "d", value: b64)]
        return comps.url
    }

    // MARK: - Decode

    /// Parses a `picksy://challenge?d=…` URL. Returns nil if malformed.
    static func parse(url: URL) -> ChallengePayload? {
        guard url.scheme == scheme, url.host == host else { return nil }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let item  = comps.queryItems?.first(where: { $0.name == "d" }),
              let b64   = item.value else { return nil }

        // Re-add base64 padding
        let padded = b64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = String(repeating: "=", count: (4 - padded.count % 4) % 4)
        guard let data = Data(base64Encoded: padded + padding) else { return nil }
        return try? JSONDecoder().decode(ChallengePayload.self, from: data)
    }

    // MARK: - Share Text

    /// Builds the message text the user sends alongside the link.
    static func shareMessage(
        payload: ChallengePayload,
        language: String
    ) -> String {
        let avg = payload.weekly.isEmpty ? 0
            : payload.weekly.reduce(0, +) / max(payload.weekly.count, 1)

        switch language {
        case "Ελληνικά":
            return "Σε προκαλώ στο Picksy! 📱 Αυτή την εβδομάδα είχα κατά μέσο όρο \(avg) σηκώματα ανά μέρα. Μπορείς να τα πας καλύτερα;"
        case "Deutsch":
            return "Ich fordere dich bei Picksy heraus! 📱 Diese Woche hatte ich im Schnitt \(avg) Griffe pro Tag. Kannst du das schlagen?"
        default:
            return "I'm challenging you on Picksy! 📱 This week I averaged \(avg) pickups per day. Can you beat that?"
        }
    }

    // MARK: - Context Triggers

    /// Returns true when today is good enough to suggest a challenge.
    /// Conditions: after 16:00, pickups ≤ 50% of goal, not already suggested today.
    static func shouldSuggestShare(pickups: Int, dailyGoal: Int) -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 16 else { return false }
        guard pickups <= Int(Double(dailyGoal) * 0.5) else { return false }
        guard !alreadySuggestedToday else { return false }
        return true
    }

    static func markSuggestedToday() {
        UserDefaults.standard.set(todayString(), forKey: "picksy_challenge_suggested_date")
    }

    private static var alreadySuggestedToday: Bool {
        UserDefaults.standard.string(forKey: "picksy_challenge_suggested_date") == todayString()
    }

    private static func todayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
