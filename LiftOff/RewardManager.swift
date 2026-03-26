//
//  RewardManager.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
// RewardManager.swift
// Unpluq
//
// Ελέγχει αν ο χρήστης βελτιώθηκε στις "χειρότερες ώρες" του
// και ξεκλειδώνει rewards.

import Foundation
import SwiftUI

// Τύποι rewards
enum RewardType: String, Codable, CaseIterable {
    case quotePack = "Quote Pack"
    case badge = "Badge"
    case giftCode = "Gift Code"
}

// Ένα unlocked reward
struct Reward: Identifiable, Codable {
    let id: String
    let type: RewardType
    let title: String
    let description: String
    let unlockedDate: Date
    var claimed: Bool
    
    // Τα quote packs που μπορεί να ξεκλειδώσει
    var quotePack: String? // π.χ. "stoic", "humor", "philosophy"
}

@Observable
class RewardManager {
    
    var unlockedRewards: [Reward] = []
    var pendingReward: Reward? = nil  // Δείχνεται σαν popup
    
    private let defaults = UserDefaults.standard
    private let storageKey = "unlockedRewards"
    
    // Όλα τα διαθέσιμα rewards
    static let availableRewards: [(type: RewardType, title: String, titleGR: String, description: String, descriptionGR: String, quotePack: String?)] = [
        // Quote packs
        (.quotePack, "Stoic Wisdom", "Στωική Σοφία",
         "20 quotes from Marcus Aurelius, Seneca, and Epictetus",
         "20 αποφθέγματα από Μάρκο Αυρήλιο, Σενέκα και Επίκτητο",
         "stoic"),
        (.quotePack, "Humor Pack", "Πακέτο Χιούμορ",
         "20 funny nudges that make you smile and put it down",
         "20 αστεία nudges που σε κάνουν να χαμογελάσεις",
         "humor"),
        (.quotePack, "Philosophy Pack", "Πακέτο Φιλοσοφίας",
         "20 deep thoughts from great thinkers",
         "20 βαθιές σκέψεις από μεγάλους στοχαστές",
         "philosophy"),
        
        // Badges
        (.badge, "First Step", "Πρώτο Βήμα",
         "Improved your worst hour for the first time",
         "Βελτίωσες τη χειρότερη ώρα σου για πρώτη φορά",
         nil),
        (.badge, "Mindful Morning", "Συνειδητό Πρωί",
         "Reduced morning pickups (6-9 AM)",
         "Μείωσες τα πρωινά pickups (6-9)",
         nil),
        (.badge, "Night Owl Tamed", "Κουκουβάγια Ημερωμένη",
         "Reduced late night pickups (22-01)",
         "Μείωσες τα βραδινά pickups (22-01)",
         nil),
        (.badge, "Lunch Break Hero", "Ήρωας Μεσημεριανού",
         "Reduced lunch break pickups (12-14)",
         "Μείωσες τα pickups στο μεσημεριανό (12-14)",
         nil),
        (.badge, "Week Warrior", "Πολεμιστής Εβδομάδας",
         "Improved 3 different hours in one week",
         "Βελτίωσες 3 διαφορετικές ώρες σε μια εβδομάδα",
         nil),
        
        // Gift codes
        (.giftCode, "Pay It Forward", "Πρόσφερέ το",
         "Share LiftOff+ with a friend at 50% off",
         "Μοιράσου το LiftOff+ με φίλο στη μισή τιμή",
         nil),
    ]
    
    init() {
        loadRewards()
    }
    
    // Ελέγχει αν πρέπει να δοθεί reward
    func checkForRewards(tracker: HourlyTracker) {
        let worstHours = tracker.worstHours
        
        for worst in worstHours {
            if tracker.hasImproved(hour: worst.hour) {
                // Βρες reward που δεν έχει ξεκλειδωθεί ακόμα
                if let reward = nextAvailableReward(forHour: worst.hour) {
                    unlockReward(reward)
                    break  // Ένα reward τη φορά
                }
            }
        }
    }
    
    private func nextAvailableReward(forHour hour: Int) -> Reward? {
        let unlockedIds = Set(unlockedRewards.map { $0.id })
        
        // Πρώτα δώσε time-specific badges
        if (6...8).contains(hour) && !unlockedIds.contains("badge_morning") {
            return makeReward(id: "badge_morning", index: 4)
        }
        if (22...23).contains(hour) || hour == 0 {
            if !unlockedIds.contains("badge_night") {
                return makeReward(id: "badge_night", index: 5)
            }
        }
        if (12...13).contains(hour) && !unlockedIds.contains("badge_lunch") {
            return makeReward(id: "badge_lunch", index: 6)
        }
        
        // First Step badge
        if !unlockedIds.contains("badge_first") {
            return makeReward(id: "badge_first", index: 3)
        }
        
        // Quote packs
        for (i, available) in Self.availableRewards.enumerated() {
            if available.type == .quotePack {
                let rewardId = "quote_\(available.quotePack ?? "unknown")"
                if !unlockedIds.contains(rewardId) {
                    return makeReward(id: rewardId, index: i)
                }
            }
        }
        
        // Gift code (μετά από αρκετά rewards)
        if unlockedRewards.count >= 3 && !unlockedIds.contains("gift_forward") {
            return makeReward(id: "gift_forward", index: 8)
        }
        
        return nil
    }
    
    private func makeReward(id: String, index: Int) -> Reward {
        let available = Self.availableRewards[index]
        return Reward(
            id: id,
            type: available.type,
            title: available.title,
            description: available.description,
            unlockedDate: Date(),
            claimed: false,
            quotePack: available.quotePack
        )
    }
    
    private func unlockReward(_ reward: Reward) {
        unlockedRewards.append(reward)
        pendingReward = reward
        saveRewards()
    }
    
    func claimReward(_ reward: Reward) {
        if let index = unlockedRewards.firstIndex(where: { $0.id == reward.id }) {
            unlockedRewards[index].claimed = true
            saveRewards()
        }
        pendingReward = nil
    }
    
    func dismissReward() {
        pendingReward = nil
    }
    
    // Localized title/description
    func localizedTitle(for reward: Reward, language: String) -> String {
        if language == "Ελληνικά" {
            if let match = Self.availableRewards.first(where: { $0.title == reward.title }) {
                return match.titleGR
            }
        }
        return reward.title
    }
    
    func localizedDescription(for reward: Reward, language: String) -> String {
        if language == "Ελληνικά" {
            if let match = Self.availableRewards.first(where: { $0.title == reward.title }) {
                return match.descriptionGR
            }
        }
        return reward.description
    }
    
    // MARK: - Persistence
    
    private func saveRewards() {
        if let data = try? JSONEncoder().encode(unlockedRewards) {
            defaults.set(data, forKey: storageKey)
        }
    }
    
    private func loadRewards() {
        guard let data = defaults.data(forKey: storageKey),
              let rewards = try? JSONDecoder().decode([Reward].self, from: data)
        else { return }
        unlockedRewards = rewards
    }
}
