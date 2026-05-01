//
//  PickupScheduler.swift
//  Picksy
//
//  Created by Fotios Pongas on 27.04.2026
//
//  Διαχειρίζεται το DeviceActivity monitoring schedule.
//  Ξεκινάει daily monitoring (00:00 — 23:59) ώστε το DeviceActivityReport
//  extension να μπορεί να διαβάσει app usage time data.
//
//  ΣΗΜΕΙΩΣΗ: Δεν χρησιμοποιούμε events. Τα pickups τα μετράει CoreMotion.
//  Εδώ μόνο monitoring για να γίνεται report για το usage time κάθε app.

import Foundation
import DeviceActivity
import FamilyControls

@Observable
class PickupScheduler {

    // MARK: - Constants

    static let appGroupID = "group.fotiospongas.picksy"

    /// Όνομα του daily schedule
    static let dailyActivityName = DeviceActivityName("daily")

    // MARK: - State

    /// True αν το monitoring είναι ενεργό
    var isMonitoring: Bool = false

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

    /// Ξεκινάει το daily monitoring για usage time tracking
    func startMonitoring() {
        guard FamilyControlsManager.shared.isAuthorized else {
            print("⚠️ Cannot start monitoring without authorization")
            return
        }

        let selection = AppSelectionStore.shared.selection

        // Αν δεν έχει επιλέξει apps, δεν ξεκινάμε monitoring
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            print("⚠️ No apps selected for monitoring")
            isMonitoring = false
            return
        }

        let center = DeviceActivityCenter()

        // Stop any existing monitoring first
        center.stopMonitoring([Self.dailyActivityName])

        // Schedule: από 00:00 μέχρι 23:59 κάθε μέρα (repeats)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            // Χωρίς events — απλά monitoring schedule για να μπορεί
            // το DeviceActivityReport extension να διαβάσει data
            try center.startMonitoring(Self.dailyActivityName, during: schedule)
            isMonitoring = true
            print("✅ DeviceActivity monitoring started for \(selection.applicationTokens.count) apps")
        } catch {
            print("❌ Failed to start monitoring: \(error.localizedDescription)")
            isMonitoring = false
        }
    }

    /// Σταματάει το monitoring
    func stopMonitoring() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([Self.dailyActivityName])
        isMonitoring = false
        print("🛑 DeviceActivity monitoring stopped")
    }

    /// Επανεκκινεί το monitoring (καλείται όταν αλλάζει η selection)
    func refreshMonitoring() {
        guard FamilyControlsManager.shared.isAuthorized else { return }
        stopMonitoring()
        startMonitoring()
    }

    /// Ελέγχει αν το monitoring τρέχει ήδη
    func checkMonitoringStatus() {
        let center = DeviceActivityCenter()
        let activities = center.activities
        isMonitoring = activities.contains(Self.dailyActivityName)
    }
}

