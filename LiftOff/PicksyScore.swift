//
//  PicksyScore.swift
//  Picksy
//
//  Single source of truth for the Picksy Score so every surface (Nudge, Stats,
//  Friends, Duel) computes it identically.
//
//  Lower = better. Weighting is 1× per pickup and 5× per screen-time minute
//  (a minute of use is as "costly" as five pickups). The raw sum is then scaled
//  down (÷20) so a typical day lands roughly in the 0–100 range instead of the
//  hundreds/thousands — e.g. a 6h / 79-pickup day was 1879, now ≈ 94.
//
//  The scaling is monotonic, so head-to-head comparisons (Duels, Friends) are
//  unaffected: dividing both sides by the same factor never changes the winner.
//

import Foundation

enum PicksyScore {

    /// Divides the raw (pickups + minutes×5) sum into a friendlier range.
    static let scaleDivisor = 20

    /// Picksy Score from pickups and screen-time minutes. Lower = better.
    static func value(pickups: Int, screenTimeMinutes: Int) -> Int {
        let raw = pickups + screenTimeMinutes * 5
        // Rounded integer division.
        return (raw + scaleDivisor / 2) / scaleDivisor
    }

    /// Convenience overload taking screen time in seconds.
    static func value(pickups: Int, screenTimeSeconds: Int) -> Int {
        value(pickups: pickups, screenTimeMinutes: screenTimeSeconds / 60)
    }
}
