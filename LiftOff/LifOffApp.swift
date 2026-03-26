// LiftOffApp.swift
// Unpluq
//
// Created by Fotios Pongas 24.03.2026
// Αυτό είναι το entry point — το πρώτο πράγμα που τρέχει.
// Σκέψου το σαν το main() σε Python ή C.

import SwiftUI

@main
struct LiftOffApp: App {
    
    @State private var store = DataStore()
    @State private var detector = PickupDetector()
    @State private var liveActivity = LiveActivityManager()
    @State private var hourlyTracker = HourlyTracker()
    @State private var rewardManager = RewardManager()
    @State private var proManager = ProManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(detector)
                .environment(liveActivity)
                .environment(hourlyTracker)
                .environment(rewardManager)
                .environment(proManager)
                .onAppear {
                    let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
                    liveActivity.start(
                        pickupCount: store.todayPickups,
                        dailyGoal: goal > 0 ? goal : 15
                    )
                }
        }
    }
}
