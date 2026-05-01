//
//  DataStore.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.03.2026

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

    private let defaults = UserDefaults(suiteName: "group.fotiospongas.picksy") ?? UserDefaults.standard
    private var midnightTimer: Timer?

    init() {
        loadData()
        startMidnightTimer()
        observeForeground()
        observeDeviceActivityPickups()

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

        checkNewDay()
    }

    func recordPickup() {
        todayPickups += 1
        totalPickups += 1
        weeklyPickups[currentDayIndex()] = todayPickups
        saveData()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func addUsageTime(seconds: Int) {
        todayTotalSeconds += seconds
        saveData()
    }

    // MARK: - DeviceActivity Sync

    /// Συγχρονίζει τα pickups με τα DeviceActivity data
    /// Αν τα DeviceActivity data είναι μεγαλύτερα, τα χρησιμοποιεί
    func syncWithDeviceActivity() {
        let key = todayPickupsKey()
        let deviceActivityCount = defaults.integer(forKey: key)

        // Χρησιμοποιούμε το μεγαλύτερο νούμερο (DeviceActivity είναι πιο ακριβές)
        if deviceActivityCount > todayPickups {
            let diff = deviceActivityCount - todayPickups
            todayPickups = deviceActivityCount
            totalPickups += diff
            weeklyPickups[currentDayIndex()] = todayPickups
            saveData()
            WidgetCenter.shared.reloadAllTimelines()
            print("📊 Synced with DeviceActivity: \(todayPickups) pickups today")
        }
    }

    /// Listen για Darwin notifications από το extension
    private func observeDeviceActivityPickups() {
        let name = "dev.fotiospongas.picksy.pickupRecorded" as CFString
        let observer = Unmanaged.passUnretained(self).toOpaque()

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

    // MARK: - Reset all stats

    func resetAllStats() {
        todayPickups = 0
        todayTotalSeconds = 0
        currentStreak = 0
        weeklyPickups = [0, 0, 0, 0, 0, 0, 0]
        totalPickups = 0
        totalDaysTracked = 0

        defaults.removeObject(forKey: "todayPickups")
        defaults.removeObject(forKey: "todayTotalSeconds")
        defaults.removeObject(forKey: "currentStreak")
        defaults.removeObject(forKey: "weeklyPickups")
        defaults.removeObject(forKey: "totalPickups")
        defaults.removeObject(forKey: "totalDaysTracked")
        defaults.removeObject(forKey: "lastActiveDate")

        // Reset και τα DeviceActivity data
        defaults.removeObject(forKey: todayPickupsKey())

        WidgetCenter.shared.reloadAllTimelines()
    }

    var averageMinutes: Int {
        guard todayPickups > 0 else { return 0 }
        return (todayTotalSeconds / todayPickups) / 60
    }

    var averageDailyPickups: Int {
        guard totalDaysTracked > 0 else { return totalPickups }
        return totalPickups / totalDaysTracked
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
        defaults.set(todayDateString(), forKey: "lastActiveDate")
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        defaults.set(language, forKey: "appLanguage")
        let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
        defaults.set(goal > 0 ? goal : 15, forKey: "dailyGoal")
    }

    func checkNewDay() {
        let lastDate = defaults.string(forKey: "lastActiveDate") ?? ""
        let today = todayDateString()

        if lastDate != today && lastDate != "" {
            let dailyGoal = defaults.integer(forKey: "dailyGoal")
            let goal = dailyGoal > 0 ? dailyGoal : 15

            if todayPickups <= goal && todayPickups > 0 {
                currentStreak += 1
            } else if todayPickups > goal {
                currentStreak = 0
            }

            if todayPickups > 0 { totalDaysTracked += 1 }

            todayPickups = 0
            todayTotalSeconds = 0
            weeklyPickups[currentDayIndex()] = 0
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

    /// Key που χρησιμοποιεί το DeviceActivity extension
    private func todayPickupsKey() -> String {
        return "picksy_pickups_\(todayDateString())"
    }

    deinit {
        midnightTimer?.invalidate()
    }
}

