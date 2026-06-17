// SharedAppsManager.swift
// Picksy
//
// Manages the list of apps a user voluntarily shares with duel/tournament partners.
// Uses plain strings (not FamilyControls tokens) — fully Apple-compliant.

import Foundation

@Observable
class SharedAppsManager {

    static let shared = SharedAppsManager()

    // MARK: - Popular app catalogue

    struct AppEntry: Identifiable {
        let id: String       // same as name
        let name: String
        let symbol: String   // SF Symbol
        let colorHex: String
    }

    static let popularApps: [AppEntry] = [
        .init(id: "Instagram",   name: "Instagram",   symbol: "camera.fill",          colorHex: "C13584"),
        .init(id: "Facebook",    name: "Facebook",    symbol: "person.2.fill",         colorHex: "1877F2"),
        .init(id: "TikTok",      name: "TikTok",      symbol: "music.note",            colorHex: "010101"),
        .init(id: "YouTube",     name: "YouTube",     symbol: "play.rectangle.fill",   colorHex: "FF0000"),
        .init(id: "X / Twitter", name: "X / Twitter", symbol: "xmark",                 colorHex: "000000"),
        .init(id: "Snapchat",    name: "Snapchat",    symbol: "camera.aperture",       colorHex: "FFFC00"),
        .init(id: "Reddit",      name: "Reddit",      symbol: "bubble.left.fill",      colorHex: "FF4500"),
        .init(id: "WhatsApp",    name: "WhatsApp",    symbol: "message.fill",          colorHex: "25D366"),
        .init(id: "LinkedIn",    name: "LinkedIn",    symbol: "briefcase.fill",        colorHex: "0A66C2"),
        .init(id: "Pinterest",   name: "Pinterest",   symbol: "pin.fill",              colorHex: "E60023"),
        .init(id: "Twitch",      name: "Twitch",      symbol: "gamecontroller.fill",   colorHex: "9146FF"),
        .init(id: "Netflix",     name: "Netflix",     symbol: "film.fill",             colorHex: "E50914"),
        .init(id: "Spotify",     name: "Spotify",     symbol: "music.note.list",       colorHex: "1DB954"),
        .init(id: "Threads",     name: "Threads",     symbol: "at.circle.fill",        colorHex: "000000"),
        .init(id: "Telegram",    name: "Telegram",    symbol: "paperplane.fill",       colorHex: "26A5E4"),
        .init(id: "Discord",     name: "Discord",     symbol: "headphones",            colorHex: "5865F2"),
        .init(id: "BeReal",      name: "BeReal",      symbol: "camera.2.fill",         colorHex: "000000"),
        .init(id: "Safari",      name: "Safari",      symbol: "safari.fill",           colorHex: "006CFF"),
        .init(id: "News apps",   name: "News apps",   symbol: "newspaper.fill",        colorHex: "FF3B30"),
        .init(id: "Games",       name: "Games",       symbol: "gamecontroller.fill",   colorHex: "34C759"),
    ]

    // MARK: - State

    var mySelectedApps: Set<String> = [] {
        didSet { saveLocally() }
    }

    // MARK: - Private

    private let userDefaultsKey = "picksy_shared_apps_v1"
    private static let supabaseURL     = "https://igbtosqmtdrxzmoblvpp.supabase.co"
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"

    private init() {
        if let stored = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            mySelectedApps = Set(stored)
        }
    }

    // MARK: - Local persistence

    private func saveLocally() {
        UserDefaults.standard.set(Array(mySelectedApps), forKey: userDefaultsKey)
    }

    // MARK: - Supabase sync

    func syncToSupabase() async {
        let deviceID = FriendSyncManager.shared.deviceID
        guard let appsJSON = try? JSONEncoder().encode(Array(mySelectedApps).sorted()),
              let appsString = String(data: appsJSON, encoding: .utf8)
        else { return }

        let urlStr = "\(Self.supabaseURL)/rest/v1/device_status"
        guard let url = URL(string: urlStr) else { return }

        let body: [String: Any] = [
            "device_id":   deviceID,
            "shared_apps": appsString,
            "updated_at":  ISO8601DateFormatter().string(from: Date())
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: req)
    }

    func fetchFriendApps(deviceID: String) async -> [String] {
        let escaped = deviceID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceID
        let urlStr = "\(Self.supabaseURL)/rest/v1/device_status?device_id=eq.\(escaped)&select=shared_apps"
        guard let url = URL(string: urlStr) else { return [] }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let row = rows.first,
              let appsStr = row["shared_apps"] as? String,
              let appsData = appsStr.data(using: .utf8),
              let apps = try? JSONDecoder().decode([String].self, from: appsData)
        else { return [] }

        return apps
    }
}
