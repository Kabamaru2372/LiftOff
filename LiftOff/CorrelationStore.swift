// CorrelationStore.swift
// Picksy
//
// Created by Fotios Pongas
//
// Stores daily weather + pickup snapshots and computes human-readable
// correlation insights. ("On sunny days you pick up 35% less 📱")

import Foundation

// MARK: - Daily Snapshot

struct DailySnapshot: Codable {
    let date: String              // "yyyy-MM-dd" of the DAY that ended
    let condition: WeatherCondition
    let temperature: Double
    let pickupCount: Int
}

// MARK: - Condition Summary

struct ConditionSummary {
    let condition: WeatherCondition
    let avgPickups: Double
    let days: Int
}

// MARK: - WeatherCondition Labels (for insight text)

extension WeatherCondition {

    var englishLabel: String {
        switch self {
        case .sunny:        return "sunny"
        case .partlyCloudy: return "partly cloudy"
        case .cloudy:       return "cloudy"
        case .rainy:        return "rainy"
        case .thunderstorm: return "stormy"
        case .snow:         return "snowy"
        case .foggy:        return "foggy"
        case .windy:        return "windy"
        case .hot:          return "hot"
        case .cold:         return "cold"
        case .unknown:      return "unknown"
        }
    }

    var greekLabel: String {
        switch self {
        case .sunny:        return "έχει ήλιο"
        case .partlyCloudy: return "έχει μερική συννεφιά"
        case .cloudy:       return "έχει συννεφιά"
        case .rainy:        return "βρέχει"
        case .thunderstorm: return "έχει καταιγίδα"
        case .snow:         return "χιονίζει"
        case .foggy:        return "έχει ομίχλη"
        case .windy:        return "φυσάει"
        case .hot:          return "κάνει ζέστη"
        case .cold:         return "κάνει κρύο"
        case .unknown:      return "άγνωστος καιρός"
        }
    }

    var germanLabel: String {
        switch self {
        case .sunny:        return "Sonnenschein"
        case .partlyCloudy: return "leichter Bewölkung"
        case .cloudy:       return "Bewölkung"
        case .rainy:        return "Regen"
        case .thunderstorm: return "Gewitter"
        case .snow:         return "Schnee"
        case .foggy:        return "Nebel"
        case .windy:        return "Wind"
        case .hot:          return "Hitze"
        case .cold:         return "Kälte"
        case .unknown:      return "unbekanntem Wetter"
        }
    }

    /// Short display label for the chart rows
    func displayName(language: String) -> String {
        switch language {
        case "Ελληνικά":
            switch self {
            case .sunny:        return "Ήλιος"
            case .partlyCloudy: return "Μερ. Συννεφιά"
            case .cloudy:       return "Συννεφιά"
            case .rainy:        return "Βροχή"
            case .thunderstorm: return "Καταιγίδα"
            case .snow:         return "Χιόνι"
            case .foggy:        return "Ομίχλη"
            case .windy:        return "Αέρας"
            case .hot:          return "Ζέστη"
            case .cold:         return "Κρύο"
            case .unknown:      return "Άγνωστο"
            }
        case "Deutsch":
            switch self {
            case .sunny:        return "Sonnig"
            case .partlyCloudy: return "Teils bewölkt"
            case .cloudy:       return "Bewölkt"
            case .rainy:        return "Regen"
            case .thunderstorm: return "Gewitter"
            case .snow:         return "Schnee"
            case .foggy:        return "Neblig"
            case .windy:        return "Windig"
            case .hot:          return "Heiß"
            case .cold:         return "Kalt"
            case .unknown:      return "Unbekannt"
            }
        default:
            switch self {
            case .sunny:        return "Sunny"
            case .partlyCloudy: return "Partly Cloudy"
            case .cloudy:       return "Cloudy"
            case .rainy:        return "Rainy"
            case .thunderstorm: return "Thunderstorm"
            case .snow:         return "Snow"
            case .foggy:        return "Foggy"
            case .windy:        return "Windy"
            case .hot:          return "Hot"
            case .cold:         return "Cold"
            case .unknown:      return "Unknown"
            }
        }
    }
}

