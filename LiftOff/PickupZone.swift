//
//  PickupZone.swift
//  Picksy
//
//  Created by Fotios Pongas on 04.05.2026
//
//  Defines the 5 usage zones based on peer-reviewed research:
//
//  - Excellent (0-50):    Top 15% of users (mindful use)
//  - Good (51-100):       Top 40% (healthy range, Rosen 2016 baseline)
//  - Average (101-150):   ~50th percentile (room to improve)
//  - Heavy (151-200):     Top 25% (consider cutting back)
//  - Problematic (201+):  ~10% population, high-risk threshold
//
//  Scientific basis:
//  • Rosen, L.D., Carrier, L.M., Cheever, N.A. (2016). The Distracted
//    Mind: Ancient Brains in a High-Tech World. MIT Press.
//    Found that average users check phones 50-100 times/day.
//  • Nottingham Trent University (2020). "Passive Objective Measures in
//    the Assessment of Problematic Smartphone Use: A Systematic Review."
//  • Keimyung University, South Korea (2018). "Analysis of Behavioral
//    Characteristics of Smartphone Addiction Using Data Mining."
//    Both identified ~110 pickups/day as high-risk threshold.
//  • Reviews.org (2026). "2026 Cell Phone Usage Stats" - reported
//    average 186 daily pickups across U.S. population.
//

import SwiftUI

enum PickupZone: String, CaseIterable {
    case excellent
    case good
    case average
    case heavy
    case problematic

    // MARK: - Range Detection

    /// Determines the zone for a given pickup count.
    static func zone(for pickups: Int) -> PickupZone {
        switch pickups {
        case 0...50:    return .excellent
        case 51...100:  return .good
        case 101...150: return .average
        case 151...200: return .heavy
        default:        return .problematic
        }
    }

    // MARK: - Goal-relative mapping (home-screen ring)

    /// Maps progress toward the user's *personal* daily goal (pickups / goal)
    /// to a zone, so the home-screen ring color + badge reflect how close they
    /// are to their own target — not the absolute research zones.
    ///
    /// Reuses the same 5-color palette:
    ///   < 40%  green   • 40–70% soft green • 70–90% yellow
    ///   90–100% orange • ≥ 100% red
    static func goalZone(progress: Double) -> PickupZone {
        switch progress {
        case ..<0.40: return .excellent
        case ..<0.70: return .good
        case ..<0.90: return .average
        case ...1.00: return .heavy     // includes exactly at goal — "Over goal" only when strictly above
        default:      return .problematic
        }
    }

    /// Goal-relative badge label — kinder than the absolute research labels
    /// (e.g. someone 1 pickup over a tight self-set goal shouldn't read
    /// "Problematic").
    func goalDisplayName(language: String) -> String {
        switch (self, language) {
        case (.excellent, "Ελληνικά"):    return "Άνετα"
        case (.excellent, "Deutsch"):      return "Locker"
        case (.excellent, _):              return "Comfortable"

        case (.good, "Ελληνικά"):          return "Καλά"
        case (.good, "Deutsch"):           return "Gut"
        case (.good, _):                   return "On track"

        case (.average, "Ελληνικά"):       return "Προσοχή"
        case (.average, "Deutsch"):        return "Achtung"
        case (.average, _):                return "Heads up"

        case (.heavy, "Ελληνικά"):         return "Κοντά στο όριο"
        case (.heavy, "Deutsch"):          return "Nahe am Limit"
        case (.heavy, _):                  return "Near limit"

        case (.problematic, "Ελληνικά"):   return "Πάνω από στόχο"
        case (.problematic, "Deutsch"):    return "Über dem Ziel"
        case (.problematic, _):            return "Over goal"
        }
    }

    // MARK: - Range Display

    /// Lower bound of the zone (inclusive).
    var lowerBound: Int {
        switch self {
        case .excellent:    return 0
        case .good:         return 51
        case .average:      return 101
        case .heavy:        return 151
        case .problematic:  return 201
        }
    }

    /// Upper bound of the zone (inclusive). nil = no upper limit.
    var upperBound: Int? {
        switch self {
        case .excellent:    return 50
        case .good:         return 100
        case .average:      return 150
        case .heavy:        return 200
        case .problematic:  return nil
        }
    }

