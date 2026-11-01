//
//  DuoFold.swift
//  Picksy
//
//  Counts how often an iPhone Duo is folded / unfolded. Events arrive from the
//  "Record Duo fold" App Intent (DuoFoldIntent.swift), run by a Shortcuts
//  automation — that is the only way to count while Picksy is closed or in the
//  background. Data lives in the App Group so the intent, the app and any
//  widget see the same numbers.
//
//  DuoFoldData is a pure value type (no UIKit, no defaults) so it can be unit
//  tested on its own; DuoFoldStore is the thin persistence layer on top.
//

import Foundation

// MARK: - Event kind

enum DuoFoldKind: String, Codable {
    /// The automation did not say which way the Duo moved.
    case any
    case opened
    case closed
}

// MARK: - Data

struct DuoFoldData: Codable, Equatable {
    struct HourBucket: Codable, Equatable {
        var date: String = ""
        var counts: [Int] = Array(repeating: 0, count: 24)
    }

    /// Every recorded event (open + close + unknown).
    var total: Int = 0
    var opens: Int = 0
    var closes: Int = 0
    /// "yyyy-MM-dd" → events that day. Trimmed to `retentionDays`.
    var days: [String: Int] = [:]
    /// Events per hour for the most recent recorded day.
    var hours: HourBucket = HourBucket()
    /// Unix seconds of the last event.
    var last: Double? = nil
    /// True once the Scriptable history was imported (import is one-shot).
    var importedFromScriptable: Bool = false

    static let retentionDays = 30

    // MARK: Keys

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: Recording (returns a new value, never mutates)

    func recording(_ kind: DuoFoldKind, at date: Date, calendar: Calendar = .current) -> DuoFoldData {
        var next = self
        let key = Self.dayKey(date, calendar: calendar)
        next.total += 1
        switch kind {
        case .opened: next.opens += 1
        case .closed: next.closes += 1
        case .any: break
        }
        next.days[key, default: 0] += 1

        if next.hours.date != key { next.hours = HourBucket(date: key) }
        let hour = min(max(calendar.component(.hour, from: date), 0), 23)
        next.hours.counts[hour] += 1

        next.last = max(next.last ?? 0, date.timeIntervalSince1970)
        return next.trimmed(now: date, calendar: calendar)
    }

    func trimmed(now: Date, calendar: Calendar = .current) -> DuoFoldData {
        guard let cutoff = calendar.date(byAdding: .day, value: -Self.retentionDays, to: now) else { return self }
        let cutoffKey = Self.dayKey(cutoff, calendar: calendar)
        var next = self
        next.days = days.filter { $0.key >= cutoffKey }
        return next
    }

    // MARK: Reading

    struct DayCount: Equatable {
        let key: String
        let weekdayLetter: String
        let count: Int
    }

    /// Last 7 days, oldest first; the final element is today.
    func week(now: Date, calendar: Calendar = .current) -> [DayCount] {
        (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let key = Self.dayKey(day, calendar: calendar)
            let weekday = calendar.component(.weekday, from: day)          // 1 = Sunday
            let letters = Array("SMTWTFS")
            return DayCount(key: key, weekdayLetter: String(letters[(weekday - 1) % 7]), count: days[key] ?? 0)
        }
    }

    func today(now: Date, calendar: Calendar = .current) -> Int {
        days[Self.dayKey(now, calendar: calendar)] ?? 0
    }

    func yesterday(now: Date, calendar: Calendar = .current) -> Int {
        guard let y = calendar.date(byAdding: .day, value: -1, to: now) else { return 0 }
        return days[Self.dayKey(y, calendar: calendar)] ?? 0
    }

    func weekTotal(now: Date, calendar: Calendar = .current) -> Int {
        week(now: now, calendar: calendar).reduce(0) { $0 + $1.count }
    }

    /// Hour (0–23) with the most events today, or nil when there are none.
    func peakHourToday(now: Date, calendar: Calendar = .current) -> Int? {
        guard hours.date == Self.dayKey(now, calendar: calendar),
              let top = hours.counts.max(), top > 0
        else { return nil }
        return hours.counts.firstIndex(of: top)
    }

    /// Full open/close cycles. With explicit kinds, `opens`; with an automation
    /// that fires on every fold without saying which way, half the events.
    var openings: Int {
        opens > 0 ? opens : (total + 1) / 2
    }

    var hasData: Bool { total > 0 }

    // MARK: Scriptable import

    /// Shape of `duo_folds.json` written by the "Duo Folds" Scriptable script.
    private struct ScriptableFile: Decodable {
        struct Hours: Decodable { let date: String?; let h: [Int]? }
        let total: Int?
        let days: [String: Int]?
        let hours: Hours?
        let last: Double?          // milliseconds
    }

    enum ImportError: Error { case unreadable, alreadyImported, empty }

    /// Merges a Scriptable history into this data. One-shot: importing twice
    /// would double the numbers, so a second attempt throws.
    func importingScriptable(_ json: Data, now: Date, calendar: Calendar = .current) throws -> DuoFoldData {
        guard !importedFromScriptable else { throw ImportError.alreadyImported }
        guard let file = try? JSONDecoder().decode(ScriptableFile.self, from: json) else { throw ImportError.unreadable }
        let importedTotal = max(file.total ?? 0, 0)
        guard importedTotal > 0 else { throw ImportError.empty }

        var next = self
        next.total += importedTotal
        for (key, count) in file.days ?? [:] where count > 0 {
            next.days[key, default: 0] += count
        }
        if let h = file.hours, let date = h.date, !date.isEmpty,
           let counts = h.h, counts.count == 24 {
            if next.hours.date == date {
                next.hours.counts = zip(next.hours.counts, counts).map { $0 + max($1, 0) }
            } else if next.hours.date < date {
                next.hours = HourBucket(date: date, counts: counts.map { max($0, 0) })
            }
        }
        if let ms = file.last, ms > 0 {
            next.last = max(next.last ?? 0, ms / 1000)
        }
        next.importedFromScriptable = true
        return next.trimmed(now: now, calendar: calendar)
    }
}
