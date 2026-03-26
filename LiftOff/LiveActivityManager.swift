//
//  LiveActivityManager.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
// LiveActivityManager.swift
// Unpluq
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
    
    func start(pickupCount: Int, dailyGoal: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }
        
        // Αν ήδη τρέχει, μην ξεκινήσεις νέο
        if currentActivity != nil { return }
        
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
            print("Live Activity started!")
        } catch {
            print("Error starting Live Activity: \(error)")
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
            // .immediate = εξαφανίζεται αμέσως
        }
        currentActivity = nil
    }
    
    // Σταματάει ΟΛΑ τα ενεργά Live Activities (cleanup)
    func stopAll() {
        Task {
            for activity in Activity<LiftOffActivityAttributes>.activities {
                let state = LiftOffActivityAttributes.ContentState(
                    pickupCount: 0,
                    currentQuote: "",
                    lastPickupTime: Date()
                )
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
        currentActivity = nil
    }
}
