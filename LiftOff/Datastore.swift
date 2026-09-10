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

    /// Bumped every time an extension reports a new confirmed screen-time value
    /// (via the Darwin "screenTimeUpdated" notification, foreground, onAppear,
    /// or the Nudge timer). The confirmed-time computed properties below read
    /// this tick so that mutating it forces @Observable-tracked views to
    /// re-evaluate — a plain UserDefaults read is NOT observable on its own, so
    /// without this a cross-process write would never refresh the UI.
    private var screenTimeRefreshTick: Int = 0

    /// Screen time confirmed by Apple's DeviceActivity threshold events.
    /// These fire in the background even when Picksy is suspended — unlike
    /// ScreenUnlockDetector which only works while the app is alive.
    ///
    /// Computed (live read) so it can never get stuck at a stale 0: it always
    /// reflects whatever the extension last wrote to the App Group. The tick
    /// read makes the access @Observable so views refresh on cross-process
    /// writes.
    var appleConfirmedScreenTimeSecs: Int {
        _ = screenTimeRefreshTick
        let storedDate = defaults.string(forKey: "picksy_apple_screen_time_date")
        guard storedDate == todayDateString() else { return 0 }
        let raw = defaults.integer(forKey: "picksy_apple_screen_time_secs")
        // Self-healing: a stale DeviceActivity callback (queued yesterday, delivered
        // today after midnight) can write yesterday's total as today's. If the stored
        // value exceeds elapsed time since the midnight reset it is physically
        // impossible — clear it so the display and duel creation don't lock on it.
        let resetEpoch = defaults.double(forKey: "picksy_ladder_reset_epoch")
        if resetEpoch > 0, Double(raw) > Date().timeIntervalSince1970 - resetEpoch {
            defaults.set(0, forKey: "picksy_apple_screen_time_secs")
            defaults.removeObject(forKey: "picksy_apple_screen_time_date")
            return 0
        }
        return raw
    }

    /// The whole-device screen-time total written to the App Group by the
    /// DeviceActivityReport extension (`PicksyDeviceReport`) — the same number
    /// the Apps tab shows. Date-guarded so a value from a previous day is never
    /// shown. Returns 0 only until the report has rendered at least once today.
    var reportConfirmedScreenTimeSecs: Int {
        _ = screenTimeRefreshTick
        let storedDate = defaults.string(forKey: "picksy_report_screen_time_date")
        guard storedDate == todayDateString() else { return 0 }
        return defaults.integer(forKey: "picksy_report_screen_time_secs")
    }

    /// Best-estimate total screen time for today — the single source of truth
    /// for EVERY screen-time display in the app (Stats tab, Nudge, Watch,
    /// Friends/Duel scores), kept consistent with the Apps tab.
    ///
    /// Takes the maximum of:
    ///   • reportConfirmedScreenTimeSecs (whole-device total — matches Apps tab)
    ///   • appleConfirmedScreenTimeSecs (Apple threshold events — lower bound,
    ///     available even before the report has rendered)
    ///   • todayTotalSeconds (ScreenUnlockDetector — accurate only while alive)
    ///
    /// Clamped to elapsed seconds since local midnight — screen time can never
    /// exceed wall-clock time elapsed today. Guards against a corrupted
    /// accumulator (e.g. a stale ScreenUnlockDetector session, observed once as
    /// 23h30m from a single missed lock event) ever displaying an impossible value.
    var bestScreenTimeSecs: Int {
        let raw = max(todayTotalSeconds, max(appleConfirmedScreenTimeSecs, reportConfirmedScreenTimeSecs))
        return min(raw, Self.secondsSinceMidnight())
    }

    static func secondsSinceMidnight(now: Date = Date()) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: now)
        return max(0, Int(now.timeIntervalSince(startOfDay)))
    }

    /// Forces the confirmed-time computed properties to re-publish so any
    /// on-screen view picks up a fresh cross-process write. Safe to call often;
    /// it just bumps the observable tick (the actual values are read live).
    func refreshConfirmedScreenTime() {
        screenTimeRefreshTick &+= 1
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

        if let saved = defaults.array(forKey: "weeklyPickups") as? [Int], saved.count == 7 {
            weeklyPickups = saved
        }
        // If a malformed/short array was ever persisted (e.g. an older schema),
        // keep the safe [0,0,0,0,0,0,0] default instead of leaving weeklyPickups
        // with < 7 elements — checkNewDay()'s weeklyPickups[currentDayIndex()] = 0
        // would otherwise crash with an out-of-range index exactly at the
        // midnight day-boundary.
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

        // Every 5th pickup (starting at 5), ask why the user picked up the phone.
        if todayPickups >= 5 && todayPickups % 5 == 0 {
            NotificationCenter.default.post(name: .picksyAskWhyPickup, object: nil)
        }
    }

    func addUsageTime(seconds: Int) {
        todayTotalSeconds += seconds
        // Also track in the per-hour bucket for friend sync
        let hour = Calendar.current.component(.hour, from: Date())
        hourlyScreenTimeSecs[hour] += seconds
        saveData()
    }

    // MARK: - Dynamic Island "plant" growth/wilt

    /// Grows to 100 over ~2h of not touching the phone at all (matches the old
    /// growth-emoji timing). Public so LiveActivityManager can extrapolate the
    /// SAME curve when populating ContentState.
    static let plantGrowthRatePerSecond = 100.0 / (2 * 60 * 60)

    /// Wilts 3x faster than it grows — easy to lose, slower to rebuild, which is
    /// the whole point of the "digital watering" nudge. Applied CONTINUOUSLY for
    /// as long as a screen session is active (see beginPlantSession/endPlantSession)
    /// — the plant visibly wilts in real time the moment the phone is picked up,
    /// not just retroactively once the user puts it back down.
    static let plantWiltRatePerSecond = plantGrowthRatePerSecond * 3

    /// If a session is still marked "active" after this long, we almost
    /// certainly missed the real screen-lock notification (e.g. the app was
    /// suspended/killed at exactly the wrong moment) — extrapolatedPlantHealth
    /// below treats the session as having ended at this cutoff and resumes
    /// growth, instead of leaving the plant stuck at 0 forever. Mirrors
    /// ScreenUnlockDetector.maxSessionDurationSeconds, the same "implausibly
    /// long unbroken session" safety net used for screen-time accounting.
    private static let plantSessionStaleCutoff: TimeInterval = 2 * 60 * 60

    /// Extrapolates health forward from a stored (baseline, time, isWilting)
    /// checkpoint. While a screen session is active (isWilting), health falls
    /// continuously; otherwise it grows continuously. Shared math so the
    /// DI/widget's own extrapolation stays identical to what the app computes.
    static func extrapolatedPlantHealth(baseline: Double, baselineTime: Date, isWilting: Bool, now: Date = Date()) -> Double {
        guard baselineTime != .distantPast else { return 0 }
        let elapsed = max(0, now.timeIntervalSince(baselineTime))
        if isWilting {
            guard elapsed < plantSessionStaleCutoff else {
                return min(100, (elapsed - plantSessionStaleCutoff) * plantGrowthRatePerSecond)
            }
            return max(0, baseline - elapsed * plantWiltRatePerSecond)
        }
        return min(100, baseline + elapsed * plantGrowthRatePerSecond)
    }

    private static func todayDateStringStatic() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Freezes whatever the checkpoint currently extrapolates to as the new
    /// baseline and flips the wilt/grow direction from `now`. Shared by
    /// begin/end below — both transitions are "checkpoint the live value, then
    /// start extrapolating the other way."
    private static func checkpointPlantHealth(isWilting: Bool, now: Date = Date()) {
        let suite = UserDefaults(suiteName: "group.fotiospongas.picksy") ?? .standard
        let checkpoint = plantHealthCheckpoint()
        let current = extrapolatedPlantHealth(
            baseline: checkpoint.baseline,
            baselineTime: checkpoint.time,
            isWilting: checkpoint.isWilting,
            now: now
        )
        suite.set(current, forKey: "picksy_plant_health")
        suite.set(now.timeIntervalSince1970, forKey: "picksy_plant_health_time")
        suite.set(todayDateStringStatic(), forKey: "picksy_plant_health_date")
        suite.set(isWilting, forKey: "picksy_plant_wilting")
    }

    /// Called on EVERY unlock (ScreenUnlockDetector.onScreenSessionStarted),
    /// before the pickup cooldown check — the instant the phone is picked up,
    /// the plant starts wilting in real time. Also bumps plantWiltTrigger so
    /// PlantHealthView fires its shake/flash right when the user picks up —
    /// the moment the nudge actually matters — rather than only after the fact.
    func beginPlantSession() {
        Self.checkpointPlantHealth(isWilting: true)
        plantWiltTrigger += 1
    }

    /// Called when the screen locks (ScreenUnlockDetector.onScreenSessionEnded)
    /// — freezes the now-wilted value and resumes growing from this moment.
    func endPlantSession() {
        Self.checkpointPlantHealth(isWilting: false)
    }

    /// Bumped by beginPlantSession() on every pickup. NudgeView's
    /// PlantHealthView observes this to trigger its wilt shake/flash animation.
    var plantWiltTrigger: Int = 0

    /// Reads the current plant-health checkpoint from the App Group, for
    /// LiveActivityManager to copy into ContentState. Read-only — does NOT
    /// write anything. Date-guarded the same way as every other "today" value.
    static func plantHealthCheckpoint() -> (baseline: Double, time: Date, isWilting: Bool) {
        let suite = UserDefaults(suiteName: "group.fotiospongas.picksy") ?? .standard
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        guard suite.string(forKey: "picksy_plant_health_date") == today else {
            return (0, .distantPast, false)
        }
        let timeRaw = suite.double(forKey: "picksy_plant_health_time")
        let time = timeRaw > 0 ? Date(timeIntervalSince1970: timeRaw) : .distantPast
        return (suite.double(forKey: "picksy_plant_health"), time, suite.bool(forKey: "picksy_plant_wilting"))
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
    #if DEBUG
    /// Fills the app with realistic demo data for App Store screenshots.
    /// Pair with DuelManager.injectDemoDuel() + a seeded friends list.
    func seedDemoData() {
        todayPickups      = 12
        totalPickups      = 487
        currentStreak     = 7
        totalDaysTracked  = 23
        todayTotalSeconds = 5400            // 1h 30m → Nudge/Stats screen time
        weeklyPickups     = [22, 18, 25, 14, 19, 9, 12]
        hourlyScreenTimeSecs = [0,0,0,0,0,0,300,900,1200,800,600,1500,2000,1100,700,900,1300,1800,2400,2100,1600,900,400,100]

        defaults.set(12, forKey: "todayPickups")
        defaults.set(5400, forKey: "picksy_apple_screen_time_secs")
        defaults.set(todayDateString(), forKey: "picksy_apple_screen_time_date")

        saveData()
        refreshConfirmedScreenTime()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Clears the demo data (back to empty) after screenshots.
    func clearDemoData() {
        todayPickups = 0; totalPickups = 0; currentStreak = 0; totalDaysTracked = 0
        todayTotalSeconds = 0
        weeklyPickups = Array(repeating: 0, count: 7)
        hourlyScreenTimeSecs = Array(repeating: 0, count: 24)

        defaults.set(0, forKey: "todayPickups")
        defaults.set(0, forKey: "picksy_apple_screen_time_secs")
        defaults.removeObject(forKey: "picksy_apple_screen_time_date")

        saveData()
        refreshConfirmedScreenTime()
        WidgetCenter.shared.reloadAllTimelines()
    }
    #endif

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

        // Reset Apple-confirmed screen time (+ the ladder-restart baseline)
        defaults.set(0, forKey: "picksy_apple_screen_time_secs")
        defaults.removeObject(forKey: "picksy_apple_screen_time_date")
        defaults.set(0, forKey: "picksy_apple_screen_time_baseline")
        defaults.removeObject(forKey: "picksy_apple_screen_time_baseline_date")

        // Reset report-confirmed screen time (Apps-tab total mirror)
        defaults.set(0, forKey: "picksy_report_screen_time_secs")
        defaults.removeObject(forKey: "picksy_report_screen_time_date")

        // Values are read live from the (now-zeroed) App Group; bump the tick
        // so any on-screen view re-publishes immediately.
        screenTimeRefreshTick &+= 1

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
        // File mirror for the SEALED ShieldConfiguration extension: its
        // UserDefaults reads come from a per-process prefs snapshot that can
        // serve a count that's hours stale (shield showed 19 while the app had
        // 25). File reads always hit disk. Format: "yyyy-MM-dd|count".
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.fotiospongas.picksy")?
            .appendingPathComponent("today_pickups.txt") {
            try? "\(todayDateString())|\(todayPickups)"
                .data(using: .utf8)?.write(to: url, options: .atomic)
        }
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
            // Do NOT remove today's per-day key here — the extension may have already
            // counted pickups since midnight. syncWithDeviceActivity() (called right
            // after checkNewDay) will read and apply the extension's count correctly.
            defaults.set(0, forKey: "todayPickups")
            // Reset Apple-confirmed screen time for the new day (+ ladder baseline).
            //
            // DATE-GUARDED: the DeviceActivityMonitor extension can ALSO reset these
            // same keys for the new day (it runs independently, often before the main
            // app is ever opened — e.g. the user uses their phone at 06:00 and the
            // extension records real screen time before checkNewDay() ever runs here).
            // Without this guard, opening the app for the first time that day would
            // unconditionally wipe screen time the extension had already correctly
            // recorded for today, and re-stamp picksy_ladder_reset_epoch — racing with
            // the extension's own stamp and visibly dropping the duel/Nudge score.
            // Only reset if today's date isn't already stamped (i.e. neither side has
            // reset for today yet).
            if defaults.string(forKey: "picksy_apple_screen_time_date") != today {
                defaults.set(0, forKey: "picksy_apple_screen_time_secs")
                defaults.removeObject(forKey: "picksy_apple_screen_time_date")
                defaults.set(0, forKey: "picksy_apple_screen_time_baseline")
                defaults.removeObject(forKey: "picksy_apple_screen_time_baseline_date")
                // Stamp the reset epoch so the DeviceActivity extension can reject stale
                // threshold callbacks that fire after this reset (delayed iOS delivery).
                defaults.set(Date().timeIntervalSince1970, forKey: "picksy_ladder_reset_epoch")
                // Reset report-confirmed total for the new day.
                defaults.set(0, forKey: "picksy_report_screen_time_secs")
                defaults.removeObject(forKey: "picksy_report_screen_time_date")
            }
            // Reset the file-based pickup count so ShieldConfiguration reads 0 even
            // when its process cache still holds yesterday's todayPickups value.
            let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.fotiospongas.picksy")
            if let pickupURL = container?.appendingPathComponent("today_pickups.txt") {
                try? "\(todayDateString())|0".data(using: .utf8)?.write(to: pickupURL, options: .atomic)
            }
            // Clear the file-based passcode lock (new day — time limit hasn't fired yet).
            if let lockURL = container?.appendingPathComponent("picksy_timelimit_lock.txt") {
                try? "".data(using: .utf8)?.write(to: lockURL, options: .atomic)
            }
            // Values are read live from the (now-zeroed) App Group; bump the
            // tick so any on-screen view re-publishes at midnight.
            screenTimeRefreshTick &+= 1
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

