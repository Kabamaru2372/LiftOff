//
//  LiveActivityManager.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
//  v1.6 UPDATE: pushType: .token για remote Live Activity updates.
//  v1.7 FIX: Αφαιρέθηκε η εξάρτηση από PushNotificationManager.
//  Το token αποθηκεύεται στο UserDefaults και το LiftOffApp το στέλνει στο Supabase.
//

import ActivityKit
import Foundation

@Observable
class LiveActivityManager {

    private var currentActivity: Activity<LiftOffActivityAttributes>?

    /// Today's best-known screen time (seconds) for the duel DI.
    /// Uses ONLY local, date-guarded App Group values — never the Supabase-synced
    /// duel.myScreenTime, which can be from a previous day's sync and would
    /// cause the DI to show yesterday's total as today's score.
    private func myDuelSecs(_ duel: DuelRecord) -> Int {
        let suite = UserDefaults(suiteName: "group.fotiospongas.picksy") ?? .standard
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        var appleSecs = 0
        if suite.string(forKey: "picksy_apple_screen_time_date") == today {
            let raw = suite.integer(forKey: "picksy_apple_screen_time_secs")
            let resetEpoch = suite.double(forKey: "picksy_ladder_reset_epoch")
            if resetEpoch == 0 || Double(raw) <= Date().timeIntervalSince1970 - resetEpoch {
                appleSecs = raw
            }
        }
        return max(suite.integer(forKey: "todayTotalSeconds"), appleSecs)
    }

    private(set) var pushToken: String? {
        didSet {
            if let token = pushToken {
                UserDefaults.standard.set(token, forKey: "liveActivityPushToken")
                print("[LiveActivity] 🔑 Push token saved: \(token.prefix(16))...")
                // LiftOffApp observer θα στείλει το token στο Supabase
            }
        }
    }

    var isRunning: Bool {
        guard let activity = currentActivity else { return false }
        return activity.activityState == .active
    }

    init() {
        recoverExistingActivity()
    }

    // MARK: - Recovery

