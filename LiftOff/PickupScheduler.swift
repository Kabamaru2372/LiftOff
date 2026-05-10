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

        // Stop any existing monitoring first για clean state
        center.stopMonitoring([Self.dailyActivityName])

        // Schedule: από 00:00 μέχρι 23:59 κάθε μέρα
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // Cap στις 20 apps (Apple limit)
        let tokensArray = Array(appTokens.prefix(Self.maxTrackedApps))
        let trackedCount = tokensArray.count

        if appTokens.count > Self.maxTrackedApps {
            log("⚠️ User selected \(appTokens.count) apps, tracking only first \(Self.maxTrackedApps)")
        }

        // Δημιούργησε ένα event για κάθε app
        // Each event: 1 second threshold, monitors single app token
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        for (index, token) in tokensArray.enumerated() {
            // Unique event name per app (πχ "app_0", "app_1", ...)
            let eventName = DeviceActivityEvent.Name("app_\(index)")

            // Save bundle ID mapping στο App Group για το extension
            // Το extension θα χρησιμοποιήσει το event name για να βρει το token
            saveTokenMapping(token: token, eventName: eventName.rawValue)

            // Create event με 1 second threshold
            let event = DeviceActivityEvent(
                applications: [token],
                threshold: DateComponents(second: 1)
            )

            events[eventName] = event
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

            log("✅ Started event-based monitoring for \(trackedCount) apps")
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
