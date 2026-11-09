//
//  ForecastStore.swift
//  Picksy
//
//  Persistence + local-notification scheduling for the Pickup Forecast.
//  The model itself lives in Forecast.swift (pure, Foundation only).
//
//  Everything is on device: ForecastData is stored in the App Group defaults,
//  and at most 2 heads-up notifications are scheduled per calendar day. This
//  file never asks for notification permission; it only uses what the user
//  already granted elsewhere.
//

import Foundation
import UserNotifications

enum ForecastStore {
    static let appGroup = "group.fotiospongas.picksy"
    static let enabledKey = "pickupForecastEnabled"

    private static let dataKey = "picksy_forecast_v1"
    private static let corruptKey = "picksy_forecast_v1_unreadable"
    private static let sentDayKey = "picksy_forecast_sent_day"
    private static let sentTimesKey = "picksy_forecast_sent_times"
    private static let idPrefix = "picksy.forecast."
    private static let category = "PICKSY_FORECAST"
    private static let dailyCap = 2

    private static var shared: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// The master "Notifications" switch in Settings (defaults to on).
    private static var notificationsAllowed: Bool {
        UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    // MARK: Persistence

    static func load() -> ForecastData {
        guard let blob = shared.data(forKey: dataKey) else { return ForecastData() }
        guard let decoded = try? JSONDecoder().decode(ForecastData.self, from: blob) else {
            // Keep an unreadable blob (e.g. written by a newer schema) instead of
            // letting the next fold overwrite the history.
            if shared.data(forKey: corruptKey) == nil { shared.set(blob, forKey: corruptKey) }
            return ForecastData()
        }
        return decoded.normalized()
    }

    static func save(_ data: ForecastData) {
        guard let blob = try? JSONEncoder().encode(data) else { return }
        shared.set(blob, forKey: dataKey)
    }

    /// Fold a finished day. hours must be 24 counts.
    static func foldRollover(hours: [Int], day: Date) {
        save(load().folding(hours: hours, on: day))
    }

    /// One-time seed from the 7x24 HourlyTracker rows when nothing is trained yet.
    /// rows[d] is d days before todayRowDate; row 0 (today, partial) and empty
    /// rows (days before the app was installed) are skipped.
    static func backfillIfNeeded(rows: [[Int]], todayRowDate: Date) {
        let current = load()
        guard current.trainedDays == 0 else { return }
        let cal = Calendar.current
        let seeded = (1...6).reversed().reduce(current) { acc, d in
            guard d < rows.count, rows[d].contains(where: { $0 > 0 }),
                  let day = cal.date(byAdding: .day, value: -d, to: todayRowDate)
            else { return acc }
            return acc.folding(hours: rows[d], on: day)
        }
        if seeded != current { save(seeded) }
    }

    // MARK: Windows

    private static var quietHours: QuietHours {
        let d = UserDefaults.standard
        return QuietHours(
            start: d.object(forKey: "quietStart") as? Int ?? 22,
            end: d.object(forKey: "quietEnd") as? Int ?? 7
        )
    }

    /// All of today's risky windows (max 2, outside quiet hours), including ones
    /// already past, so the Stats card can show the whole day. Scheduling uses
    /// its own stricter "still ahead" filter.
    static func todaysWindows(now: Date = Date()) -> [ForecastData.Window] {
        load().windows(on: now, after: .distantPast, quiet: quietHours)
    }

    // MARK: Scheduling

    /// Recompute today's remaining windows and (re)schedule up to 2 notifications.
    ///
    /// Deterministic on purpose: launch and foreground can both call this at
    /// once, so the daily cap comes from the timestamps scheduled today (those
    /// already in the past count as fired), never from the pending list.
    static func rescheduleToday(now: Date = Date()) {
        guard isEnabled, notificationsAllowed else { cancelAll(); return }
        let data = load()
        guard data.isReady else { cancelAll(); return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let ok = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            // The switches may have flipped while the settings call was in flight.
            guard ok, isEnabled, notificationsAllowed else { cancelAll(); return }

            let fired = scheduledToday(now: now).filter { $0 <= now.timeIntervalSince1970 }
            let room = max(0, dailyCap - fired.count)
            let windows = Array(data.windows(on: now, after: now, quiet: quietHours).prefix(room))

            center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
            windows.forEach { schedule($0, center: center) }
            recordScheduled(fired + windows.map { $0.notifyAt.timeIntervalSince1970 }, now: now)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIdentifiers)
    }

    private static var allIdentifiers: [String] { (0..<24).map { "\(idPrefix)\($0)" } }

    // MARK: Daily cap

    /// notifyAt timestamps scheduled for today; empty once the day changes.
    private static func scheduledToday(now: Date) -> [Double] {
        guard shared.string(forKey: sentDayKey) == ForecastData.dayKey(now) else { return [] }
        return shared.array(forKey: sentTimesKey) as? [Double] ?? []
    }

    private static func recordScheduled(_ times: [Double], now: Date) {
        shared.set(ForecastData.dayKey(now), forKey: sentDayKey)
        shared.set(times, forKey: sentTimesKey)
    }

    // MARK: Notification

    private static func schedule(_ window: ForecastData.Window, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        let (title, body) = copy(hour: window.hour)
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = ["type": "forecast"]

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: window.notifyAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        let request = UNNotificationRequest(identifier: "\(idPrefix)\(window.hour)", content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    private static func copy(hour: Int) -> (title: String, body: String) {
        let hh = String(format: "%02d", hour)
        func t(_ en: String, _ el: String, _ de: String) -> String {
            switch UserDefaults.standard.string(forKey: "appLanguage") {
            case "Ελληνικά": return el
            case "Deutsch": return de
            default: return en
            }
        }
        return (
            t("Heads-up from Picksy 🌱", "Μικρή υπενθύμιση από το Picksy 🌱", "Kurzer Hinweis von Picksy 🌱"),
            t("A busy hour is coming up at \(hh):00. Maybe leave the phone down for a bit?",
              "Στις \(hh):00 έρχεται μια ώρα που συνήθως χρησιμοποιείς πολύ το κινητό. Μια μικρή παύση;",
              "Um \(hh):00 greifst du meist öfter zum Handy. Vielleicht kurz liegen lassen?")
        )
    }
}