    private func recoverExistingActivity() {
        let activities = Activity<LiftOffActivityAttributes>.activities

        // Only recover activities that are truly active — dismissed activities cannot
        // be updated and must not block creation of a fresh one on next launch.
        if let existing = activities.first(where: { $0.activityState == .active }) {
            currentActivity = existing
            print("✅ Recovered existing Live Activity (state: .active)")
            observeActivity(existing)
        }

        // Clean up any ended or dismissed stragglers
        let stale = activities.filter { $0.activityState != .active }
        if !stale.isEmpty {
            Task {
                for activity in stale {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                print("🧹 Ended \(stale.count) stale/dismissed Live Activities")
            }
        }
    }

    private func observeActivity(_ activity: Activity<LiftOffActivityAttributes>) {
        Task {
            for await pushTokenData in activity.pushTokenUpdates {
                let token = pushTokenData.map { String(format: "%02x", $0) }.joined()
                await MainActor.run { self.pushToken = token }
                // Upload immediately so the edge function can find the token
                // as soon as the next pickup is recorded.
                await PushNotificationManager.shared.registerLiveActivityToken(token)
            }
        }

        Task {
            for await state in activity.activityStateUpdates {
                if state == .ended || state == .dismissed {
                    await MainActor.run {
                        if self.currentActivity?.id == activity.id {
                            self.currentActivity = nil
                            self.pushToken = nil
                            print("[LiveActivity] ⚠️ Activity \(state == .dismissed ? "dismissed" : "ended") externally — cleared reference")
                        }
                    }

                    // Auto-restart after accidental swipe-dismiss (e.g. WiiM taking over DI).
                    // Respects the user's explicit "disable" choice in SettingsView:
                    // liveActivityEnabled defaults to true, is false only when user turned it off.
                    if state == .dismissed {
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 s
                        let shouldRestart = await MainActor.run {
                            let enabled = UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
                            return enabled && self.currentActivity == nil
                        }
                        guard shouldRestart else { continue }
                        let suite = UserDefaults(suiteName: "group.fotiospongas.picksy") ?? UserDefaults.standard
                        let pickups = suite.integer(forKey: "todayPickups")
                        let rawGoal = UserDefaults.standard.integer(forKey: "dailyGoal")
                        let goal = rawGoal > 0 ? rawGoal : 50
                        await MainActor.run {
                            self.start(pickupCount: pickups, dailyGoal: goal)
                            print("[LiveActivity] 🔄 Auto-restarted after external dismissal")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Start

    func start(pickupCount: Int, dailyGoal: Int) {
        let info = ActivityAuthorizationInfo()
        print("[LiveActivity] areActivitiesEnabled: \(info.areActivitiesEnabled)")
        print("[LiveActivity] frequentPushesEnabled: \(info.frequentPushesEnabled)")

        guard info.areActivitiesEnabled else {
            print("[LiveActivity] ❌ Live Activities not enabled by user")
            return
        }

        // Μόνο αν η activity είναι πραγματικά .active — stale/ended πέφτουν through
        if isRunning {
            update(pickupCount: pickupCount)
            print("ℹ️ Live Activity already running — updated instead")
            return
        }

        // Καθάρισε stale/ended reference
        if currentActivity != nil {
            currentActivity = nil
        }

        // Recover an active system activity if one exists.
        // IMPORTANT: skip .dismissed activities — they can't be updated and would
        // silently block creation of a fresh activity, leaving the DI blank.
        let systemActivities = Activity<LiftOffActivityAttributes>.activities
        if let existing = systemActivities.first(where: { $0.activityState == .active }) {
            currentActivity = existing
            observeActivity(existing)
            update(pickupCount: pickupCount)
            print("ℹ️ Recovered active system Live Activity — updating")
            return
        }
        // End any dismissed/ended activities so iOS doesn't hit per-app limits
        Task {
            for old in systemActivities where old.activityState != .active {
                await old.end(nil, dismissalPolicy: .immediate)
            }
        }

        let attributes = LiftOffActivityAttributes(dailyGoal: dailyGoal)

        // Start in duel mode if a duel is already active
        let duel = DuelManager.shared.activeDuel.flatMap { $0.status == .active ? $0 : nil }
        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: pickupCount,
            currentQuote: duel != nil ? "⚔️ Duel vs \(duel!.theirName)" : QuoteBank.random(),
            lastPickupTime: Date(),
            focusEndTime: nil,
            focusPickupCount: 0,
            duelOpponentName: duel?.theirName,
            duelMySecs: duel.map { myDuelSecs($0) } ?? 0,
            duelTheirSecs: duel?.theirScreenTime ?? 0
        )

        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            relevanceScore: 100 // midnight tonight
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .token   // enables server-side APNs updates for the Dynamic Island
            )
            currentActivity = activity
            print("✅ Live Activity started!")
            observeActivity(activity)
        } catch {
            print("❌ Error starting Live Activity: \(error)")
        }
    }

    // MARK: - Update
    //
    // Smart update: if a duel is active, automatically shows the duel score
    // so that ANY caller (silent push, NudgeView, focus end, etc.) never
    // accidentally overwrites the duel Dynamic Island with the plain pickup count.

    func update(pickupCount: Int) {
        guard let activity = currentActivity else { return }

        // Duel takes priority over normal mode (Focus callers use updateForFocus directly)
        if let duel = DuelManager.shared.activeDuel, duel.status == .active {
            let state = LiftOffActivityAttributes.ContentState(
                pickupCount: pickupCount,
                currentQuote: "⚔️ Duel vs \(duel.theirName)",
                lastPickupTime: Date(),
                focusEndTime: nil,
                focusPickupCount: 0,
                duelOpponentName: duel.theirName,
                duelMySecs: myDuelSecs(duel),
                duelTheirSecs: duel.theirScreenTime
            )
            let content = ActivityContent(
                state: state,
                staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            relevanceScore: 100
            )
            Task { await activity.update(content) }
            return
        }

        // Normal mode
        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: pickupCount,
            currentQuote: QuoteBank.random(),
            lastPickupTime: Date(),
            focusEndTime: nil,
            focusPickupCount: 0,
            duelOpponentName: nil,
            duelMySecs: 0,
            duelTheirSecs: 0
        )
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            relevanceScore: 100
        )
        Task { await activity.update(content) }
    }

    // MARK: - Focus Update

    func updateForFocus(pickupCount: Int, focusEndTime: Date?, focusPickupCount: Int) {
        guard let activity = currentActivity else { return }
        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: pickupCount,
            currentQuote: focusEndTime != nil ? "Stay present 🍃" : QuoteBank.random(),
            lastPickupTime: Date(),
            focusEndTime: focusEndTime,
            focusPickupCount: focusPickupCount,
            duelOpponentName: nil,
            duelMySecs: 0,
            duelTheirSecs: 0
        )
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            relevanceScore: 100 // midnight tonight
        )
        Task { await activity.update(content) }
    }

