//
//  HourlyTracker.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.03.26.

import Foundation

@Observable
class HourlyTracker {

    // 7 ημέρες x 24 ώρες
    // Index 0 = σήμερα, 1 = χθες, ... 6 = πριν 6 μέρες
    var hourlyData: [[Int]] = Array(repeating: Array(repeating: 0, count: 24), count: 7)

    private let defaults = UserDefaults.standard
    private let storageKey = "hourlyPickupData"
    private let lastDateKey = "hourlyLastDate"

    init() {
        loadData()
    }

    // Καταγράφει pickup στην τρέχουσα ώρα
    func recordPickup() {
        checkNewDay()
        let hour = Calendar.current.component(.hour, from: Date())
        hourlyData[0][hour] += 1
        saveData()
    }

    // MARK: - Total for day (νέο)

    /// Συνολικά pickups για μια συγκεκριμένη μέρα
    /// daysAgo: 0 = σήμερα, 1 = χθες, etc.
    func totalForDay(daysAgo: Int) -> Int {
        guard daysAgo >= 0 && daysAgo < 7 else { return 0 }
        return hourlyData[daysAgo].reduce(0, +)
    }

    // MARK: - Worst hours

    var worstHours: [(hour: Int, avgPickups: Double)] {
        var hourAverages: [(hour: Int, avg: Double)] = []

        for hour in 0..<24 {
            var total = 0
            var daysWithData = 0

            for day in 0..<7 {
                let count = hourlyData[day][hour]
                if count > 0 {
                    total += count
                    daysWithData += 1
                }
            }

            let avg = daysWithData > 0 ? Double(total) / Double(daysWithData) : 0
            hourAverages.append((hour: hour, avg: avg))
        }

        return hourAverages
            .sorted { $0.avg > $1.avg }
            .prefix(3)
            .map { (hour: $0.hour, avgPickups: $0.avg) }
    }

    var maxHourlyCount: Int {
        var maxVal = 1
        for day in hourlyData {
            for count in day {
                if count > maxVal { maxVal = count }
            }
        }
        return maxVal
    }

    func hasImproved(hour: Int) -> Bool {
        let recent = Double(hourlyData[0][hour] + hourlyData[1][hour]) / 2.0

        var olderTotal = 0
        var olderDays = 0
        for day in 2..<7 {
            if hourlyData[day][hour] > 0 {
                olderTotal += hourlyData[day][hour]
                olderDays += 1
            }
        }

        guard olderDays > 0 else { return false }
        let olderAvg = Double(olderTotal) / Double(olderDays)

        return recent < olderAvg * 0.7
    }

    func dayLabel(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // MARK: - Persistence

    private func checkNewDay() {
        let today = todayString()
        let lastDate = defaults.string(forKey: lastDateKey) ?? ""

        if lastDate != today {
            var newData = Array(repeating: Array(repeating: 0, count: 24), count: 7)
            for i in 0..<6 {
                newData[i + 1] = hourlyData[i]
            }
            hourlyData = newData
            defaults.set(today, forKey: lastDateKey)
            saveData()
        }
    }

    private func saveData() {
        let flat = hourlyData.flatMap { $0 }
        defaults.set(flat, forKey: storageKey)
    }

    private func loadData() {
        guard let flat = defaults.array(forKey: storageKey) as? [Int],
              flat.count == 168 else { return }

        for day in 0..<7 {
            for hour in 0..<24 {
                hourlyData[day][hour] = flat[day * 24 + hour]
            }
        }
        checkNewDay()
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

