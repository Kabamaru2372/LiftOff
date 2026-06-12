//
//  WeeklySummaryManager.swift
//  Picksy
//
//  Created by Fotios Pongas on 22.04.2026

import Foundation

struct WeeklySummary {
    let totalPickups: Int
    let dailyAverage: Int
    let bestDay: (name: String, pickups: Int)
    let worstDay: (name: String, pickups: Int)
    let greatDays: Int
    let okayDays: Int
    let roughDays: Int
    let daysWithCheckIn: Int
    let streak: Int
    let personalityType: PhonePersonalityType
}

@Observable
class WeeklySummaryManager {

    private let defaults = UserDefaults.standard
    private let lastShownKey = "picksyWeeklySummaryLastShown"

    /// Επιστρέφει summary για την τρέχουσα εβδομάδα
    func computeSummary(
        weeklyPickups: [Int],
        hourlyScreenTimeSecs: [Int] = Array(repeating: 0, count: 24),
        checkInManager: CheckInManager,
        streak: Int,
        dayNames: [String]
    ) -> WeeklySummary {

        let total = weeklyPickups.reduce(0, +)
        let average = total > 0 ? total / 7 : 0

        // Best/Worst day (μόνο μέρες με pickups > 0)
        let nonZeroDays = zip(weeklyPickups.indices, weeklyPickups).filter { $0.1 > 0 }

        let best: (String, Int)
        let worst: (String, Int)

        if nonZeroDays.isEmpty {
            best = (dayNames.first ?? "—", 0)
            worst = (dayNames.first ?? "—", 0)
        } else {
            let bestPair = nonZeroDays.min(by: { $0.1 < $1.1 })!
            let worstPair = nonZeroDays.max(by: { $0.1 < $1.1 })!
            best = (dayNames[bestPair.0], bestPair.1)
            worst = (dayNames[worstPair.0], worstPair.1)
        }

        // Mood counts
        let moods = checkInManager.last7DaysMoods
        let great = moods.filter { $0 == .great }.count
        let okay = moods.filter { $0 == .okay }.count
        let rough = moods.filter { $0 == .rough }.count
        let checked = moods.compactMap { $0 }.count

        let personality = PhonePersonalityType.detect(
            weeklyPickups: weeklyPickups,
            hourlyScreenTimeSecs: hourlyScreenTimeSecs
        )

        return WeeklySummary(
            totalPickups: total,
            dailyAverage: average,
            bestDay: best,
            worstDay: worst,
            greatDays: great,
            okayDays: okay,
            roughDays: rough,
            daysWithCheckIn: checked,
            streak: streak,
            personalityType: personality
        )
    }

    // MARK: - Should show summary

    /// Επιστρέφει true αν είναι Κυριακή μετά τις 20:00 και δεν έχει εμφανιστεί ήδη αυτή την εβδομάδα
    var shouldShowSummary: Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now) // Sunday = 1
        let hour = calendar.component(.hour, from: now)

        guard weekday == 1, hour >= 20 else { return false }

        // Έχει εμφανιστεί αυτή την εβδομάδα;
        if let lastShown = defaults.object(forKey: lastShownKey) as? Date {
            let lastWeek = calendar.component(.weekOfYear, from: lastShown)
            let currentWeek = calendar.component(.weekOfYear, from: now)
            let lastYear = calendar.component(.year, from: lastShown)
            let currentYear = calendar.component(.year, from: now)

            if lastWeek == currentWeek && lastYear == currentYear {
                return false
            }
        }

        return true
    }

    func markAsShown() {
        defaults.set(Date(), forKey: lastShownKey)
    }
}