    // MARK: - Duel Update

    func updateForDuel(pickupCount: Int, opponentName: String, mySecs: Int, theirSecs: Int) {
        guard let activity = currentActivity else { return }
        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: pickupCount,
            currentQuote: "⚔️ Duel vs \(opponentName)",
            lastPickupTime: Date(),
            focusEndTime: nil,
            focusPickupCount: 0,
            duelOpponentName: opponentName,
            duelMySecs: mySecs,
            duelTheirSecs: theirSecs
        )
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            relevanceScore: 100
        )
        Task { await activity.update(content) }
    }

    // MARK: - Async update (for background pickup callback)
    //
    // The sync variants above fire `Task { await activity.update() }` and return
    // immediately. When called from a UIBackgroundTask, iOS may re-suspend the app
    // before the detached Task runs — so the DI never updates.
    //
    // These async variants properly await `activity.update()`, allowing the caller
    // to keep the UIBackgroundTask alive until the DI is actually updated.

    /// Awaitable update — use from `onPickupDetected` background callback only.
    /// Applies the same duel/focus/normal priority logic as `update()`.
    func updateAsync(pickupCount: Int) async {
        guard let activity = currentActivity else { return }
        if let duel = DuelManager.shared.activeDuel, duel.status == .active {
            let state = LiftOffActivityAttributes.ContentState(
                pickupCount: pickupCount,
                currentQuote: "⚔️ Duel vs \(duel.theirName)",
                lastPickupTime: Date(),
                focusEndTime: nil,
                focusPickupCount: 0,
                duelOpponentName: duel.theirName,
                duelMySecs: myDuelSecs(duel),
                duelTheirSecs: duel.theirScreenTime
            )
            let content = ActivityContent(
                state: state,
                staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            relevanceScore: 100
            )
            await activity.update(content)
            return
        }
        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: pickupCount,
            currentQuote: QuoteBank.random(),
            lastPickupTime: Date(),
            focusEndTime: nil,
            focusPickupCount: 0,
            duelOpponentName: nil,
            duelMySecs: 0,
            duelTheirSecs: 0
        )
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            relevanceScore: 100
        )
        await activity.update(content)
    }

    func updateForFocusAsync(pickupCount: Int, focusEndTime: Date?, focusPickupCount: Int) async {
        guard let activity = currentActivity else { return }
        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: pickupCount,
            currentQuote: focusEndTime != nil ? "Stay present 🍃" : QuoteBank.random(),
            lastPickupTime: Date(),
            focusEndTime: focusEndTime,
            focusPickupCount: focusPickupCount,
            duelOpponentName: nil,
            duelMySecs: 0,
            duelTheirSecs: 0
        )
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            relevanceScore: 100
        )
        await activity.update(content)
    }

    // MARK: - Stop

    func stop() {
        guard let activity = currentActivity else { return }

        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: 0,
            currentQuote: "See you tomorrow!",
            lastPickupTime: Date(),
            focusEndTime: nil,
            focusPickupCount: 0,
            duelOpponentName: nil,
            duelMySecs: 0,
            duelTheirSecs: 0
        )

        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        pushToken = nil
        UserDefaults.standard.removeObject(forKey: "liveActivityPushToken")
    }

    func stopAll() {
        Task {
            for activity in Activity<LiftOffActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
        pushToken = nil
        UserDefaults.standard.removeObject(forKey: "liveActivityPushToken")
    }
}

