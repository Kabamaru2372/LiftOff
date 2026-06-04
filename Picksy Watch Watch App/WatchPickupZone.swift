//
//  WatchPickupZone.swift
//  Picksy Watch
//
//  Lightweight mirror of the iOS PickupZone — colors and names kept identical
//  so the Watch experience matches the phone. No notification logic here.
//

import SwiftUI

enum WatchPickupZone: String, CaseIterable {
    case excellent
    case good
    case average
    case heavy
    case problematic

    /// Determines the zone for a given pickup count (same thresholds as iOS).
    static func zone(for pickups: Int) -> WatchPickupZone {
        switch pickups {
        case 0...50:    return .excellent
        case 51...100:  return .good
        case 101...150: return .average
        case 151...200: return .heavy
        default:        return .problematic
        }
    }

    /// Primary color — matches iOS PickupZone.color exactly.
    var color: Color {
        switch self {
        case .excellent:   return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .good:        return Color(red: 0.40, green: 0.70, blue: 0.40)
        case .average:     return Color(red: 0.95, green: 0.77, blue: 0.06)
        case .heavy:       return Color(red: 0.95, green: 0.55, blue: 0.10)
        case .problematic: return Color(red: 0.85, green: 0.25, blue: 0.20)
        }
    }

    var iconName: String {
        switch self {
        case .excellent:   return "leaf.fill"
        case .good:        return "checkmark.seal.fill"
        case .average:     return "exclamationmark.circle.fill"
        case .heavy:       return "exclamationmark.triangle.fill"
        case .problematic: return "exclamationmark.octagon.fill"
        }
    }

    func displayName(language: String) -> String {
        switch (self, language) {
        case (.excellent, "Ελληνικά"):   return "Εξαιρετικά"
        case (.excellent, "Deutsch"):     return "Ausgezeichnet"
        case (.excellent, _):             return "Excellent"

        case (.good, "Ελληνικά"):         return "Καλά"
        case (.good, "Deutsch"):          return "Gut"
        case (.good, _):                  return "Good"

        case (.average, "Ελληνικά"):      return "Μέτρια"
        case (.average, "Deutsch"):       return "Durchschnittlich"
        case (.average, _):               return "Average"

        case (.heavy, "Ελληνικά"):        return "Έντονη χρήση"
        case (.heavy, "Deutsch"):         return "Starke Nutzung"
        case (.heavy, _):                 return "Heavy"

        case (.problematic, "Ελληνικά"):  return "Προβληματική"
        case (.problematic, "Deutsch"):   return "Problematisch"
        case (.problematic, _):           return "Problematic"
        }
    }
}
