//
//  LiveActivityManager.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
// Διαχειρίζεται το Live Activity — ξεκινάει, ενημερώνει, σταματάει.
// Καλείται από τον PickupDetector και τον DataStore.

import ActivityKit
import Foundation

@Observable
class LiveActivityManager {

    private var currentActivity: Activity<LiftOffActivityAttributes>?

    var isRunning: Bool {
        currentActivity != nil
    }

    init() {
        // Στο app start, βρες αν υπάρχει ήδη ενεργό Live Activity
        // και κράτα το reference αντί να φτιάξεις νέο
        recoverExistingActivity()
    }

    /// Αν υπάρχει ήδη ενεργό Live Activity από προηγούμενο session,
    /// το χρησιμοποιούμε αντί να φτιάξουμε νέο
    private func recoverExistingActivity() {
        let activities = Activity<LiftOffActivityAttributes>.activities
        if let existing = activities.first {
            currentActivity = existing
            print("✅ Recovered existing Live Activity")

            // Σταμάτα τα τυχόν επιπλέον (αν υπάρχουν duplicates)
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

    func start(pickupCount: Int, dailyGoal: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }

        // ΣΗΜΑΝΤΙΚΟ: Έλεγχος αν υπάρχει ήδη activity (από προηγούμενο session)
        if let existing = currentActivity {
            // Update αντί για new
            update(pickupCount: pickupCount)
            print("ℹ️ Live Activity already running — updated instead")
            return
        }

        // Έλεγχος και στο system-level activities list (extra safety)
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
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("✅ Live Activity started!")
        } catch {
            print("❌ Error starting Live Activity: \(error)")
        }
    }

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
    }

    /// Σταματάει ΟΛΑ τα ενεργά Live Activities (cleanup)
    func stopAll() {
        Task {
            for activity in Activity<LiftOffActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }
}

