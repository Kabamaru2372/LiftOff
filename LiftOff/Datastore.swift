//
//  DataStore.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.03.2026
//
//  v1.6 UPDATE - Added ZoneNotificationManager hook in recordPickup().
//  v1.6 UPDATE - Comprehensive reset για όλα τα Picksy-controlled data.
//

import Foundation
import SwiftUI
import WidgetKit

@Observable
class DataStore {

    var todayPickups: Int = 0
    var todayTotalSeconds: Int = 0
    var currentStreak: Int = 0
    var weeklyPickups: [Int] = [0, 0, 0, 0, 0, 0, 0]
    var totalPickups: Int = 0
    var totalDaysTracked: Int = 0

    /// Screen time in seconds per hour today (index 0–23 = hour of day).
    /// Updated every time addUsageTime() is called.
    var hourlyScreenTimeSecs: [Int] = Array(repeating: 0, count: 24)

    /// Total screen time in seconds for the current + previous hour (rolling 2-hour window).
    /// Wraps to hour 23 at midnight to avoid double-counting hour 0.
    var screenTimeLastTwoHours: Int {
        let hour = Calendar.current.component(.hour, from: Date())
        let prev = hour > 0 ? hour - 1 : 23
        return hourlyScreenTimeSecs[hour] + hourlyScreenTimeSecs[prev]
    }

    /// Screen time confirmed by Apple's DeviceActivity threshold events.
    /// These fire in the background even when Picksy is suspended — unlike
    /// ScreenUnlockDetector which only works while the app is alive.
    ///
    /// IMPORTANT: this is a STORED @Observable property, not a computed one.
    /// The value is written to the App Group by the DeviceActivityMonitor
    /// extension (a separate process), and cross-process UserDefaults writes do
    /// NOT trigger SwiftUI updates. We mirror it into this stored property via
    /// refreshConfirmedScreenTime() so every view re-renders consistently.
    var appleConfirmedScreenTimeSecs: Int = 0

    /// The EXACT screen-time total shown on the Apps tab, written to the App
    /// Group by the DeviceActivityReport extension (`PicksyDeviceReport`).
    /// This is Apple's authoritative number — the same one the Apps tab renders.
    ///
    /// Also a STORED @Observable property (see note above) — refreshed from the
    /// App Group via refreshConfirmedScreenTime(). Stays 0 until the report has
    /// rendered at least once today (Apps tab or Nudge screen, both of which
    /// host a DeviceActivityReport).
    var reportConfirmedScreenTimeSecs: Int = 0

    /// Best-estimate total screen time for today — the single source of truth
    /// for EVERY screen-time display in the app (Stats tab, Nudge, Watch,
    /// Friends/Duel scores), kept consistent with the Apps tab.
    ///
    /// Takes the maximum of:
    ///   • reportConfirmedScreenTimeSecs (Apple's exact total — matches Apps tab)
    ///   • appleConfirmedScreenTimeSecs (Apple threshold events — lower bound,
    ///     available even before the report has rendered)
    ///   • todayTotalSeconds (ScreenUnlockDetector — accurate only while alive)
    ///
    /// This fixes the "31 min vs 6 hours" discrepancy where the app was suspended
    /// during most of the user's phone session, AND guarantees cross-tab
    /// consistency once the report has rendered.
    var bestScreenTimeSecs: Int {
        max(todayTotalSeconds, max(appleConfirmedScreenTimeSecs, reportConfirmedScreenTimeSecs))
    }

    /// Re-reads the Apple-confirmed (threshold) and report-confirmed (Apps-tab
    /// total) screen-time values from the App Group into the stored @Observable
    /// properties above. Cross-process writes from the extensions don't notify
    /// SwiftUI on their own, so this MUST be called whenever a screen-time
    /// display might be on-screen: app foreground, the Darwin "screenTimeUpdated"
    /// notification, the Nudge refresh timer, and each relevant view's onAppear.
    func refreshConfirmedScreenTime() {
        let apple = defaults.integer(forKey: "picksy_apple_screen_time_secs")

        let reportDate = defaults.string(forKey: "picksy_report_screen_time_date")
        let report = (reportDate == todayDateString())
            ? defaults.integer(forKey: "picksy_report_screen_time_secs")
            : 0

        // Only assign on change to avoid redundant @Observable invalidations.
        if apple != appleConfirmedScreenTimeSecs {
            appleConfirmedScreenTimeSecs = apple
        }
        if report != reportConfirmedScreenTimeSecs {
            reportConfirmedScreenTimeSecs = report
        }
    }

