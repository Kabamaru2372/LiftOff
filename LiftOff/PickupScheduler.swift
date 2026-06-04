//
//  PickupScheduler.swift
//  Picksy
//
//  Created by Fotios Pongas on 27.04.2026
//
//  v1.6 REWRITE - Event-based DeviceActivity tracking για ακριβή pickups.
//
//  Διαχειρίζεται το DeviceActivity monitoring με per-app events.
//  Κάθε selected app έχει το δικό του event με threshold 1 δευτερόλεπτο.
//  Όταν ο user ανοίγει την app, το extension καλείται με eventDidReachThreshold.
//
//  Limits:
//  - Max 20 apps tracked ταυτόχρονα (Apple DeviceActivity limit)
//  - Threshold 1s ανά app για άμεση detection
//

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

@Observable
class PickupScheduler {

    // MARK: - Constants

    static let appGroupID = "group.fotiospongas.picksy"

    /// Όνομα του daily schedule
    static let dailyActivityName = DeviceActivityName("daily")

    /// Maximum apps που μπορούμε να trackάρουμε ταυτόχρονα
    static let maxTrackedApps = 20

    /// Thresholds (in seconds) per tracked app.
    /// Each threshold = one potential pickup detection (with 30s cooldown in the extension).
    /// 10 thresholds × up to 20 apps = 200 events — well within Apple's limits.
    /// With the extension's cooldown, rapid consecutive crossings (same session) count as 1.
    static let pickupThresholds: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    /// Increment this when changing the events schema (e.g. adding thresholds).
    /// Forces a monitoring restart on the next app launch to apply the new events.
    private static let monitoringVersion = 2
    private static let monitoringVersionKey = "picksy_monitoring_version"

    // MARK: - State

    /// True αν το monitoring είναι ενεργό
    var isMonitoring: Bool = false

    /// Πόσες apps trackάρουμε αυτή τη στιγμή
    var currentTrackedAppsCount: Int = 0

    /// Last error για debugging
    var lastError: String? = nil

    // MARK: - Singleton

    static let shared = PickupScheduler()

    private init() {
        checkMonitoringStatus()
    }

    // MARK: - Shared Storage

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    // MARK: - Monitoring

