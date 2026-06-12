//
//  UsageThresholdManager.swift
//  Picksy
//
//  Created by Fotios Pongas on 05.05.2026
//
//  v1.7 UPDATE:
//  - Προστέθηκε ThresholdPreset για user-selectable thresholds
//  - Default: Light (1h/2h/3h) - research-backed
//  - Moderate: 45min/1.5h/2h
//  - Strict: 30min/1h/1.5h
//

import CryptoKit
import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

// MARK: - Threshold Preset

enum ThresholdPreset: String, CaseIterable {
    case light    = "light"    // 1h / 2h / 3h (default, research-backed)
    case moderate = "moderate" // 45min / 1.5h / 2h
    case strict   = "strict"   // 30min / 1h / 1.5h

    static let storageKey = "picksyThresholdPreset"

    static var current: ThresholdPreset {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? "light"
        return ThresholdPreset(rawValue: raw) ?? .light
    }

    static func save(_ preset: ThresholdPreset) {
        UserDefaults.standard.set(preset.rawValue, forKey: storageKey)
        // Mirror to the shared App Group so the DeviceActivityMonitor extension
        // can read the preset when recording Apple-confirmed screen time.
        let shared = UserDefaults(suiteName: "group.fotiospongas.picksy")
        shared?.set(preset.rawValue, forKey: "picksyThresholdPreset_shared")
    }

    func displayName(language: String) -> String {
        switch language {
        case "Ελληνικά":
            switch self {
            case .light:    return "Ελαφρύ"
            case .moderate: return "Μέτριο"
            case .strict:   return "Αυστηρό"
            }
        case "Deutsch":
            switch self {
            case .light:    return "Leicht"
            case .moderate: return "Moderat"
            case .strict:   return "Streng"
            }
        default:
            switch self {
            case .light:    return "Light"
            case .moderate: return "Moderate"
            case .strict:   return "Strict"
            }
        }
    }

    func subtitle(language: String) -> String {
        switch language {
        case "Ελληνικά":
            switch self {
            case .light:    return "1h / 2h / 3h — βάσει έρευνας"
            case .moderate: return "45λ / 1.5h / 2h"
            case .strict:   return "30λ / 1h / 1.5h"
            }
        case "Deutsch":
            switch self {
            case .light:    return "1h / 2h / 3h — forschungsbasiert"
            case .moderate: return "45min / 1,5h / 2h"
            case .strict:   return "30min / 1h / 1,5h"
            }
        default:
            switch self {
            case .light:    return "1h / 2h / 3h — research-backed"
            case .moderate: return "45min / 1.5h / 2h"
            case .strict:   return "30min / 1h / 1.5h"
            }
        }
    }

    /// Thresholds για κάθε level
    var thresholds: (level1: DateComponents, level2: DateComponents, level3: DateComponents) {
        switch self {
        case .light:
            return (
                DateComponents(hour: 1),
                DateComponents(hour: 2),
                DateComponents(hour: 3)
            )
        case .moderate:
            return (
                DateComponents(minute: 45),
                DateComponents(minute: 90),
                DateComponents(hour: 2)
            )
        case .strict:
            return (
                DateComponents(minute: 30),
                DateComponents(hour: 1),
                DateComponents(minute: 90)
            )
        }
    }

    /// Display values για notifications
    var displayValues: (level1: String, level2: String, level3: String) {
        switch self {
        case .light:    return ("1h", "2h", "3h")
        case .moderate: return ("45m", "1.5h", "2h")
        case .strict:   return ("30m", "1h", "1.5h")
        }
    }
}

// MARK: - UsageThresholdManager

class UsageThresholdManager {

    static let shared = UsageThresholdManager()

    static let isTestMode = false
    static let activityName = DeviceActivityName("picksy.usageThresholds")
    /// Separate activity for the score's hourly confirmed-time ladder, isolated
    /// from the notification thresholds above.
    static let scoreActivityName = DeviceActivityName("picksy.scoreLadder")

