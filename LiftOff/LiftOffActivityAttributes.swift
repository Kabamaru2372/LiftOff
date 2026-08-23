//
//  LiftOffActivityAttributes.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
// LiftOffActivityAttributes.swift
// Unpluq
//
// Αυτό ορίζει τι δεδομένα δείχνει το Live Activity.
// Πρέπει να είναι προσβάσιμο ΚΑΙ από την app ΚΑΙ από το widget.
//
// ActivityAttributes = "τι πληροφορίες χρειάζεται το Live Activity"
// Έχει δύο μέρη:
//   1. Στατικά δεδομένα (δεν αλλάζουν) — π.χ. όνομα χρήστη
//   2. ContentState (αλλάζουν live) — π.χ. αριθμός pickups

import ActivityKit
import Foundation

struct LiftOffActivityAttributes: ActivityAttributes {
    // ContentState = τα δεδομένα που αλλάζουν σε real-time
    public struct ContentState: Codable, Hashable {
        var pickupCount: Int
        var currentQuote: String
        var lastPickupTime: Date
        var focusEndTime: Date?       // nil = not in focus mode
        var focusPickupCount: Int     // pickups during this focus session
        // Duel mode — nil opponentName means no active duel.
        // Duel metric = SCREEN TIME (seconds), same as DuelRecord.myScore —
        // the DI/Lock Screen must show the number the duel is judged on.
        var duelOpponentName: String? // e.g. "Alex"
        var duelMySecs:    Int        // my screen time in the duel (seconds)
        var duelTheirSecs: Int        // opponent's screen time (seconds)
        // Today's screen time (seconds), outside duel mode. Tracked via
        // DeviceActivityMonitor thresholds — unlike pickupCount, this stays
        // accurate even while the app is suspended, so the normal (non-duel,
        // non-focus) DI leads with this instead of the pickup heuristic.
        var screenTimeSecs: Int = 0
        // "Plant health" (0-100) for the normal-mode growth animation. Grows
        // continuously while the phone stays down; WILTS continuously in real
        // time for as long as a screen session is active (isWilting == true),
        // so picking the phone up visibly hurts the plant immediately instead
        // of only at the next lock. Stored as a (baseline, time, isWilting)
        // triple rather than a live value so the DI can extrapolate between
        // updates without needing a push every second — the widget computes
        // isWilting ? max(0, baseline - secondsSince(baselineTime) * wiltRate)
        //           : min(100, baseline + secondsSince(baselineTime) * growthRate).
        // See DataStore.plantGrowthRatePerSecond/plantWiltRatePerSecond.
        var plantHealthBaseline: Double = 0
        var plantHealthBaselineTime: Date = .distantPast
        var plantHealthIsWilting: Bool = false
    }

    // Στατικά δεδομένα (δεν αλλάζουν κατά τη διάρκεια)
    var dailyGoal: Int
}