    /// Ξεκινάει event-based monitoring για όλες τις selected apps
    /// Κάθε app έχει το δικό της event με threshold 1 δευτερόλεπτο
    func startMonitoring() {
        // Defensive checks
        guard FamilyControlsManager.shared.isAuthorized else {
            log("⚠️ Cannot start monitoring without authorization")
            isMonitoring = false
            return
        }

        let selection = AppSelectionStore.shared.selection
        let appTokens = selection.applicationTokens

        // Αν δεν έχει επιλέξει apps, δεν ξεκινάμε monitoring
        guard !appTokens.isEmpty else {
            log("⚠️ No apps selected for monitoring")
            isMonitoring = false
            currentTrackedAppsCount = 0
            return
        }

        let center = DeviceActivityCenter()

        // Αν τρέχει ήδη, ελέγχουμε αν η έκδοση των events είναι ενημερωμένη.
        // Αν όχι (π.χ. πρώτη εκκίνηση μετά από update που πρόσθεσε νέα thresholds),
        // κάνουμε restart ώστε να εφαρμοστούν τα νέα events.
        let savedVersion = sharedDefaults?.integer(forKey: Self.monitoringVersionKey) ?? 0
        if center.activities.contains(Self.dailyActivityName) {
            if savedVersion >= Self.monitoringVersion {
                log("ℹ️ Monitoring already active (v\(savedVersion)), skipping restart")
                isMonitoring = true
                currentTrackedAppsCount = Array(selection.applicationTokens.prefix(Self.maxTrackedApps)).count
                return
            }
            // Outdated monitoring version → stop and restart with new events
            log("🔄 Monitoring version outdated (saved: \(savedVersion), current: \(Self.monitoringVersion)) — restarting")
            center.stopMonitoring([Self.dailyActivityName])
        }

        // Schedule: από 00:00 μέχρι 23:59 κάθε μέρα
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59), // fix #6: closer to midnight
            repeats: true
        )

        // Cap στις 20 apps (Apple limit)
        let tokensArray = Array(appTokens.prefix(Self.maxTrackedApps))
        let trackedCount = tokensArray.count

        if appTokens.count > Self.maxTrackedApps {
            log("⚠️ User selected \(appTokens.count) apps, tracking only first \(Self.maxTrackedApps)")
        }

        // Δημιούργησε πολλαπλά events για κάθε app — ένα ανά threshold.
        // Κάθε threshold crossing → extension πυρώνει → pickup detected (με 30s cooldown).
        // 10 thresholds × ≤20 apps = ≤200 events (well within Apple DeviceActivity limits).
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        for (index, token) in tokensArray.enumerated() {
            for threshold in Self.pickupThresholds {
                // Event name: "app_0_t1", "app_0_t2", ... "app_1_t1", etc.
                let eventName = DeviceActivityEvent.Name("app_\(index)_t\(threshold)")

                // Save token mapping μόνο για το πρώτο threshold (για debugging)
                if threshold == 1 {
                    saveTokenMapping(token: token, eventName: "app_\(index)")
                }

                let event = DeviceActivityEvent(
                    applications: [token],
                    threshold: DateComponents(second: threshold)
                )
                events[eventName] = event
            }
        }

        // Save tracked apps count για το extension
        saveTrackedAppsCount(trackedCount)

        do {
            // Start monitoring με events
            try center.startMonitoring(
                Self.dailyActivityName,
                during: schedule,
                events: events
            )

            isMonitoring = true
            currentTrackedAppsCount = trackedCount
            lastError = nil
            sharedDefaults?.set(Self.monitoringVersion, forKey: Self.monitoringVersionKey)

            log("✅ Started event-based monitoring for \(trackedCount) apps (\(events.count) events total, v\(Self.monitoringVersion))")
        } catch {
            isMonitoring = false
            currentTrackedAppsCount = 0
            lastError = error.localizedDescription
            log("❌ Failed to start monitoring: \(error.localizedDescription)")
        }
    }

    /// Σταματάει το monitoring
    func stopMonitoring() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([Self.dailyActivityName])
        isMonitoring = false
        currentTrackedAppsCount = 0
        clearTokenMappings()
        log("🛑 DeviceActivity monitoring stopped")
    }

    /// Επανεκκινεί το monitoring (καλείται όταν αλλάζει η selection)
    func refreshMonitoring() {
        guard FamilyControlsManager.shared.isAuthorized else { return }
        log("🔄 Refreshing monitoring with new selection")
        stopMonitoring()
        startMonitoring()
    }

    /// Ελέγχει αν το monitoring τρέχει ήδη
    func checkMonitoringStatus() {
        let center = DeviceActivityCenter()
        let activities = center.activities
        isMonitoring = activities.contains(Self.dailyActivityName)
        log("📊 Monitoring status: \(isMonitoring ? "active" : "inactive")")
    }

    // MARK: - Token Mapping
    // Αποθηκεύουμε mapping event_name -> bundle_id (αν υπάρχει)
    // για να μπορεί το extension να ξέρει ποια app πατήθηκε

    /// Αποθηκεύει το mapping του event στο App Group
    /// Σημείωση: Δεν μπορούμε να αποθηκεύσουμε ApplicationToken απευθείας,
    /// οπότε αποθηκεύουμε hash για identification
    private func saveTokenMapping(token: ApplicationToken, eventName: String) {
        guard let defaults = sharedDefaults else { return }

        // Encode το token για να μπορούμε να το αναγνωρίσουμε
        do {
            let data = try JSONEncoder().encode(token)
            let key = "picksy_event_token_\(eventName)"
            defaults.set(data, forKey: key)
        } catch {
            log("⚠️ Failed to save token mapping: \(error)")
        }
    }

    /// Καθαρίζει όλα τα token mappings
    private func clearTokenMappings() {
        guard let defaults = sharedDefaults else { return }

        // Βρες όλα τα keys που ξεκινάνε με το prefix
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix("picksy_event_token_") {
            defaults.removeObject(forKey: key)
        }
    }

    /// Αποθηκεύει τον αριθμό tracked apps για debugging από extension
    private func saveTrackedAppsCount(_ count: Int) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(count, forKey: "picksy_tracked_apps_count")
    }

    // MARK: - Logging

    private func log(_ message: String) {
        print("[PickupScheduler] \(message)")
    }
}
