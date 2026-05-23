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
        // Duel mode — nil opponentName means no active duel
        var duelOpponentName: String? // e.g. "Alex"
        var duelMyPickups:    Int     // my pickups in the duel
        var duelTheirPickups: Int     // opponent's pickups in the duel
    }
    
    // Στατικά δεδομένα (δεν αλλάζουν κατά τη διάρκεια)
    var dailyGoal: Int
}

