//
//  ForecastChecks
//
//  Plain-Swift check runner for LiftOff/Forecast.swift (the project has no
//  test target). Run from the repo root:
//
//    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
//      xcrun swiftc LiftOff/Forecast.swift Tools/ForecastChecks/main.swift -o /tmp/forecast-checks \
//      && /tmp/forecast-checks
//

import Foundation

var failures = 0
var checks = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    checks += 1
    if !condition() {
        failures += 1
        print("FAIL (line \(line)): \(message)")
    }
}

func makeCalendar(_ id: String = "UTC") -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: id)!
    return cal
}

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, cal: Calendar) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

/// 24 hourly counts: `base` everywhere, `peak` at `peakHour`.
func hours(base: Int = 1, peak: Int = 1, peakHour: Int = 21) -> [Int] {
    (0..<24).map { $0 == peakHour ? peak : base }
}

/// `days` consecutive days ending the day before `end`, all with the same hourly shape.
func trained(days: Int, endingBefore end: Date, shape: [Int], cal: Calendar) -> ForecastData {
    var data = ForecastData()
    for offset in stride(from: days, through: 1, by: -1) {
        let day = cal.date(byAdding: .day, value: -offset, to: end)!
        data = data.folding(hours: shape, on: day, calendar: cal)
    }
    return data
}

let utc = makeCalendar()

// MARK: folding

do {
    let monday = date(2026, 11, 2, 12, cal: utc)
    let weekdayIndex = utc.component(.weekday, from: monday) - 1
    let data = ForecastData().folding(hours: hours(base: 2, peak: 9), on: monday, calendar: utc)
    check(data.dayCounts[weekdayIndex] == 1, "day count increments on the right weekday")
    check(data.trainedDays == 1, "trainedDays counts folded days")
    check(data.sums[weekdayIndex][21] == 9, "hour sums stored")
    check(data.sums[weekdayIndex][3] == 2, "base hour sums stored")
    check(data.lastFoldedDay == "2026-11-02", "lastFoldedDay recorded")

    let again = data.folding(hours: hours(base: 2, peak: 9), on: monday, calendar: utc)
    check(again == data, "folding the same day twice is a no-op")

    let earlier = date(2026, 11, 1, 12, cal: utc)
    let older = data.folding(hours: hours(), on: earlier, calendar: utc)
    check(older == data, "folding an older day is ignored")

    let bad = data.folding(hours: [1, 2, 3], on: date(2026, 11, 3, cal: utc), calendar: utc)
    check(bad == data, "wrong-length hour array is ignored")

    let negative = ForecastData().folding(hours: hours(base: -5, peak: 4), on: monday, calendar: utc)
    check(negative.sums[weekdayIndex][0] == 0, "negative counts clamp to zero")
    check(negative.sums[weekdayIndex][21] == 4, "positive counts survive clamping")
}

// MARK: readiness

do {
    let now = date(2026, 11, 20, 12, cal: utc)
    let nine = trained(days: 9, endingBefore: now, shape: hours(), cal: utc)
    let ten = trained(days: ForecastData.minTrainedDays, endingBefore: now, shape: hours(), cal: utc)
    check(!nine.isReady, "9 days is not ready")
    check(ten.isReady, "minTrainedDays is ready")
    check(nine.progress > 0 && nine.progress < 1, "progress is partial while learning")
    check(ten.progress == 1, "progress caps at 1")
}

// MARK: expectation, shrinkage and risk

do {
    let now = date(2026, 11, 30, 12, cal: utc)
    let data = trained(days: 14, endingBefore: now, shape: hours(base: 1, peak: 9, peakHour: 21), cal: utc)
    let weekday = utc.component(.weekday, from: now) - 1
    check(abs(data.expected(weekday: weekday, hour: 21) - 9) < 0.001, "expected pickups at the peak hour")
    check(abs(data.expected(weekday: weekday, hour: 5) - 1) < 0.001, "expected pickups at a calm hour")
    check(data.risk(weekday: weekday, hour: 21) > 2, "peak hour has high relative risk")
    check(data.risk(weekday: weekday, hour: 5) < 1, "calm hour has below-average risk")

    // A weekday with no samples falls back to the global hourly mean.
    var sparse = ForecastData()
    for offset in stride(from: 14, through: 1, by: -1) {
        let day = utc.date(byAdding: .day, value: -offset, to: now)!
        if utc.component(.weekday, from: day) == 1 { continue }   // never fold a Sunday
        sparse = sparse.folding(hours: hours(base: 1, peak: 9, peakHour: 21), on: day, calendar: utc)
    }
    check(sparse.dayCounts[0] == 0, "no Sunday samples were folded")
    check(sparse.expected(weekday: 0, hour: 21) > 5, "empty weekday borrows the global hourly mean")
    check(ForecastData().risk(weekday: 0, hour: 0) == 0, "empty data has zero risk")
}

