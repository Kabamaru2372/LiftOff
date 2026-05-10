//
//  LiveActivityManager.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
//  v1.6 UPDATE: pushType: .token για remote Live Activity updates.
//  Το Dynamic Island ενημερώνεται ΑΜΕΣΩΣ από APNs push
//  χωρίς να χρειάζεται το main app να είναι alive.
//

import ActivityKit
import Foundation

@Observable
class LiveActivityManager {

    private var currentActivity: Activity<LiftOffActivityAttributes>?

    /// Push token για Live Activity remote updates.
    /// Αποθηκεύεται στο UserDefaults για access από extension.
    private(set) var pushToken: String? {
        didSet {
            if let token = pushToken {
                UserDefaults.standard.set(token, forKey: "liveActivityPushToken")
                print("[LiveActivity] 🔑 Push token saved: \(token.prefix(16))...")

                // Στείλε token στο Supabase
                Task {
                    await PushNotificationManager.shared.registerLiveActivityToken(token)
                }
            }
        }
    }

    var isRunning: Bool {
        currentActivity != nil
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

            // Observe push token αν υπάρχει ήδη
            Task {
                for await pushTokenData in existing.pushTokenUpdates {
                    let token = pushTokenData.map { String(format: "%02x", $0) }.joined()
                    await MainActor.run {
                        self.pushToken = token
                    }
                }
            }

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

    // MARK: - Start

    func start(pickupCount: Int, dailyGoal: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }

        if let existing = currentActivity {
            update(pickupCount: pickupCount)
            print("ℹ️ Live Activity already running — updated instead")
            return
        }

        let systemActivities = Activity<LiftOffActivityAttributes>.activities
        if let existing = systemActivities.first {
            currentActivity = existing
            update(pickupCount: pickupCount)
            print("ℹ️ Found existing system Live Activity — using it")
            return
        }

        let attributes = LiftOffActivityAttributes(dailyGoal: dailyGoal)
        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: pickupCount,
            currentQuote: QuoteBank.random(),
            lastPickupTime: Date()
        )

        let content = ActivityContent(state: state, staleDate: nil)

        do {
            // v1.6: pushType: .token για remote updates από APNs
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
            print("✅ Live Activity started!")

            // Observe push token updates
            if let activity = currentActivity {
                Task {
                    for await pushTokenData in activity.pushTokenUpdates {
                        let token = pushTokenData.map { String(format: "%02x", $0) }.joined()
                        await MainActor.run {
                            self.pushToken = token
                        }
                    }
                }
            }

        } catch {
            print("❌ Error starting Live Activity: \(error)")
        }
    }

    // MARK: - Update (local)

    func update(pickupCount: Int) {
        guard let activity = currentActivity else { return }

        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: pickupCount,
            currentQuote: QuoteBank.random(),
            lastPickupTime: Date()
        )

        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.update(content)
        }
    }

    // MARK: - Stop

    func stop() {
        guard let activity = currentActivity else { return }

        let state = LiftOffActivityAttributes.ContentState(
            pickupCount: 0,
            currentQuote: "See you tomorrow!",
            lastPickupTime: Date()
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