    // MARK: - Visual

    /// Primary color for UI display.
    var color: Color {
        switch self {
        case .excellent:    return Color(red: 0.20, green: 0.78, blue: 0.35)  // Vibrant green
        case .good:         return Color(red: 0.40, green: 0.70, blue: 0.40)  // Soft green
        case .average:      return Color(red: 0.95, green: 0.77, blue: 0.06)  // Warm yellow
        case .heavy:        return Color(red: 0.95, green: 0.55, blue: 0.10)  // Orange
        case .problematic:  return Color(red: 0.85, green: 0.25, blue: 0.20)  // Strong red
        }
    }

    /// SF Symbol name representing the zone.
    var iconName: String {
        switch self {
        case .excellent:    return "leaf.fill"
        case .good:         return "checkmark.seal.fill"
        case .average:      return "exclamationmark.circle.fill"
        case .heavy:        return "exclamationmark.triangle.fill"
        case .problematic:  return "exclamationmark.octagon.fill"
        }
    }

    // MARK: - Localization

    /// Display name for the zone.
    func displayName(language: String) -> String {
        switch (self, language) {
        case (.excellent, "Ελληνικά"):    return "Εξαιρετικά"
        case (.excellent, "Deutsch"):      return "Ausgezeichnet"
        case (.excellent, _):              return "Excellent"

        case (.good, "Ελληνικά"):          return "Καλά"
        case (.good, "Deutsch"):           return "Gut"
        case (.good, _):                   return "Good"

        case (.average, "Ελληνικά"):       return "Μέτρια"
        case (.average, "Deutsch"):        return "Durchschnittlich"
        case (.average, _):                return "Average"

        case (.heavy, "Ελληνικά"):         return "Έντονη χρήση"
        case (.heavy, "Deutsch"):          return "Starke Nutzung"
        case (.heavy, _):                  return "Heavy use"

        case (.problematic, "Ελληνικά"):   return "Προβληματική"
        case (.problematic, "Deutsch"):    return "Problematisch"
        case (.problematic, _):            return "Problematic"
        }
    }

    /// Short summary describing the zone.
    func summary(language: String) -> String {
        switch (self, language) {
        case (.excellent, "Ελληνικά"):    return "Είσαι στο top 15% των χρηστών. Mindful use."
        case (.excellent, "Deutsch"):      return "Du gehörst zu den Top 15% der Nutzer. Bewusste Nutzung."
        case (.excellent, _):              return "You're in the top 15% of users. Mindful use."

        case (.good, "Ελληνικά"):          return "Υγιής χρήση. Καλή ισορροπία."
        case (.good, "Deutsch"):           return "Gesunde Nutzung. Gutes Gleichgewicht."
        case (.good, _):                   return "Healthy use. Good balance."

        case (.average, "Ελληνικά"):       return "Μέσος όρος. Υπάρχει περιθώριο βελτίωσης."
        case (.average, "Deutsch"):        return "Durchschnitt. Es gibt Verbesserungspotenzial."
        case (.average, _):                return "Average use. Room to improve."

        case (.heavy, "Ελληνικά"):         return "Σκέψου να μειώσεις λίγο τη χρήση."
        case (.heavy, "Deutsch"):          return "Erwäge, deine Nutzung zu reduzieren."
        case (.heavy, _):                  return "Consider cutting back on your usage."

        case (.problematic, "Ελληνικά"):   return "Υψηλού κινδύνου χρήση. Καιρός να βάλεις όρια."
        case (.problematic, "Deutsch"):    return "Hochriskante Nutzung. Zeit für Grenzen."
        case (.problematic, _):            return "High-risk usage. Time to set boundaries."
        }
    }

    // MARK: - Notification Triggers

    /// Determines if this zone triggers a notification.
    /// Only Average, Heavy, and Problematic trigger notifications.
    /// Excellent and Good zones celebrate silently.
    var triggersNotification: Bool {
        switch self {
        case .excellent, .good:           return false
        case .average, .heavy, .problematic: return true
        }
    }
}
