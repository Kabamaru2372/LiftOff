//
//  PushNotificationManager.swift
//  Picksy
//
//  Created by Fotios Pongas on 10.05.2026
//
//  v1.6 UPDATE: Προστέθηκε Live Activity push token registration.
//  Τώρα στέλνει στο Supabase:
//  1. Device token (για silent push → app wake-up)
//  2. Live Activity token (για Live Activity remote update → Dynamic Island)
//

import Foundation
import UIKit

@Observable
class PushNotificationManager {

    static let shared = PushNotificationManager()

    private static let supabaseURL = "https://igbtosqmtdrxzmoblvpp.supabase.co"
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"
    private static let bundleId = "fotiospongas.dev.UnPluq"

    var deviceToken: String? = nil
    var isRegistered: Bool = false

    private init() {}

    // MARK: - Device Token Registration

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .notDetermined:
                    UIApplication.shared.registerForRemoteNotifications()
                    print("[PushManager] ✅ Registering for remote notifications")
                default:
                    print("[PushManager] ⚠️ Push notifications not authorized")
                }
            }
        }
    }

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        self.isRegistered = true
        print("[PushManager] 📱 Device token: \(token.prefix(16))...")

        Task {
            await registerTokenWithSupabase(token: token, type: "device")
        }
    }

    func handleRegistrationFailure(_ error: Error) {
        print("[PushManager] ❌ Failed to register: \(error.localizedDescription)")
    }

    // MARK: - Live Activity Token Registration

    /// Καταχωρεί το Live Activity push token στο Supabase.
    /// Αυτό επιτρέπει στο Supabase να στέλνει push απευθείας
    /// στο Live Activity για να ενημερώνει το Dynamic Island
    /// χωρίς να χρειάζεται το app να είναι alive.
    func registerLiveActivityToken(_ token: String) async {
        print("[PushManager] 🎯 Registering Live Activity token: \(token.prefix(16))...")
        await registerTokenWithSupabase(token: token, type: "live_activity")
    }

    // MARK: - Silent Push Handling

    func handleSilentPush(
        userInfo: [AnyHashable: Any],
        store: DataStore?,
        liveActivity: LiveActivityManager?,
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("[PushManager] 🔔 Silent push received")

        store?.syncWithDeviceActivity()
        ScreenUnlockDetector.shared.startMonitoring()

        // H14 fix: guarantee completionHandler is called within iOS's ~30s deadline.
        // The original code only called it inside a Task, which iOS could kill before
        // completion, and also only when store AND liveActivity were both non-nil.
        // The timeout item fires at 25s as a safety net; the Task cancels it on success.
        let timeoutItem = DispatchWorkItem { completionHandler(.newData) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timeoutItem)

        Task {
            await DuelManager.shared.forcePoll()

            if let store = store, let liveActivity = liveActivity {
                let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
                let dailyGoal = goal > 0 ? goal : 50
                let pickups = store.todayPickups

                // Every successful silent-push wake (the pg_cron "picksy-silent-push"
                // job pings every 5 min, though Apple decides if/when it's actually
                // delivered) is also a chance to refresh the 21:00 notification's
                // baked-in count — not just the Live Activity below. Cheap, and closes
                // more of the staleness gap on top of the per-pickup reschedule.
                LiftOffApp.rescheduleTimeBasedNotifications(pickupCount: pickups)

                if liveActivity.isRunning {
                    liveActivity.update(pickupCount: pickups)
                } else {
                    liveActivity.start(pickupCount: pickups, dailyGoal: dailyGoal)
                }

                let activeDuel    = DuelManager.shared.activeDuel
                let isDuelActive  = activeDuel?.status == .active
                await self.pushLiveActivityUpdate(
                    pickupCount:      pickups,
                    screenTimeSecs:   store.bestScreenTimeSecs,
                    duelOpponentName: isDuelActive ? activeDuel?.theirName : nil,
                    duelMySecs:    isDuelActive ? store.bestScreenTimeSecs : 0,
                    duelTheirSecs: isDuelActive ? (activeDuel?.theirScreenTime ?? 0) : 0
                )

                // If we're in an active duel, upload our pickup count immediately
                // so the challenger can see it without waiting for us to open the app.
                // The DeviceActivity extension keeps todayPickups current in the App Group
                // even when the app is closed, so this background upload is accurate.
                if isDuelActive {
                    await DuelManager.shared.updateMyPickups(pickups, screenTimeSeconds: store.bestScreenTimeSecs)
                    print("[PushManager] 📤 Duel stats synced in background: pickups=\(pickups) screenTime=\(store.bestScreenTimeSecs)s")
                }

                print("[PushManager] ✅ Live Activity refreshed via silent push. Pickups: \(pickups)")
            }
            // Cancel timeout before calling — prevents a rare double-call if Task
            // finishes just as the timeout fires.
            timeoutItem.cancel()
            completionHandler(.newData)
        }
    }

    // MARK: - Live Activity Remote Update

    /// Calls the Supabase `update-live-activity` edge function, which sends an APNs
    /// Live Activity push directly to the Dynamic Island — works even when the app
    /// is fully suspended (same mechanism as live-score apps).
    func pushLiveActivityUpdate(
        pickupCount: Int,
        screenTimeSecs: Int = 0,
        duelOpponentName: String? = nil,
        duelMySecs: Int = 0,
        duelTheirSecs: Int = 0
    ) async {
        guard let url = URL(string: "\(Self.supabaseURL)/functions/v1/update-live-activity") else { return }

        var body: [String: Any] = [
            "device_id":        FriendSyncManager.shared.deviceID,
            "pickup_count":     pickupCount,
            "screen_time_secs": screenTimeSecs
        ]
        if let name = duelOpponentName {
            body["duel_opponent_name"] = name
            body["duel_my_secs"]       = duelMySecs
            body["duel_their_secs"]    = duelTheirSecs
        }
        // Carry an active Focus session into background/remote pushes too — without
        // this, a BGAppRefresh or silent push firing mid-session would flip the DI
        // out of Focus mode back to Normal/Duel, since ActivityKit remote pushes
        // replace the WHOLE content-state (there's no partial update).
        // FocusSessionManager is in-memory only and not reachable from here, so we
        // read the App Group mirror it writes on start()/stop().
        let suite = UserDefaults(suiteName: "group.fotiospongas.picksy")
        let focusEnd = suite?.double(forKey: "picksy_focus_end_time") ?? 0
        if focusEnd > Date().timeIntervalSince1970 {
            let pickupsAtStart = suite?.integer(forKey: "picksy_focus_pickups_at_start") ?? pickupCount
            body["focus_end_time"] = focusEnd
            body["focus_pickup_count"] = max(0, pickupCount - pickupsAtStart)
        }
        // Carry the plant-growth checkpoint into background/remote pushes too, so
        // the normal-mode DI's growth animation keeps extrapolating correctly
        // instead of resetting to 0 on every background-triggered update.
        let plant = DataStore.plantHealthCheckpoint()
        body["plant_health"] = plant.baseline
        body["plant_health_time"] = plant.time.timeIntervalSince1970
        body["plant_health_wilting"] = plant.isWilting
        // Same reasoning as the plant checkpoint: the DI's "time since last
        // pickup" ticker must reflect the REAL last detected pickup, not the
        // moment this background/remote push happens to fire — otherwise a
        // routine silent push (BGAppRefresh, duel sync) falsely resets it.
        let lastPickup = ScreenUnlockDetector.shared.lastPickupTime
        if lastPickup != .distantPast {
            body["last_pickup_time"] = lastPickup.timeIntervalSince1970
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        request.timeoutInterval = 8

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[PushManager] 🎯 LiveActivity push → \(http.statusCode)")
                if http.statusCode < 300 {
                    let d = UserDefaults(suiteName: "group.fotiospongas.picksy")
                    let k = "picksy_debug_edge_calls_\(Self.todayKey())"
                    d?.set((d?.integer(forKey: k) ?? 0) + 1, forKey: k)
                }
            }
        } catch {
            print("[PushManager] ⚠️ LiveActivity push failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Supabase Registration

    private func registerTokenWithSupabase(token: String, type: String) async {
        // `on_conflict=token` tells PostgREST which column to use for conflict detection.
        // The Prefer header alone is not enough — PostgREST needs the column name to upsert.
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/device_tokens?on_conflict=token") else {
            return
        }

        let isProduction = !isDebugBuild()

        let body: [String: Any] = [
            "token": token,
            "bundle_id": Self.bundleId,
            "is_production": isProduction,
            "is_active": true,
            "token_type": type,  // "device" ή "live_activity"
            "device_id": FriendSyncManager.shared.deviceID,  // anonymous UUID for friend sync
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("[PushManager] ✅ Token (\(type)) registered with Supabase")
                } else {
                    print("[PushManager] ⚠️ Supabase response: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("[PushManager] ❌ Failed to register token: \(error.localizedDescription)")
        }
    }

    private static func todayKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

