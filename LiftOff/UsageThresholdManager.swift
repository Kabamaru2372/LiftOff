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
    }

    func stopMonitoring() {
        center.stopMonitoring([Self.activityName])
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