    /// Confirmed-time score ladder granularity. Events fire every
    /// `scoreLadderStepMinutes` of cumulative usage, up to `scoreLadderMaxMinutes`.
    /// Finer steps → the in-app Picksy Score (and the duel score we sync) tracks
    /// the real screen time more closely (≈ within one step + Apple's delivery
    /// delay). 15 min × up to 10h = 40 events — well under DeviceActivity's limit.
    static let scoreLadderStepMinutes = 15
    static let scoreLadderMaxMinutes  = 10 * 60

    enum ThresholdLevel: String, CaseIterable {
        case level1 = "picksy.threshold.level1"
        case level2 = "picksy.threshold.level2"
        case level3 = "picksy.threshold.level3"

        var eventName: DeviceActivityEvent.Name {
            DeviceActivityEvent.Name(self.rawValue)
        }

        func duration(preset: ThresholdPreset) -> DateComponents {
            let thresholds = preset.thresholds
            switch self {
            case .level1: return thresholds.level1
            case .level2: return thresholds.level2
            case .level3: return thresholds.level3
            }
        }

        func displayValue(preset: ThresholdPreset) -> String {
            let values = preset.displayValues
            switch self {
            case .level1: return values.level1
            case .level2: return values.level2
            case .level3: return values.level3
            }
        }
    }

    private let center = DeviceActivityCenter()
    private init() {}

    // MARK: - Public API

    func startMonitoring() {
        let selection = AppSelectionStore.shared.selection
        let hasApps = !selection.applicationTokens.isEmpty
        let hasCategories = !selection.categoryTokens.isEmpty

        guard hasApps || hasCategories else {
            log("⚠️ No apps selected, skipping threshold monitoring")
            stopMonitoring()
            return
        }

        let preset = ThresholdPreset.current
        let limitMinutes = UserDefaults.standard.integer(forKey: "picksy_timelimit_minutes")

        // Always mirror preset to App Group so the extension has the current value.
        let sharedDefaults = UserDefaults(suiteName: "group.fotiospongas.picksy")
        sharedDefaults?.set(preset.rawValue, forKey: "picksyThresholdPreset_shared")

        // ── Skip needless restarts ──────────────────────────────────────────────
        // stopMonitoring + startMonitoring resets Apple's usage accumulation to
        // ZERO for these events. LiftOffApp calls startMonitoring on every launch,
        // so an unconditional restart wiped the confirmed-time ladder several
        // times a day — the duel score showed only the usage since the last
        // launch (e.g. 2h15 while the Apps tab showed 9h07). When monitoring is
        // already active with an unchanged config, leave the ladder untouched.
        let fingerprint = Self.monitoringFingerprint(
            selection: selection, preset: preset, limitMinutes: limitMinutes
        )
        let monitored = Set(center.activities.map(\.rawValue))
        if monitored.contains(Self.activityName.rawValue),
           monitored.contains(Self.scoreActivityName.rawValue),
           sharedDefaults?.string(forKey: "picksy_monitoring_fingerprint") == fingerprint {
            log("⏭️ Monitoring already active with unchanged config — keeping ladder intact")
            return
        }

        // ── Ladder restart baseline ─────────────────────────────────────────────
        // A genuine restart (changed selection/preset, or first start after boot)
        // still resets the accumulation — every rung that fires afterwards reports
        // time since the RESTART, not since midnight. Stamp today's best-known
        // confirmed time as a baseline; the monitor extension adds it to each rung
        // so the recorded total remains real time-of-day usage.
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        let confirmed = sharedDefaults?.string(forKey: "picksy_apple_screen_time_date") == today
            ? (sharedDefaults?.integer(forKey: "picksy_apple_screen_time_secs") ?? 0) : 0
        sharedDefaults?.set(confirmed, forKey: "picksy_apple_screen_time_baseline")
        sharedDefaults?.set(today,     forKey: "picksy_apple_screen_time_baseline_date")
        if confirmed > 0 {
            log("📐 Ladder baseline stamped: \(confirmed / 60)min (restart mid-day)")
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        for level in ThresholdLevel.allCases {
            events[level.eventName] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: level.duration(preset: preset)
            )
        }

        // Optional daily time-limit event: fires once when cumulative usage of the
        // tracked apps crosses the user's chosen limit. The monitor then applies a
        // "time's up" shield. 0 = off.
        if limitMinutes > 0 {
            events[DeviceActivityEvent.Name("picksy.timelimit")] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(minute: limitMinutes)
            )
        }

