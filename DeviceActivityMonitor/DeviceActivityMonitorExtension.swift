//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitor
//
//  Created by Fotios Pongas on 27.04.26.
//
//  Αυτό το extension τρέχει στο background και ειδοποιείται από το iOS
//  όταν συμβαίνει ένα event (π.χ. pickup threshold reached).
//  Καταγράφουμε τα events στο shared App Group ώστε το main app να τα διαβάζει.

import DeviceActivity
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // MARK: - Shared Storage

    /// Το App Group που μοιράζεται data με το main app
    private static let appGroupID = "group.fotiospongas.picksy"

    /// Shared UserDefaults για data sharing με το main app
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    // MARK: - Interval Lifecycle

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log("📅 Interval started for: \(activity.rawValue)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log("📅 Interval ended for: \(activity.rawValue)")

        // Reset daily counter at end of day interval
        if activity.rawValue == "daily" {
            resetDailyCounter()
        }
    }

    // MARK: - Event Handling

    /// Καλείται όταν ένα event φτάνει το threshold (π.χ. 1 pickup)
    /// Για κάθε pickup, αυξάνουμε τον counter στο shared storage
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        log("🎯 Event threshold reached: \(event.rawValue)")

        // Increment pickup counter
        incrementPickupCounter()
    }

    // MARK: - Warnings (optional, για future use)

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }

    // MARK: - Helpers

    /// Αυξάνει τον pickup counter στο shared storage
    private func incrementPickupCounter() {
        guard let defaults = sharedDefaults else {
            log("❌ Cannot access shared defaults")
            return
        }

        let today = todayKey()
        let currentCount = defaults.integer(forKey: today)
        let newCount = currentCount + 1
        defaults.set(newCount, forKey: today)
        defaults.set(Date().timeIntervalSince1970, forKey: "lastPickupTimestamp")

        log("✅ Pickup recorded. Today's total: \(newCount)")

        // Notify main app via Darwin notification (αν τρέχει)
        notifyMainApp()
    }

    /// Reset του ημερήσιου counter
    private func resetDailyCounter() {
        guard let defaults = sharedDefaults else { return }
        let today = todayKey()
        defaults.set(0, forKey: today)
        log("🔄 Daily counter reset")
    }

    /// Generate key για σήμερα (yyyy-MM-dd format)
    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "picksy_pickups_\(formatter.string(from: Date()))"
    }

    /// Στέλνει Darwin notification στο main app
    private func notifyMainApp() {
        let name = CFNotificationName("dev.fotiospongas.picksy.pickupRecorded" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            name,
            nil,
            nil,
            true
        )
    }

    /// Logging με prefix για ευκολία debugging
    private func log(_ message: String) {
        print("[PicksyDeviceActivity] \(message)")
    }
}