// MARK: - CorrelationStore

@Observable
class CorrelationStore {

    static let shared = CorrelationStore()

    private(set) var snapshots: [DailySnapshot] = []

    /// Latest weather known to the store (updated by WeatherManager on every successful fetch)
    private(set) var lastKnownCondition: WeatherCondition = .unknown
    private(set) var lastKnownTemp: Double = 0

    private let defaults = UserDefaults.standard
    private let snapshotsKey = "picksy_correlation_snapshots"
    private let maxDays = 90

    private init() {
        loadSnapshots()
    }

    // MARK: - Weather Update (called by WeatherManager)

    func updateCurrentWeather(condition: WeatherCondition, temperature: Double) {
        lastKnownCondition = condition
        lastKnownTemp = temperature
    }

    // MARK: - Day End (called by DataStore.checkNewDay before reset)

    /// Records a snapshot for `date` (the day that just ended, e.g. "2026-05-14").
    func recordDayEnd(pickups: Int, date: String) {
        // Need real weather data and at least 1 pickup to be meaningful
        guard lastKnownCondition != .unknown, pickups > 0 else { return }
        // Avoid duplicates
        guard !snapshots.contains(where: { $0.date == date }) else { return }

        let snapshot = DailySnapshot(
            date: date,
            condition: lastKnownCondition,
            temperature: lastKnownTemp,
            pickupCount: pickups
        )

        snapshots.append(snapshot)

        // Keep rolling 90-day window
        if snapshots.count > maxDays {
            snapshots.removeFirst(snapshots.count - maxDays)
        }

        saveSnapshots()
        print("[Correlation] Saved: \(date) \(lastKnownCondition.emoji) \(pickups) pickups")
    }

    // MARK: - Analysis

    /// Minimum snapshots needed to show insights
    var hasEnoughData: Bool { snapshots.count >= 5 }

    var daysUntilInsights: Int { max(0, 5 - snapshots.count) }

    /// Per-condition averages, sorted best (lowest pickups) → worst.
    /// Only includes conditions with ≥ 2 data points.
    var conditionSummaries: [ConditionSummary] {
        let grouped = Dictionary(grouping: snapshots, by: { $0.condition })
        return grouped
            .filter { $0.value.count >= 2 }
            .map { entry -> ConditionSummary in
                let avg = Double(entry.value.map(\.pickupCount).reduce(0, +)) / Double(entry.value.count)
                return ConditionSummary(condition: entry.key, avgPickups: avg, days: entry.value.count)
            }
            .sorted { $0.avgPickups < $1.avgPickups }
    }

    /// The single top-level insight sentence, or nil if not enough contrast.
    func insightText(language: String) -> String? {
        guard hasEnoughData else { return nil }
        let summaries = conditionSummaries
        guard summaries.count >= 2 else { return nil }

        let best  = summaries.first!   // lowest avg pickups
        let worst = summaries.last!    // highest avg pickups

        guard best.condition != worst.condition else { return nil }

        let improvement = worst.avgPickups > 0
            ? Int(((worst.avgPickups - best.avgPickups) / worst.avgPickups * 100).rounded())
            : 0

        guard improvement >= 10 else { return nil } // Only show meaningful differences

        switch language {
        case "Ελληνικά":
            return "Όταν \(best.condition.greekLabel), σηκώνεις \(improvement)% λιγότερο 📱"
        case "Deutsch":
            return "Bei \(best.condition.germanLabel) greifst du \(improvement)% seltener 📱"
        default:
            return "On \(best.condition.englishLabel) days, you pick up \(improvement)% less 📱"
        }
    }

    // MARK: - Persistence

    private func loadSnapshots() {
        guard let data = defaults.data(forKey: snapshotsKey),
              let decoded = try? JSONDecoder().decode([DailySnapshot].self, from: data) else { return }
        snapshots = decoded
    }

    private func saveSnapshots() {
        guard let encoded = try? JSONEncoder().encode(snapshots) else { return }
        defaults.set(encoded, forKey: snapshotsKey)
    }
}
