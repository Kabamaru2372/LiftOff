// ForceUpdateManager.swift
// Picksy
//
// Checks a remote Supabase config table on every app foreground.
// If the running version is below `ios_min_version`, the app is blocked
// with a full-screen update prompt. If below `ios_recommended_version`,
// a dismissible soft-update banner is shown.
//
// Supabase setup (run once in the SQL editor):
//
//   CREATE TABLE IF NOT EXISTS app_config (
//     key   TEXT PRIMARY KEY,
//     value TEXT NOT NULL
//   );
//   ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
//   CREATE POLICY "anon_read" ON app_config FOR SELECT USING (true);
//
//   INSERT INTO app_config (key, value) VALUES
//     ('ios_min_version',         '1.0'),   -- bump to FORCE update from below this version
//     ('ios_recommended_version', '1.6')    -- bump to show soft banner
//   ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

import Foundation
import SwiftUI
import UIKit

@Observable
final class ForceUpdateManager {

    static let shared = ForceUpdateManager()

    // MARK: - State

    /// True when the running version is below `ios_min_version`.
    /// Causes LiftOffApp to overlay `ForceUpdateView` and block all interaction.
    var isForceUpdateRequired = false

    /// True when the running version is below `ios_recommended_version`
    /// but above `ios_min_version`. Shows a dismissible top banner.
    var isSoftUpdateAvailable = false

    /// Set to true after the first successful (or failed) check so the UI
    /// doesn't flicker while the network request is in flight.
    var checkCompleted = false

    // MARK: - Constants

    private static let supabaseURL     = "https://igbtosqmtdrxzmoblvpp.supabase.co"
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"

    static let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id6761116771")!
    static let appStoreWebURL = URL(string: "https://apps.apple.com/app/picksy-be-present/id6761116771")!

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Fetches `ios_min_version` and `ios_recommended_version` from Supabase
    /// and updates `isForceUpdateRequired` / `isSoftUpdateAvailable`.
    /// Always fails open: if the network is unreachable, the user is not blocked.
    func check() async {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            await MainActor.run { checkCompleted = true }
            return
        }

        let query = "key=in.(ios_min_version,ios_recommended_version)&select=key,value"
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/app_config?\(query)") else {
            await MainActor.run { checkCompleted = true }
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else {
            // Network error or bad response — fail open so users are never blocked offline
            print("[ForceUpdate] ⚠️ Could not reach config — failing open")
            await MainActor.run { checkCompleted = true }
            return
        }

        // Parse into a dictionary
        var config: [String: String] = [:]
        for row in rows {
            if let key = row["key"], let value = row["value"] {
                config[key] = value
            }
        }

        let minVersion         = config["ios_min_version"]         ?? "0.0"
        let recommendedVersion = config["ios_recommended_version"] ?? "0.0"

        await MainActor.run {
            isForceUpdateRequired = isVersion(currentVersion, olderThan: minVersion)
            isSoftUpdateAvailable = !isForceUpdateRequired
                                    && isVersion(currentVersion, olderThan: recommendedVersion)
            checkCompleted = true

            if isForceUpdateRequired {
                print("[ForceUpdate] 🚨 Force update required — running \(currentVersion), min \(minVersion)")
            } else if isSoftUpdateAvailable {
                print("[ForceUpdate] 💡 Soft update available — running \(currentVersion), recommended \(recommendedVersion)")
            } else {
                print("[ForceUpdate] ✅ Up to date — running \(currentVersion)")
            }
        }
    }

    /// Opens the App Store page for Picksy.
    /// Not available in app extensions (UIApplication.shared is restricted there).
    @MainActor
    @available(iOSApplicationExtension, unavailable)
    func openAppStore() {
        let target = UIApplication.shared.canOpenURL(Self.appStoreURL)
            ? Self.appStoreURL
            : Self.appStoreWebURL
        UIApplication.shared.open(target)
    }

    // MARK: - Version comparison

    /// Returns true if `version` is strictly older than `minimum`.
    /// Compares each dot-separated component as an integer.
    /// Examples: "1.5" < "1.6" → true; "1.6" < "1.6" → false; "2.0" < "1.9" → false
    private func isVersion(_ version: String, olderThan minimum: String) -> Bool {
        let lhs = version.split(separator: ".").compactMap { Int($0) }
        let rhs  = minimum.split(separator: ".").compactMap { Int($0) }
        let length = max(lhs.count, rhs.count)
        for i in 0..<length {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l < r { return true  }
            if l > r { return false }
        }
        return false // equal
    }
}