// MARK: windows

do {
    let day = date(2026, 12, 7, cal: utc)                       // the day we forecast
    let data = trained(days: 14, endingBefore: day, shape: hours(base: 1, peak: 9, peakHour: 21), cal: utc)

    let evening = data.windows(on: day, after: date(2026, 12, 7, 18, cal: utc), calendar: utc)
    check(evening.count == 1, "only the evening peak qualifies")
    check(evening.first?.hour == 21, "peak window is hour 21")
    check(evening.first?.notifyAt == date(2026, 12, 7, 20, 50, cal: utc), "notification fires 10 minutes before the window")

    let late = data.windows(on: day, after: date(2026, 12, 7, 20, 55, cal: utc), calendar: utc)
    check(late.isEmpty, "a window whose notification time has passed is dropped")

    let quiet = data.windows(on: day, after: date(2026, 12, 7, 18, cal: utc),
                             quiet: QuietHours(start: 20, end: 23), calendar: utc)
    check(quiet.isEmpty, "quiet hours suppress the notification")

    let wrap = data.windows(on: day, after: date(2026, 12, 7, 18, cal: utc),
                            quiet: QuietHours(start: 22, end: 7), calendar: utc)
    check(wrap.count == 1, "wrap-around quiet hours (22 to 7) do not hide 20:50")

    let notReady = trained(days: 4, endingBefore: day, shape: hours(base: 1, peak: 9, peakHour: 21), cal: utc)
    check(notReady.windows(on: day, after: date(2026, 12, 7, 6, cal: utc), calendar: utc).isEmpty,
          "no windows while still learning")

    // Cap: three equal peaks, only two are returned, in time order.
    let multi = (0..<24).map { [9, 13, 21].contains($0) ? 9 : 1 }
    let busy = trained(days: 14, endingBefore: day, shape: multi, cal: utc)
    let capped = busy.windows(on: day, after: date(2026, 12, 7, 6, cal: utc), calendar: utc)
    check(capped.count == 2, "at most two windows per day")
    check(capped == capped.sorted { $0.notifyAt < $1.notifyAt }, "windows are returned in time order")

    // A flat day has no standout window.
    let flat = trained(days: 14, endingBefore: day, shape: hours(base: 3, peak: 3), cal: utc)
    check(flat.windows(on: day, after: date(2026, 12, 7, 6, cal: utc), calendar: utc).isEmpty,
          "a flat profile produces no windows")

    let strip = data.todayRisks(on: day, calendar: utc)
    check(strip.count == 24, "risk strip has 24 hours")
    check(strip[21] == strip.max(), "risk strip peaks at hour 21")
}

// MARK: time zones

do {
    let athens = makeCalendar("Europe/Athens")
    let day = date(2026, 10, 26, cal: athens)                  // DST ends on 25 Oct 2026 in Europe
    let data = trained(days: 14, endingBefore: day, shape: hours(base: 1, peak: 9, peakHour: 21), cal: athens)
    let w = data.windows(on: day, after: date(2026, 10, 26, 18, cal: athens), calendar: athens)
    check(w.first?.notifyAt == date(2026, 10, 26, 20, 50, cal: athens), "local-time notification survives a DST change")
}

// MARK: persistence

do {
    let monday = date(2026, 11, 2, 12, cal: utc)
    let data = ForecastData().folding(hours: hours(base: 2, peak: 9), on: monday, calendar: utc)
    let encoded = try JSONEncoder().encode(data)
    let decoded = try JSONDecoder().decode(ForecastData.self, from: encoded)
    check(decoded == data, "Codable round trip")

    // A corrupt or old blob with the wrong shape must not crash and must self-heal.
    let broken = #"{"sums":[[1]],"dayCounts":[1],"lastFoldedDay":"2026-11-02"}"#.data(using: .utf8)!
    let healed = (try? JSONDecoder().decode(ForecastData.self, from: broken)).map { $0.normalized() }
    check(healed?.sums.count == 7 && healed?.sums.allSatisfy { $0.count == 24 } == true, "wrong-shaped data normalizes to 7x24")
    check(healed?.dayCounts.count == 7, "wrong-shaped day counts normalize to 7")
}

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
