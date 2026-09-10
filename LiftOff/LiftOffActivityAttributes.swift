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

        enum CodingKeys: String, CodingKey {
            case pickupCount, currentQuote, lastPickupTime, focusEndTime, focusPickupCount
            case duelOpponentName, duelMySecs, duelTheirSecs, screenTimeSecs
            case plantHealthBaseline, plantHealthBaselineTime, plantHealthIsWilting
        }
    }

    // Στατικά δεδομένα (δεν αλλάζουν κατά τη διάρκεια)
    var dailyGoal: Int
}

extension LiftOffActivityAttributes.ContentState {
    /// Tolerant decode: every key falls back to a default when it's absent.
    ///
    /// Swift's synthesized `Decodable` ignores stored-property defaults and
    /// hard-fails (`keyNotFound`) on ANY missing key. That's exactly what
    /// happens when the NEW widget binary is asked to decode a Live Activity
    /// whose ContentState was persisted by the PREVIOUS app version — it has
    /// no `screenTimeSecs` / `plantHealth*` keys. A decode failure there, right
    /// after an app update, is a well-known ActivityKit crash-spike source.
    /// Keeping this initializer in an extension preserves the synthesized
    /// memberwise initializer the app's own construction sites rely on.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pickupCount:             try c.decodeIfPresent(Int.self,    forKey: .pickupCount) ?? 0,
            currentQuote:            try c.decodeIfPresent(String.self, forKey: .currentQuote) ?? "",
            lastPickupTime:          try c.decodeIfPresent(Date.self,   forKey: .lastPickupTime) ?? Date(),
            focusEndTime:            try c.decodeIfPresent(Date.self,   forKey: .focusEndTime),
            focusPickupCount:        try c.decodeIfPresent(Int.self,    forKey: .focusPickupCount) ?? 0,
            duelOpponentName:        try c.decodeIfPresent(String.self, forKey: .duelOpponentName),
            duelMySecs:              try c.decodeIfPresent(Int.self,    forKey: .duelMySecs) ?? 0,
            duelTheirSecs:           try c.decodeIfPresent(Int.self,    forKey: .duelTheirSecs) ?? 0,
            screenTimeSecs:          try c.decodeIfPresent(Int.self,    forKey: .screenTimeSecs) ?? 0,
            plantHealthBaseline:     try c.decodeIfPresent(Double.self, forKey: .plantHealthBaseline) ?? 0,
            plantHealthBaselineTime: try c.decodeIfPresent(Date.self,   forKey: .plantHealthBaselineTime) ?? .distantPast,
            plantHealthIsWilting:    try c.decodeIfPresent(Bool.self,   forKey: .plantHealthIsWilting) ?? false
        )
    }
}
