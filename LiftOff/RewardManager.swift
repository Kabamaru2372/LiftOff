//
//  RewardManager.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.03.26.

import Foundation
import SwiftUI

enum RewardType: String, Codable, CaseIterable {
    case quotePack = "Quote Pack"
    case badge = "Badge"
    case giftCode = "Gift Code"
}

struct Reward: Identifiable, Codable {
    let id: String
    let type: RewardType
    let title: String
    let description: String
    let unlockedDate: Date
    var claimed: Bool
    var quotePack: String?
}

@Observable
class RewardManager {

    var unlockedRewards: [Reward] = []
    var pendingReward: Reward? = nil

    private let defaults = UserDefaults.standard
    private let storageKey = "unlockedRewards"

    static let availableRewards: [(type: RewardType, title: String, titleGR: String, titleDE: String, description: String, descriptionGR: String, descriptionDE: String, quotePack: String?)] = [
        // Quote packs
        (.quotePack, "Stoic Wisdom", "Στωική Σοφία", "Stoische Weisheit",
         "20 quotes from Marcus Aurelius, Seneca, and Epictetus",
         "20 αποφθέγματα από Μάρκο Αυρήλιο, Σενέκα και Επίκτητο",
         "20 Zitate von Marc Aurel, Seneca und Epiktet",
         "stoic"),
        (.quotePack, "Humor Pack", "Πακέτο Χιούμορ", "Humor-Paket",
         "20 funny nudges that make you smile and put it down",
         "20 αστεία nudges που σε κάνουν να χαμογελάσεις",
         "20 witzige Erinnerungen, die dich zum Lächeln bringen",
         "humor"),
        (.quotePack, "Philosophy Pack", "Πακέτο Φιλοσοφίας", "Philosophie-Paket",
         "20 deep thoughts from great thinkers",
         "20 βαθιές σκέψεις από μεγάλους στοχαστές",
         "20 tiefe Gedanken großer Denker",
         "philosophy"),

        // Badges
        (.badge, "First Step", "Πρώτο Βήμα", "Erster Schritt",
         "Improved your worst hour for the first time",
         "Βελτίωσες τη χειρότερη ώρα σου για πρώτη φορά",
         "Deine schlechteste Stunde zum ersten Mal verbessert",
         nil),
        (.badge, "Mindful Morning", "Συνειδητό Πρωί", "Achtsamer Morgen",
         "Reduced morning pickups (6-9 AM)",
         "Μείωσες τα πρωινά pickups (6-9)",
         "Morgendliche Griffe reduziert (6-9 Uhr)",
         nil),
        (.badge, "Night Owl Tamed", "Κουκουβάγια Ημερωμένη", "Nachteule gezähmt",
         "Reduced late night pickups (22-01)",
         "Μείωσες τα βραδινά pickups (22-01)",
         "Nächtliche Griffe reduziert (22-01 Uhr)",
         nil),
        (.badge, "Lunch Break Hero", "Ήρωας Μεσημεριανού", "Mittagspausen-Held",
         "Reduced lunch break pickups (12-14)",
         "Μείωσες τα pickups στο μεσημεριανό (12-14)",
         "Mittagspausen-Griffe reduziert (12-14 Uhr)",
         nil),
        (.badge, "Week Warrior", "Πολεμιστής Εβδομάδας", "Wochen-Krieger",
         "Improved 3 different hours in one week",
         "Βελτίωσες 3 διαφορετικές ώρες σε μια εβδομάδα",
         "3 verschiedene Stunden in einer Woche verbessert",
         nil),

        // Gift codes
        (.giftCode, "Pay It Forward", "Πρόσφερέ το", "Weitergeben",
         "Share Picksy Pro with a friend",
         "Μοιράσου το Picksy Pro με φίλο",
         "Picksy Pro mit einem Freund teilen",
         nil),
    ]

    init() { loadRewards() }

    func checkForRewards(tracker: HourlyTracker) {
        let worstHours = tracker.worstHours
        for worst in worstHours {
            if tracker.hasImproved(hour: worst.hour) {
                if let reward = nextAvailableReward(forHour: worst.hour) {
                    unlockReward(reward)
                    break
                }
            }
        }
    }

    private func nextAvailableReward(forHour hour: Int) -> Reward? {
        let unlockedIds = Set(unlockedRewards.map { $0.id })

        if (6...8).contains(hour) && !unlockedIds.contains("badge_morning") {
            return makeReward(id: "badge_morning", index: 4)
        }
        if (22...23).contains(hour) || hour == 0 {
            if !unlockedIds.contains("badge_night") { return makeReward(id: "badge_night", index: 5) }
        }
        if (12...13).contains(hour) && !unlockedIds.contains("badge_lunch") {
            return makeReward(id: "badge_lunch", index: 6)
        }
        if !unlockedIds.contains("badge_first") { return makeReward(id: "badge_first", index: 3) }

        for (i, available) in Self.availableRewards.enumerated() {
            if available.type == .quotePack {
                let rewardId = "quote_\(available.quotePack ?? "unknown")"
                if !unlockedIds.contains(rewardId) { return makeReward(id: rewardId, index: i) }
            }
        }

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

    func dismissReward() { pendingReward = nil }

    // MARK: - Localized strings

    func localizedTitle(for reward: Reward, language: String) -> String {
        guard let match = Self.availableRewards.first(where: { $0.title == reward.title }) else {
            return reward.title
        }
        switch language {
        case "Ελληνικά": return match.titleGR
        case "Deutsch": return match.titleDE
        default: return reward.title
        }
    }

    func localizedDescription(for reward: Reward, language: String) -> String {
        guard let match = Self.availableRewards.first(where: { $0.title == reward.title }) else {
            return reward.description
        }
        switch language {
        case "Ελληνικά": return match.descriptionGR
        case "Deutsch": return match.descriptionDE
        default: return reward.description
        }
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

