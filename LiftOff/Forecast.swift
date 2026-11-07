//
//  Forecast.swift
//  Picksy
//
//  Pickup Forecast: learns, on device, when in the week the user reaches for
//  the phone most, so Picksy can nudge a few minutes BEFORE the next risky
//  window instead of after the habit has already fired.
//
//  ForecastData is a pure value type (Foundation only, no defaults, no UIKit)
//  so it can be checked on its own: see Tools/ForecastChecks/main.swift.
//  ForecastStore.swift is the thin persistence + scheduling layer on top.
//
//  Model: a weekday x hour grid of summed pickups plus how many days of each
//  weekday were folded in. A weekday with few samples is blended with the
//  all-days hourly mean (shrinkage), so the grid is useful after ~10 days
//  instead of needing 10 samples of every single weekday.
//

import Foundation

// MARK: - Quiet hours

/// Local-time range in which no forecast notification may fire. `start` to
/// `end` wraps past midnight when start > end (e.g. 22 to 7).
struct QuietHours: Equatable {
    let start: Int
    let end: Int

    func contains(hour: Int) -> Bool {
        if start == end { return false }
        if start < end { return hour >= start && hour < end }
        return hour >= start || hour < end
    }
}

// MARK: - Data

struct ForecastData: Codable, Equatable {
    /// Days of history before the forecast is trusted.
    static let minTrainedDays = 10
    /// Pseudo-samples of the all-days hourly mean blended into each weekday.
    static let shrinkage = 2.0
    /// A window must be this many times busier than the average hour.
    static let riskThreshold = 1.5
    /// ...and expect at least this many pickups, so quiet users get no noise.
    static let minExpectedPickups = 2.0

    /// [weekday - 1][hour]: summed pickups. Index 0 is Sunday (Calendar.weekday 1).
    var sums: [[Double]] = Array(repeating: Array(repeating: 0, count: 24), count: 7)
    /// Number of days folded in per weekday.
    var dayCounts: [Int] = Array(repeating: 0, count: 7)
    /// "yyyy-MM-dd" of the newest folded day; older or equal days are ignored.
    var lastFoldedDay: String = ""

    // MARK: Keys

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: Shape safety

    /// Returns a copy with exactly 7x24 sums and 7 day counts, so a corrupt or
    /// older stored blob can never crash an index lookup.
    func normalized() -> ForecastData {
        var next = self
        next.sums = (0..<7).map { w in
            let row = w < sums.count ? sums[w] : []
            return (0..<24).map { $0 < row.count ? row[$0] : 0 }
        }
        next.dayCounts = (0..<7).map { $0 < dayCounts.count ? dayCounts[$0] : 0 }
        return next
    }

    // MARK: Learning (returns a new value, never mutates)

    /// Folds one finished day (24 hourly pickup counts) into the grid.
    /// Idempotent: a day that is not newer than `lastFoldedDay` is ignored.
    func folding(hours: [Int], on day: Date, calendar: Calendar = .current) -> ForecastData {
        guard hours.count == 24 else { return self }
        let key = Self.dayKey(day, calendar: calendar)
        guard key > lastFoldedDay else { return self }

        var next = normalized()
        let weekday = calendar.component(.weekday, from: day) - 1
        guard (0..<7).contains(weekday) else { return self }

        next.sums[weekday] = zip(next.sums[weekday], hours).map { $0 + Double(max($1, 0)) }
        next.dayCounts[weekday] += 1
        next.lastFoldedDay = key
        return next
    }

    // MARK: Reading

    var trainedDays: Int { dayCounts.reduce(0, +) }

    var isReady: Bool { trainedDays >= Self.minTrainedDays }

    /// 0...1, for the "learning" state of the card.
    var progress: Double {
        min(1, Double(trainedDays) / Double(Self.minTrainedDays))
    }

    /// Mean pickups at `hour` across every folded day, any weekday.
    private func globalMean(hour: Int) -> Double {
        let days = trainedDays
        guard days > 0 else { return 0 }
        return sums.reduce(0) { $0 + $1[hour] } / Double(days)
    }

    /// Mean pickups per hour, averaged over the day.
    private var overallMean: Double {
        (0..<24).reduce(0) { $0 + globalMean(hour: $1) } / 24
    }

    /// Expected pickups at `hour` on `weekday` (0 = Sunday), blended toward the
    /// all-days mean while that weekday has few samples.
    func expected(weekday: Int, hour: Int) -> Double {
        let safe = normalized()
        guard (0..<7).contains(weekday), (0..<24).contains(hour), safe.trainedDays > 0 else { return 0 }
        let k = Self.shrinkage
        return (safe.sums[weekday][hour] + k * safe.globalMean(hour: hour))
            / (Double(safe.dayCounts[weekday]) + k)
    }

    /// How many times busier than the average hour this slot is expected to be.
    func risk(weekday: Int, hour: Int) -> Double {
        let safe = normalized()
        let mean = safe.overallMean
        guard mean > 0 else { return 0 }
        return safe.expected(weekday: weekday, hour: hour) / mean
    }

    /// Risk for each of the 24 hours of `date`'s weekday (the Stats strip).
    func todayRisks(on date: Date, calendar: Calendar = .current) -> [Double] {
        let weekday = calendar.component(.weekday, from: date) - 1
        return (0..<24).map { risk(weekday: weekday, hour: $0) }
    }

    // MARK: Windows

    struct Window: Equatable {
        let hour: Int
        let risk: Double
        let expected: Double
        /// When the heads-up should fire (window start minus the lead time).
        let notifyAt: Date
    }

    /// Up to `maxCount` risky windows on `date` whose notification time is
    /// still ahead of `now` and outside quiet hours, in time order.
    func windows(
        on date: Date,
        after now: Date,
        leadMinutes: Int = 10,
        maxCount: Int = 2,
        quiet: QuietHours? = nil,
        calendar: Calendar = .current
    ) -> [Window] {
        guard isReady else { return [] }
        let weekday = calendar.component(.weekday, from: date) - 1
        let dayStart = calendar.startOfDay(for: date)

        let candidates: [Window] = (0..<24).compactMap { hour in
            let r = risk(weekday: weekday, hour: hour)
            let e = expected(weekday: weekday, hour: hour)
            guard r >= Self.riskThreshold, e >= Self.minExpectedPickups,
                  let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart)
            else { return nil }
            let notifyAt = start.addingTimeInterval(-Double(leadMinutes) * 60)
            guard notifyAt > now else { return nil }
            if let quiet, quiet.contains(hour: calendar.component(.hour, from: notifyAt)) { return nil }
            return Window(hour: hour, risk: r, expected: e, notifyAt: notifyAt)
        }

        return candidates
            .sorted { $0.risk != $1.risk ? $0.risk > $1.risk : $0.hour < $1.hour }
            .prefix(maxCount)
            .sorted { $0.notifyAt < $1.notifyAt }
    }
}
