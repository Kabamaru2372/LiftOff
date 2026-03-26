//
//  DataStore.swift
//  LiftOff
//
//  Created by Fotios Pongas on 24.03.2026
//  Αποθηκεύει τα στατιστικά τοπικά στο κινητό.
//  Χρησιμοποιεί UserDefaults — σαν ένα μικρό dictionary
//  που μένει αποθηκευμένο ακόμα κι αν κλείσεις την app.

import Foundation
import SwiftUI

@Observable
class DataStore {

    var todayPickups: Int = 0
    var todayTotalSeconds: Int = 0
    var currentStreak: Int = 0
    var weeklyPickups: [Int] = [0, 0, 0, 0, 0, 0, 0]

    private let defaults = UserDefaults.standard

    init() {
        loadData()
    }

    func loadData() {
        todayPickups = defaults.integer(forKey: "todayPickups")
        todayTotalSeconds = defaults.integer(forKey: "todayTotalSeconds")
        currentStreak = defaults.integer(forKey: "currentStreak")

        if let saved = defaults.array(forKey: "weeklyPickups") as? [Int] {
            weeklyPickups = saved
        }

        checkNewDay()
    }

    func recordPickup() {
        todayPickups += 1
        let dayIndex = currentDayIndex()
        weeklyPickups[dayIndex] = todayPickups
        saveData()
    }
    


    func addUsageTime(seconds: Int) {
        todayTotalSeconds += seconds
        saveData()
    }

    var averageMinutes: Int {
        guard todayPickups > 0 else { return 0 }
        return (todayTotalSeconds / todayPickups) / 60
    }

    // MARK: - Private

    private func saveData() {
        defaults.set(todayPickups, forKey: "todayPickups")
        defaults.set(todayTotalSeconds, forKey: "todayTotalSeconds")
        defaults.set(currentStreak, forKey: "currentStreak")
        defaults.set(weeklyPickups, forKey: "weeklyPickups")
        defaults.set(todayDateString(), forKey: "lastActiveDate")
    }

    private func checkNewDay() {
        let lastDate = defaults.string(forKey: "lastActiveDate") ?? ""
        let today = todayDateString()

        if lastDate != today {
            let dailyGoal = defaults.integer(forKey: "dailyGoal")
            let goal = dailyGoal > 0 ? dailyGoal : 15

            if todayPickups <= goal && todayPickups > 0 {
                currentStreak += 1
            } else if todayPickups > goal {
                currentStreak = 0
            }

            todayPickups = 0
            todayTotalSeconds = 0

            let dayIndex = currentDayIndex()
            weeklyPickups[dayIndex] = 0

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
}

