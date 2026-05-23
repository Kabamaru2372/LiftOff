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
        if let existing = activities.first {
            currentActivity = existing
            print("✅ Recovered existing Live Activity")

            observeActivity(existing)

            if activities.count > 1 {
                Task {
                    for activity in activities.dropFirst() {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                    print("🧹 Cleaned up \(activities.count - 1) duplicate Live Activities")
                }
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
                            print("[LiveActivity] ⚠️ Activity ended externally — cleared reference")
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

        // Έλεγξε αν υπάρχει system activity που μπορεί να ανακτηθεί
        let systemActivities = Activity<LiftOffActivityAttributes>.activities
        if let existing = systemActivities.first, existing.activityState != .ended {
            currentActivity = existing
            observeActivity(existing)
            update(pickupCount: pickupCount)
            print("ℹ️ Recovered system Live Activity (state: \(existing.activityState)) — updating")
            return
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
            duelMyPickups: duel != nil ? pickupCount : 0,
            duelTheirPickups: duel?.theirPickups ?? 0
        )

        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)) // midnight tonight
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
                duelMyPickups: pickupCount,       // caller always passes the current local count
                duelTheirPickups: duel.theirPickups
            )
            let content = ActivityContent(
                state: state,
                staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
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
            duelMyPickups: 0,
            duelTheirPickups: 0
        )
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
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
            duelMyPickups: 0,
            duelTheirPickups: 0
        )
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)) // midnight tonight
        )
        Task { await activity.update(content) }
    }

    // MARK: - Duel Update

    func updateForDuel(pickupCount: Int, opponentName: String, myPickups: Int, theirPickups: Int) {
        guard let activity = currentActivity else { return }
        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: pickupCount,
            currentQuote: "⚔️ Duel vs \(opponentName)",
            lastPickupTime: Date(),
            focusEndTime: nil,
            focusPickupCount: 0,
            duelOpponentName: opponentName,
            duelMyPickups: myPickups,
            duelTheirPickups: theirPickups
        )
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        )
        Task { await activity.update(content) }
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
            duelMyPickups: 0,
            duelTheirPickups: 0
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