    private let defaults = UserDefaults(suiteName: "group.fotiospongas.picksy") ?? UserDefaults.standard
    private var midnightTimer: Timer?
    // H5 fix: store the observer opaque pointer so deinit can remove it and prevent UAF crashes.
    private var darwinObserver: UnsafeMutableRawPointer? = nil

    init() {
        loadData()
        startMidnightTimer()
        observeForeground()
        observeDeviceActivityPickups()
        observeScreenTimeUpdates()

        // Initial sync με DeviceActivity data
        syncWithDeviceActivity()
    }

    func loadData() {
        
        todayPickups = defaults.integer(forKey: "todayPickups")
        todayTotalSeconds = defaults.integer(forKey: "todayTotalSeconds")
        currentStreak = defaults.integer(forKey: "currentStreak")
        totalPickups = defaults.integer(forKey: "totalPickups")
        totalDaysTracked = defaults.integer(forKey: "totalDaysTracked")

        if let saved = defaults.array(forKey: "weeklyPickups") as? [Int] {
            weeklyPickups = saved
        }
        if let saved = defaults.array(forKey: "hourlyScreenTimeSecs") as? [Int], saved.count == 24 {
            hourlyScreenTimeSecs = saved
        }

        checkNewDay()

        // Seed the confirmed screen-time values from the App Group on launch.
        refreshConfirmedScreenTime()
    }

    func recordPickup() {
        todayPickups += 1
        totalPickups += 1
        weeklyPickups[currentDayIndex()] = todayPickups
        saveData()
        WidgetCenter.shared.reloadAllTimelines()

        // v1.6: Check for zone transitions and trigger notifications
        ZoneNotificationManager.shared.checkAndNotify(currentPickups: todayPickups)
    }

    func addUsageTime(seconds: Int) {
        todayTotalSeconds += seconds
        // Also track in the per-hour bucket for friend sync
        let hour = Calendar.current.component(.hour, from: Date())
        hourlyScreenTimeSecs[hour] += seconds
        saveData()
    }

    // MARK: - DeviceActivity Sync

    func syncWithDeviceActivity() {
        let key = todayPickupsKey()
        let deviceActivityCount = defaults.integer(forKey: key)

        if deviceActivityCount > todayPickups {
            let diff = deviceActivityCount - todayPickups
            todayPickups = deviceActivityCount
            totalPickups += diff
            weeklyPickups[currentDayIndex()] = todayPickups
            saveData()
            WidgetCenter.shared.reloadAllTimelines()
            print("📊 Synced with DeviceActivity: \(todayPickups) pickups today")

            ZoneNotificationManager.shared.checkAndNotify(currentPickups: todayPickups)
        }

        // Also pull the latest confirmed screen-time totals on every sync.
        refreshConfirmedScreenTime()
    }