        center.stopMonitoring([Self.activityName])

        do {
            try center.startMonitoring(
                Self.activityName,
                during: schedule,
                events: events
            )

            let values = preset.displayValues
            log("✅ Started threshold monitoring [\(preset.rawValue.uppercased()): \(values.level1)/\(values.level2)/\(values.level3)]")
            log("   Apps: \(selection.applicationTokens.count), Categories: \(selection.categoryTokens.count)")
        } catch {
            log("❌ Failed to start monitoring: \(error.localizedDescription)")
        }

        // Confirmed-time ladder for the Picksy Score, in a SEPARATE activity so it
        // can't affect the notification thresholds above. Each event fires as the
        // user's SELECTED apps+categories cross a time mark; the monitor extension
        // records it (no notification) so the in-app score reflects real usage.
        //
        // Measured against the user's selection (applications + categories) —
        // category tokens DO track reliably (unlike empty/whole-device events,
        // which fire all-at-once). If the user selects ALL CATEGORIES, this ≈ the
        // whole-device total and stays accurate, so the duel score (synced from
        // this) matches Nudge/Stats and is fair (both players on the same basis).
        var ladderEvents: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        var minutes = Self.scoreLadderStepMinutes
        while minutes <= Self.scoreLadderMaxMinutes {
            let name = DeviceActivityEvent.Name("picksy.usagemin.\(minutes)")
            ladderEvents[name] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(minute: minutes)
            )
            minutes += Self.scoreLadderStepMinutes
        }

        center.stopMonitoring([Self.scoreActivityName])

        do {
            try center.startMonitoring(
                Self.scoreActivityName,
                during: schedule,
                events: ladderEvents
            )
            log("✅ Started score ladder monitoring (every \(Self.scoreLadderStepMinutes)min up to \(Self.scoreLadderMaxMinutes / 60)h, \(ladderEvents.count) events)")
        } catch {
            log("❌ Failed to start score ladder: \(error.localizedDescription)")
        }

        // Remember this config so the next launch can skip the restart when
        // nothing changed (see the fingerprint check at the top).
        sharedDefaults?.set(fingerprint, forKey: "picksy_monitoring_fingerprint")
    }

    /// Stable digest of everything that affects the monitoring config. Token sets
    /// are encoded individually and sorted so the digest doesn't depend on set
    /// iteration order (which varies between launches).
    private static func monitoringFingerprint(
        selection: FamilyActivitySelection,
        preset: ThresholdPreset,
        limitMinutes: Int
    ) -> String {
        let encoder = JSONEncoder()
        let appParts = selection.applicationTokens.compactMap {
            (try? encoder.encode($0))?.base64EncodedString()
        }.sorted()
        let catParts = selection.categoryTokens.compactMap {
            (try? encoder.encode($0))?.base64EncodedString()
        }.sorted()
        let joined = "\(preset.rawValue)|\(limitMinutes)|\(scoreLadderStepMinutes)|\(scoreLadderMaxMinutes)|"
            + appParts.joined(separator: ",") + "|" + catParts.joined(separator: ",")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func stopMonitoring() {
        center.stopMonitoring([Self.activityName, Self.scoreActivityName])
        log("🛑 Stopped threshold monitoring")
    }

    func restartMonitoring() {
        log("🔄 Restarting threshold monitoring")
        stopMonitoring()
        startMonitoring()
    }

    private func log(_ message: String) {
        print("[UsageThresholds] \(message)")
    }
}