    private func observeDeviceActivityPickups() {
        let name = "dev.fotiospongas.picksy.pickupRecorded" as CFString
        // H5 fix: store the observer pointer so deinit can remove it.
        // Without removal, DataStore deallocation leaves a dangling opaque pointer
        // in the Darwin notification center, causing a Use-After-Free crash.
        let observer = Unmanaged.passUnretained(self).toOpaque()
        darwinObserver = observer

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { (_, observer, _, _, _) in
                guard let observer = observer else { return }
                let store = Unmanaged<DataStore>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    store.syncWithDeviceActivity()
                }
            },
            name,
            nil,
            .deliverImmediately
        )
    }

    /// Observes the Darwin notification posted by the DeviceActivityReport and
    /// DeviceActivityMonitor extensions whenever they write a new confirmed
    /// screen-time value to the App Group. Without this, those cross-process
    /// writes never reach SwiftUI and screens (e.g. Nudge) keep a stale total.
    private func observeScreenTimeUpdates() {
        let name = "dev.fotiospongas.picksy.screenTimeUpdated" as CFString
        // Reuse the same opaque self pointer as the pickup observer; removal in
        // deinit is keyed by notification name, so one pointer serves both.
        let observer = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { (_, observer, _, _, _) in
                guard let observer = observer else { return }
                let store = Unmanaged<DataStore>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    store.refreshConfirmedScreenTime()
                }
            },
            name,
            nil,
            .deliverImmediately
        )
    }

    // MARK: - Reset today only

    /// Μηδενίζει μόνο τα σημερινά σηκώματα.
    /// Αφαιρεί το σημερινό count από το totalPickups ώστε να παραμείνει συνεπές.
    /// Το streak, η εβδομαδιαία ιστορία (εκτός σήμερα) και τα achievements δεν επηρεάζονται.
    func resetTodayPickups() {
        let todayCount = todayPickups

        // Αφαίρεσε το σημερινό count από το all-time total
        totalPickups = max(0, totalPickups - todayCount)

        // Μηδένισε σήμερα
        todayPickups = 0
        weeklyPickups[currentDayIndex()] = 0

        // Persist
        defaults.set(totalPickups, forKey: "totalPickups")
        defaults.set(0, forKey: "todayPickups")
        defaults.set(weeklyPickups, forKey: "weeklyPickups")

        // Καθάρισε το DeviceActivity shared key για σήμερα
        defaults.removeObject(forKey: todayPickupsKey())

        // Άσε το ScreenUnlockDetector να μετρήσει το επόμενο unlock
        UserDefaults.standard.removeObject(forKey: "ScreenUnlockDetector.lastPickupTime")
        ScreenUnlockDetector.shared.sessionPickupCount = 0

        // Άσε τις zone notifications να ξανατριγκάρουν από 0
        ZoneNotificationManager.shared.resetForNewDay()

        // Ανανέωσε widgets
        WidgetCenter.shared.reloadAllTimelines()

        print("🔄 Today's pickups reset (was \(todayCount), total adjusted to \(totalPickups))")
    }

    // MARK: - Reset all stats

    /// v1.6: Σβήνει όλα τα Picksy-controlled data.
    /// ΣΗΜΕΙΩΣΗ: App usage time από Apple Screen Time ΔΕΝ μπορούν να σβηστούν
    /// (iOS limitation). Αυτά resetάρονται αυτόματα στις 00:00.
    func resetAllStats() {
        // Core stats
        todayPickups = 0
        todayTotalSeconds = 0
        currentStreak = 0
        weeklyPickups = [0, 0, 0, 0, 0, 0, 0]
        totalPickups = 0
        totalDaysTracked = 0

        // Clear core stat keys
        defaults.removeObject(forKey: "todayPickups")
        defaults.removeObject(forKey: "todayTotalSeconds")
        defaults.removeObject(forKey: "currentStreak")
        defaults.removeObject(forKey: "weeklyPickups")
        defaults.removeObject(forKey: "totalPickups")
        defaults.removeObject(forKey: "totalDaysTracked")
        defaults.removeObject(forKey: "lastActiveDate")

        // Reset DeviceActivity shared key
        defaults.removeObject(forKey: todayPickupsKey())

        // Clear shared cooldown key (used by both ScreenUnlockDetector + extension, fix #1)
        defaults.removeObject(forKey: "picksy_last_pickup_timestamp")

        // Reset Apple-confirmed screen time
        defaults.set(0, forKey: "picksy_apple_screen_time_secs")

        // Reset report-confirmed screen time (Apps-tab total mirror)
        defaults.set(0, forKey: "picksy_report_screen_time_secs")
        defaults.removeObject(forKey: "picksy_report_screen_time_date")

        // Mirror the reset into the stored @Observable props so views update.
        appleConfirmedScreenTimeSecs = 0
        reportConfirmedScreenTimeSecs = 0

        // v1.6: Clear last pickup timestamp στο NudgeView
        UserDefaults.standard.removeObject(forKey: "lastPickupTimestamp")

        // v1.6: Reset zone notifications - ώστε να μπορούν να ξανατριγκάρουν
        ZoneNotificationManager.shared.resetForNewDay()

        // v1.6: Reset session counter του ScreenUnlockDetector
        ScreenUnlockDetector.shared.sessionPickupCount = 0

        // Reload all widgets και Live Activity
        WidgetCenter.shared.reloadAllTimelines()

        // Note: we do NOT reset achievements — they're permanent

        print("🔄 All Picksy stats reset")
    }

    var averageMinutes: Int {
        guard todayPickups > 0 else { return 0 }
        return (todayTotalSeconds / todayPickups) / 60
    }

    /// Human-readable average session length: shows seconds when < 60s to avoid "0m".
    var averageSessionLabel: String {
        guard todayPickups > 0, todayTotalSeconds > 0 else { return "—" }
        let avgSecs = todayTotalSeconds / todayPickups
        if avgSecs < 60 { return "\(avgSecs)s" }
        let mins = avgSecs / 60
        let secs = avgSecs % 60
        return secs > 0 ? "\(mins)m \(secs)s" : "\(mins)m"
    }

    var averageDailyPickups: Int {
        guard totalDaysTracked > 0 else { return totalPickups }
        return totalPickups / totalDaysTracked
    }

    /// v1.6: Current pickup zone based on todayPickups
    var currentZone: PickupZone {
        return PickupZone.zone(for: todayPickups)
    }

    // MARK: - Midnight Timer

    private func startMidnightTimer() {
        midnightTimer?.invalidate()

        let calendar = Calendar.current
        guard let midnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return }

        let secondsUntilMidnight = midnight.timeIntervalSinceNow

        midnightTimer = Timer.scheduledTimer(withTimeInterval: secondsUntilMidnight, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.checkNewDay()
            self.startMidnightTimer()

            // v1.6: Reset zone notification triggers at midnight
            ZoneNotificationManager.shared.resetForNewDay()
        }
    }

    // MARK: - Foreground Observer

    private func observeForeground() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkNewDay()
            self?.syncWithDeviceActivity()
            self?.startMidnightTimer()
        }
    }

    // MARK: - Private

    private func saveData() {
        defaults.set(todayPickups, forKey: "todayPickups")
        defaults.set(todayTotalSeconds, forKey: "todayTotalSeconds")
        defaults.set(currentStreak, forKey: "currentStreak")
        defaults.set(weeklyPickups, forKey: "weeklyPickups")
        defaults.set(totalPickups, forKey: "totalPickups")
        defaults.set(totalDaysTracked, forKey: "totalDaysTracked")
        defaults.set(hourlyScreenTimeSecs, forKey: "hourlyScreenTimeSecs")
        defaults.set(todayDateString(), forKey: "lastActiveDate")
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        defaults.set(language, forKey: "appLanguage")
        let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
        defaults.set(goal > 0 ? goal : 50, forKey: "dailyGoal")
    }

    func checkNewDay() {
        let lastDate = defaults.string(forKey: "lastActiveDate") ?? ""
        let today = todayDateString()

        if lastDate != today && lastDate != "" {
            let dailyGoal = defaults.integer(forKey: "dailyGoal")
            let goal = dailyGoal > 0 ? dailyGoal : 50

            if todayPickups > 0 && todayPickups <= goal {
                currentStreak += 1
            } else if todayPickups > goal || todayPickups == 0 {
                // H6 fix: 0 pickups (phone not opened) also resets streak —
                // previously a day with 0 pickups silently skipped the streak check.
                currentStreak = 0
            }

            if todayPickups > 0 { totalDaysTracked += 1 }

            // Save previous day pickups for Big Drop badge calculation
            let previousPickups = defaults.integer(forKey: "ach_previousDayPickups")
            defaults.set(todayPickups, forKey: "ach_previousDayPickups")

            // Notify AchievementManager before resetting
            AchievementManager.shared.onDayCompleted(
                pickups: todayPickups,
                goal: goal,
                streak: currentStreak,
                totalDays: totalDaysTracked,
                previousDayPickups: previousPickups
            )

            // Record weather correlation snapshot for the day that just ended
            CorrelationStore.shared.recordDayEnd(pickups: todayPickups, date: lastDate)

            todayPickups = 0
            todayTotalSeconds = 0
            hourlyScreenTimeSecs = Array(repeating: 0, count: 24)
            weeklyPickups[currentDayIndex()] = 0
            defaults.removeObject(forKey: todayPickupsKey())
            // Reset Apple-confirmed screen time for the new day.
            defaults.set(0, forKey: "picksy_apple_screen_time_secs")
            // Reset report-confirmed total for the new day.
            defaults.set(0, forKey: "picksy_report_screen_time_secs")
            defaults.removeObject(forKey: "picksy_report_screen_time_date")
            // Mirror into the stored @Observable props so views update at midnight.
            appleConfirmedScreenTimeSecs = 0
            reportConfirmedScreenTimeSecs = 0
            saveData()
            WidgetCenter.shared.reloadAllTimelines()
        } else if lastDate == "" {
            saveData()
        }
    }

    private func currentDayIndex() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func todayPickupsKey() -> String {
        return "picksy_pickups_\(todayDateString())"
    }

    deinit {
        midnightTimer?.invalidate()
        // H5 fix: remove the Darwin notification observers before deallocation.
        if let observer = darwinObserver {
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterRemoveObserver(
                center,
                observer,
                CFNotificationName("dev.fotiospongas.picksy.pickupRecorded" as CFString),
                nil
            )
            CFNotificationCenterRemoveObserver(
                center,
                observer,
                CFNotificationName("dev.fotiospongas.picksy.screenTimeUpdated" as CFString),
                nil
            )
        }
    }
}

