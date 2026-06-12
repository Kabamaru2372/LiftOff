//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitor
//
//  Created by Fotios Pongas on 27.04.26.
//
//  Αυτό το extension τρέχει στο background και ειδοποιείται από το iOS
//  όταν συμβαίνει ένα event (π.χ. pickup threshold reached).
//  Καταγράφουμε τα events στο shared App Group ώστε το main app να τα διαβάζει.

import DeviceActivity
import Foundation
import WidgetKit
import UserNotifications
import ManagedSettings
import FamilyControls

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // MARK: - Shared Storage

    /// Το App Group που μοιράζεται data με το main app
    private static let appGroupID = "group.fotiospongas.picksy"

    /// Shared UserDefaults για data sharing με το main app
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    // MARK: - Supabase (για Live Activity APNs push)
    //
    // Το extension τρέχει σε separate process — δεν έχει πρόσβαση στο
    // PushNotificationManager του main app. Κάνουμε απευθείας HTTP call.

    private static let supabaseURL     = "https://igbtosqmtdrxzmoblvpp.supabase.co"
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"

    /// Cooldown (δευτερόλεπτα) μεταξύ event firings που μετρούν ως νέο pickup.
    /// Consecutive threshold crossings στο ίδιο session (π.χ. 1s→2s→3s) φυσούν
    /// μέσα σε ~1 δευτερόλεπτο — η cooldown τα φιλτράρει σε 1 pickup.
    private static let cooldownSeconds: TimeInterval = 30

    // MARK: - Interval Lifecycle

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log("📅 Interval started for: \(activity.rawValue)")

        // One-shot re-shield, scheduled by the ShieldAction extension after a
        // category shield was lifted (tap-through on a category-shielded app).
        // The config extension is sealed (can't tell us WHICH app was opened),
        // so the whole category unshields — this guarantees it re-locks within
        // ~15 min even if Picksy's process is dead and the screen never locks.
        if activity.rawValue == "picksy.reshield" {
            reapplyCategoryShields()
            DeviceActivityCenter().stopMonitoring([activity])
            return
        }

        // New day: clear the duel meta cache so the first pickup fetches fresh
        // active duels from Supabase (catches overnight duel invitations).
        if activity.rawValue == "daily" {
            sharedDefaults?.removeObject(forKey: "picksy_active_duel_meta")
            sharedDefaults?.set(0.0, forKey: "picksy_duel_meta_last_fetch")
            log("⚔️ Duel meta cache cleared for new day")

            // Reset the confirmed screen-time accumulator for the new day. This is
            // "only-increasing" within a day, so it MUST be zeroed at midnight —
            // otherwise yesterday's (higher) total persists when the app isn't
            // opened across midnight, and today's lower real total gets ignored by
            // the max(), making the duel/score show a stale, inflated value.
            // Previously only the main app reset this (checkNewDay), which fails if
            // the app stays closed across the day boundary.
            sharedDefaults?.set(0, forKey: "picksy_apple_screen_time_secs")
            sharedDefaults?.set(0, forKey: "picksy_report_screen_time_secs")
            sharedDefaults?.removeObject(forKey: "picksy_report_screen_time_date")
            log("📊 Screen-time accumulator reset for new day")

            // New day → lift yesterday's time-limit shield + clear its flag.
            let tlStore = ManagedSettingsStore(named: .init("picksy.timeLimit"))
            tlStore.shield.applications = nil
            tlStore.shield.applicationCategories = nil
            sharedDefaults?.removeObject(forKey: "picksy_timelimit_active")

            // Tell the main app (if alive) to re-read the now-zeroed values.
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("dev.fotiospongas.picksy.screenTimeUpdated" as CFString),
                nil, nil, true
            )
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log("📅 Interval ended for: \(activity.rawValue)")

        // Reset daily counter at end of day interval
        if activity.rawValue == "daily" {
            resetDailyCounter()
        }
    }

    // MARK: - Event Handling

    /// Καλείται όταν ένα event φτάνει το threshold.
    ///
    /// Δύο είδη events φτάνουν εδώ:
    ///   • "app_<i>_t<n>"            → pickup detection (PickupScheduler)   → +1 σήκωμα
    ///   • "picksy.threshold.levelN" → ΧΡΗΣΗ 1h/2h/3h (UsageThresholdManager)
    ///                                  → ΑΚΡΙΒΗΣ screen-time ειδοποίηση (Apple data,
    ///                                    background). ΔΕΝ είναι σήκωμα.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        log("🎯 Event threshold reached: \(event.rawValue)")

        // Daily time-limit reached → apply the "time's up" shield to the tracked
        // apps and flag it, so the ShieldConfiguration extension shows the limit
        // message. Cleared at midnight (intervalDidStart "daily").
        if event.rawValue == "picksy.timelimit" {
            applyTimeLimitShield()
            return
        }

        // Cumulative usage thresholds (picksy.threshold.levelN) are NO LONGER used
        // for notifications — screen-time alerts moved to a true CONTINUOUS-use model
        // (scheduled in-app on unlock, cancelled on lock; see ScreenTimeMilestoneNotifier
        // + LiftOffApp). This cumulative daily threshold would fire when the *total*
        // day's usage crossed 1h/2h/3h, which is NOT what the user wants.
        // BUT: we still record the confirmed Apple screen time so the Nudge/Stats
        // screen can show an accurate value even when the main app was suspended.
        if event.rawValue.hasPrefix("picksy.threshold.level") {
            recordAppleConfirmedScreenTime(for: event.rawValue)
            log("ℹ️ Usage threshold \(event.rawValue) — recorded confirmed time only (no notification; continuous-use model)")
            return
        }

        // Hourly confirmed-time ladder (picksy.usagehour.N → N hours). These fire
        // as cumulative usage of the selected apps crosses each hour mark, so the
        // in-app Picksy Score can reflect heavy usage beyond the 3h notification
        // cap. They do NOT post notifications — they only record confirmed time.
        // Fine-grained confirmed-time ladder (picksy.usagemin.N → N minutes).
        if event.rawValue.hasPrefix("picksy.usagemin.") {
            let suffix = event.rawValue.dropFirst("picksy.usagemin.".count)
            if let mins = Int(suffix), mins > 0 {
                recordConfirmedSeconds(mins * 60, source: event.rawValue)
            }
            return
        }

        // Legacy hourly ladder (kept for any monitoring still registered from a
        // previous install until it restarts).
        if event.rawValue.hasPrefix("picksy.usagehour.") {
            let suffix = event.rawValue.dropFirst("picksy.usagehour.".count)
            if let hours = Int(suffix), hours > 0 {
                recordConfirmedSeconds(hours * 3600, source: event.rawValue)
            }
            return
        }

        // Otherwise it's a pickup detection event.
        incrementPickupCounter()
    }

    // MARK: - Screen-time milestone (accurate, background)

    /// Delivers the screen-time milestone notification using the smart message the
    /// main app pre-computed in the App Group (weather/time-aware, localized).
    /// Fires at most once per level per calendar day.
    private func fireScreenTimeMilestone(level: Int) {
        guard level >= 1, level <= 3, let defaults = sharedDefaults else { return }

        // ── Per-day dedup ──────────────────────────────────────────────────────
        let firedKey = "picksy_milestone_fired_\(milestoneTodayKey())"
        var firedToday = defaults.array(forKey: firedKey) as? [Int] ?? []
        guard !firedToday.contains(level) else {
            log("⏭️ Screen-time milestone L\(level) already fired today")
            return
        }
        firedToday.append(level)
        defaults.set(firedToday, forKey: firedKey)

        // ── Read pre-computed message (fallback to a generic line) ─────────────
        let p = "picksy_milestone_\(level)_"
        let language = defaults.string(forKey: "picksy.appLanguage") ?? "English"
        let minutes  = defaults.integer(forKey: p + "minutes")
        let title = defaults.string(forKey: p + "title") ?? fallbackTitle(minutes: minutes, language: language)
        let body  = defaults.string(forKey: p + "body")  ?? ""

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        content.categoryIdentifier = "PICKSY_SCREEN_TIME_MILESTONE"

        // userInfo so tapping opens MilestoneDetailView (same shape as the app path).
        var info: [AnyHashable: Any] = ["milestoneMinutes": minutes]
        if let en = defaults.string(forKey: p + "bodyEN") { info["milestoneBodyEN"] = en }
        if let gr = defaults.string(forKey: p + "bodyGR") { info["milestoneBodyGR"] = gr }
        if let de = defaults.string(forKey: p + "bodyDE") { info["milestoneBodyDE"] = de }
        if let link = defaults.string(forKey: p + "link") { info["milestoneLink"] = link }
        content.userInfo = info

        let request = UNNotificationRequest(
            identifier: "picksy.milestone.\(level).\(milestoneTodayKey())",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request) { [weak self] err in
            if let err { self?.log("❌ Milestone L\(level) notify failed: \(err.localizedDescription)") }
            else       { self?.log("🔔 Screen-time milestone L\(level) fired (\(minutes)min, accurate)") }
        }
    }

    private func fallbackTitle(minutes: Int, language: String) -> String {
        let hours = minutes / 60
        switch language {
        case "Ελληνικά":
            return hours > 0 ? "\(hours) \(hours == 1 ? "ώρα" : "ώρες") στις apps σου 📱" : "\(minutes) λεπτά στις apps σου 📱"
        case "Deutsch":
            return hours > 0 ? "\(hours) \(hours == 1 ? "Stunde" : "Stunden") in deinen Apps 📱" : "\(minutes) Minuten in deinen Apps 📱"
        default:
            return hours == 1 ? "1 hour on your apps today 📱" : hours > 1 ? "\(hours) hours on your apps today 📱" : "\(minutes) min on your apps today 📱"
        }
    }

    private func milestoneTodayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Warnings (optional, για future use)

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }

    // MARK: - Helpers

    /// Αυξάνει τον pickup counter στο shared storage.
    ///
    /// Fix #1: Χρησιμοποιεί το ίδιο cooldown key ("picksy_last_pickup_timestamp")
    /// με τον ScreenUnlockDetector — ένα κοινό cooldown για όλα τα systems,
    /// αποφεύγοντας διπλοκαταμέτρηση (unlock + app open = 1 pickup).
    private func incrementPickupCounter() {
        guard let defaults = sharedDefaults else {
            log("❌ Cannot access shared defaults")
            return
        }

        // ── Cooldown check (shared key με ScreenUnlockDetector — fix #1) ────────
        let sharedCooldownKey = "picksy_last_pickup_timestamp"
        let lastEventTime = defaults.double(forKey: sharedCooldownKey)
        let now = Date().timeIntervalSince1970
        let timeSinceLast = now - lastEventTime

        guard timeSinceLast > Self.cooldownSeconds || lastEventTime == 0 else {
            log("⏭️ Skipped (shared cooldown): \(Int(timeSinceLast))s since last event")
            return
        }

        // Ενημερώνουμε το shared timestamp ΜΟΝΟ αν μετράμε
        defaults.set(now, forKey: sharedCooldownKey)

        // ── Increment counter ──────────────────────────────────────────────────
        let today = todayKey()
        let currentCount = defaults.integer(forKey: today)
        let newCount = currentCount + 1
        defaults.set(newCount, forKey: today)
        defaults.set(now, forKey: "lastPickupTimestamp")

        // ── Widget direct update (fix #7) ──────────────────────────────────────
        // Γράφουμε πάντα αν newCount > currentWidgetCount (γνωστή συμπεριφορά).
        // Αν το DataStore έχει μεγαλύτερη τιμή (από ScreenUnlock pickups),
        // δεν κάνουμε override — το DataStore είναι ο authoritative source.
        let currentWidgetCount = defaults.integer(forKey: "todayPickups")
        if newCount > currentWidgetCount {
            defaults.set(newCount, forKey: "todayPickups")
        }
        // File mirror — keeps the sealed ShieldConfiguration's count fresh
        // (its defaults reads can be a stale per-process snapshot).
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)?
            .appendingPathComponent("today_pickups.txt") {
            try? "\(milestoneTodayKey())|\(max(newCount, currentWidgetCount))"
                .data(using: .utf8)?.write(to: url, options: .atomic)
        }
        // Πάντα reload το widget — ακόμα και αν η τιμή δεν άλλαξε,
        // το DataStore μπορεί να έχει γράψει νέο count που χρειάζεται refresh (fix #7)
        WidgetCenter.shared.reloadAllTimelines()
        log("📱 Widget reload triggered. todayPickups: \(max(newCount, currentWidgetCount))")

        log("✅ Pickup recorded. Today's total: \(newCount) (last event: \(Int(timeSinceLast))s ago)")

        // Notify main app via Darwin notification (αν τρέχει)
        notifyMainApp()

        let finalCount = max(newCount, currentWidgetCount)

        // ── Duel score sync (background — no app open needed) ─────────────────
        // Patches our pickup count directly to Supabase so the opponent sees
        // live scores even if we never open the app during the day.
        syncPickupsToDuel(pickupCount: finalCount)

        // ── Live Activity APNs push (fix #5: includes duel state) ─────────────
        pushLiveActivityUpdate(pickupCount: finalCount)
    }

    /// Patches our pickup count to every active duel in Supabase so opponents
    /// see live scores even when this device never opens the main app.
    ///
    /// Fast path: uses cached meta written by LiftOffApp.syncDuelStateToAppGroup().
    /// Slow path: queries Supabase directly (≤ once per 10 min) for when the app
    ///            was never opened for today's duel (e.g. new duel started while
    ///            user has not opened Picksy yet today).
    private static let duelCacheMaxAge: TimeInterval = 10 * 60   // 10 minutes

    private func syncPickupsToDuel(pickupCount: Int) {
        guard let defaults = sharedDefaults else { return }
        let deviceID = defaults.string(forKey: "picksy_device_id") ?? ""
        guard !deviceID.isEmpty else {
            log("⚠️ No device ID — skipping duel sync")
            return
        }

        // ── Day-boundary cache invalidation ───────────────────────────────────
        // If the app was never opened today, the cached meta may still hold
        // yesterday's (completed) duel IDs. Clear it so the slow path runs fresh
        // and discovers today's active duels from Supabase.
        let todayStr: String = {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
        }()
        let cachedDate = defaults.string(forKey: "picksy_duel_meta_cache_date") ?? ""
        if cachedDate != todayStr {
            defaults.removeObject(forKey: "picksy_active_duel_meta")
            defaults.set(0.0, forKey: "picksy_duel_meta_last_fetch")
            log("⚔️ Duel meta stale (cached: \(cachedDate), today: \(todayStr)) — invalidated")
        }

        // ── Fast path: cached meta from main app ──────────────────────────────
        if let metaData = defaults.data(forKey: "picksy_active_duel_meta"),
           let meta = try? JSONSerialization.jsonObject(with: metaData) as? [[String: String]],
           !meta.isEmpty {
            log("⚔️ Duel sync (cached): \(meta.count) duel(s)")
            patchDuels(meta: meta, pickupCount: pickupCount)
            return
        }

        // ── Slow path: rate-limited Supabase fetch ─────────────────────────────
        // Only query when we have no cached meta — covers the case where the
        // friend has a duel but hasn't opened the app yet today.
        let lastFetch = defaults.double(forKey: "picksy_duel_meta_last_fetch")
        let now = Date().timeIntervalSince1970
        guard now - lastFetch > Self.duelCacheMaxAge else {
            log("⏭️ Duel meta fetch skipped (\(Int(now - lastFetch))s ago — max \(Int(Self.duelCacheMaxAge))s)")
            return
        }
        defaults.set(now, forKey: "picksy_duel_meta_last_fetch")
        log("⚔️ Duel sync: querying Supabase for active duels (no cached meta)…")
        fetchActiveDuelsAndPatch(deviceID: deviceID, pickupCount: pickupCount, defaults: defaults)
    }

    /// Apply cached duel meta: PATCH each duel with the new pickup count.
    private func patchDuels(meta: [[String: String]], pickupCount: Int) {
        for duelInfo in meta {
            guard let duelID = duelInfo["id"] else { continue }
            let amChallenger = duelInfo["challenger"] == "1"
            patchDuel(id: duelID, amChallenger: amChallenger, pickupCount: pickupCount)
        }
    }

    /// Slow path: query Supabase for active duels, cache the result, then PATCH each one.
    private func fetchActiveDuelsAndPatch(deviceID: String, pickupCount: Int, defaults: UserDefaults) {
        guard var comps = URLComponents(string: "\(Self.supabaseURL)/rest/v1/duels") else { return }
        comps.queryItems = [
            URLQueryItem(name: "or",     value: "(challenger_id.eq.\(deviceID),opponent_id.eq.\(deviceID))"),
            URLQueryItem(name: "status", value: "eq.active"),
            URLQueryItem(name: "limit",  value: "5")
        ]
        guard let url = comps.url else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            guard let data,
                  let duels = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else {
                self.log("⚠️ Active duel fetch failed: \(error?.localizedDescription ?? "no data")")
                return
            }

            self.log("⚔️ Supabase returned \(duels.count) active duel(s)")
            guard !duels.isEmpty else { return }

            // Build meta array, cache it, and patch each duel
            var meta: [[String: String]] = []
            for duel in duels {
                guard let id = duel["id"] as? String,
                      let challengerID = duel["challenger_id"] as? String else { continue }
                let amChallenger = challengerID == deviceID
                meta.append(["id": id, "challenger": amChallenger ? "1" : "0"])
                self.patchDuel(id: id, amChallenger: amChallenger, pickupCount: pickupCount)
            }

            // Cache for fast path on next pickup — stamp with today's date
            // so the day-boundary check knows this meta is fresh.
            if let json = try? JSONSerialization.data(withJSONObject: meta) {
                let today: String = {
                    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
                }()
                defaults.set(json,  forKey: "picksy_active_duel_meta")
                defaults.set(today, forKey: "picksy_duel_meta_cache_date")
                self.log("⚔️ Cached \(meta.count) active duel(s) to App Group (date: \(today))")
            }
        }.resume()
    }

    /// PATCH a single duel record with the new pickup count.
    private func patchDuel(id: String, amChallenger: Bool, pickupCount: Int) {
        let field = amChallenger ? "challenger_pickups" : "opponent_pickups"
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/duels?id=eq.\(id)") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10
        req.httpBody = try? JSONSerialization.data(withJSONObject: [field: pickupCount])

        URLSession.shared.dataTask(with: req) { [weak self] _, response, error in
            if let http = response as? HTTPURLResponse {
                self?.log("⚔️ Duel PATCH → HTTP \(http.statusCode) (\(field): \(pickupCount))")
            } else if let error = error {
                self?.log("⚠️ Duel PATCH failed: \(error.localizedDescription)")
            }
        }.resume()
    }

    /// Στέλνει APNs push για το Live Activity μέσω Supabase edge function.
    /// Fix #5: Διαβάζει duel state από App Group ώστε να μην σβήνει το ⚔️ από το DI.
    private func pushLiveActivityUpdate(pickupCount: Int) {
        guard let defaults = sharedDefaults else { return }

        let deviceID = defaults.string(forKey: "picksy_device_id") ?? ""
        guard !deviceID.isEmpty else {
            log("⚠️ No device ID — skipping APNs push (will work after next app launch)")
            return
        }

        guard let url = URL(string: "\(Self.supabaseURL)/functions/v1/update-live-activity") else { return }

        // Fix #5: Read duel state written by LiftOffApp.syncDuelStateToAppGroup()
        let isDuelActive  = defaults.bool(forKey: "picksy_duel_active")
        let opponentName  = defaults.string(forKey: "picksy_duel_opponent") ?? ""
        let theirPickups  = defaults.integer(forKey: "picksy_duel_their_pickups")

        var body: [String: Any] = [
            "device_id":    deviceID,
            "pickup_count": pickupCount
        ]
        if isDuelActive {
            body["duel_opponent_name"] = opponentName
            body["duel_my_pickups"]    = pickupCount
            body["duel_their_pickups"] = theirPickups
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let http = response as? HTTPURLResponse {
                self?.log("🎯 APNs push → \(http.statusCode) (pickups: \(pickupCount), duel: \(isDuelActive))")
            } else if let error = error {
                self?.log("⚠️ APNs push failed: \(error.localizedDescription)")
            }
        }.resume()
    }

    /// Fix #6: Δεν κάνει reset τον per-day counter — κάθε μέρα έχει unique key.
    /// Μόνο το shared cooldown timestamp resetάρεται ώστε το νέο 24ωρο να ξεκινά clean.
    private func resetDailyCounter() {
        guard let defaults = sharedDefaults else { return }
        defaults.set(0, forKey: "picksy_last_pickup_timestamp")  // shared cooldown
        // Δεν αγγίζουμε "todayPickups" — DataStore το κάνει reset στις 00:00
        log("🔄 Daily cooldown reset (new day key will be: \(todayKey()))")
    }

    /// Generate key για σήμερα (yyyy-MM-dd format)
    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "picksy_pickups_\(formatter.string(from: Date()))"
    }

    /// Στέλνει Darwin notification στο main app
    private func notifyMainApp() {
        let name = CFNotificationName("dev.fotiospongas.picksy.pickupRecorded" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            name,
            nil,
            nil,
            true
        )
    }

    /// Records the Apple-confirmed minimum screen time to the App Group so the
    /// Nudge screen can show an accurate value even when Picksy was suspended.
    ///
    /// Apple fires these threshold events from its own background process,
    /// so they are accurate regardless of whether Picksy is alive in memory.
    ///
    /// ThresholdPreset is in the main app target so we read the preset name
    /// from the shared App Group and map it to seconds inline.
    private func recordAppleConfirmedScreenTime(for eventName: String) {
        guard let defaults = sharedDefaults else { return }

        // Read preset name that the main app saved to the shared group.
        // Falls back to "light" (1h/2h/3h) if not found.
        let presetRaw = defaults.string(forKey: "picksyThresholdPreset_shared") ?? "light"

        // (hour, minute) tuples for (level1, level2, level3) per preset.
        // Must stay in sync with ThresholdPreset in UsageThresholdManager.swift.
        let thresholds: [(h: Int, m: Int)]
        switch presetRaw {
        case "moderate": thresholds = [(0, 45), (1, 30), (2, 0)]
        case "strict":   thresholds = [(0, 30), (1,  0), (1, 30)]
        default:         thresholds = [(1,  0), (2,  0), (3,  0)] // light
        }

        let levelIndex: Int
        switch eventName {
        case "picksy.threshold.level1": levelIndex = 0
        case "picksy.threshold.level2": levelIndex = 1
        case "picksy.threshold.level3": levelIndex = 2
        default: return
        }

        let t = thresholds[levelIndex]
        let confirmedSecs = t.h * 3600 + t.m * 60
        recordConfirmedSeconds(confirmedSecs, source: "\(eventName) preset:\(presetRaw)")
    }

    /// Writes an Apple-confirmed screen-time lower bound to the App Group,
    /// only ever increasing it WITHIN THE SAME DAY, and pokes the main app to
    /// refresh. Used by both the notification thresholds and the hourly score ladder.
    ///
    /// Date-stamped: the value is "only-increasing", so without a day guard a
    /// yesterday total persists when the app isn't opened across midnight, and
    /// today's lower real total gets ignored by the max() — making the duel/score
    /// show a stale, inflated value (e.g. 9h45 from yesterday vs 7h57 real today).
    /// On the first write of a new day we treat the baseline as 0 and re-stamp.
    private func recordConfirmedSeconds(_ secs: Int, source: String) {
        guard secs > 0, let defaults = sharedDefaults else { return }

        let today = milestoneTodayKey()   // "yyyy-MM-dd"
        let storedDate = defaults.string(forKey: "picksy_apple_screen_time_date")
        // New day → baseline is 0 (ignore yesterday's stored value).
        let current = (storedDate == today) ? defaults.integer(forKey: "picksy_apple_screen_time_secs") : 0
        guard secs > current else { return }

        defaults.set(secs, forKey: "picksy_apple_screen_time_secs")
        defaults.set(today, forKey: "picksy_apple_screen_time_date")
        log("📊 Apple screen time confirmed: ≥\(secs / 60)min (\(source))")

        // ── Duel screen-time sync (background — no app open needed) ────────────
        // Screen time is the duel metric. Pushing it here, from Apple's background
        // process, keeps the opponent's view of our screen time accurate even when
        // the main app is suspended — the whole reason the duel uses screen time.
        syncScreenTimeToDuel(secs: secs)

        // Tell the main app to re-read so the Nudge/Stats score refreshes live.
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("dev.fotiospongas.picksy.screenTimeUpdated" as CFString),
            nil, nil, true
        )
    }

    /// Patches our SCREEN TIME (seconds) to every active duel in Supabase so the
    /// opponent sees live, accurate screen time even when this device never opens
    /// the main app. Uses the cached duel meta written by the pickup path /
    /// LiftOffApp; if no meta is cached yet, skips (the pickup path populates it).
    private func syncScreenTimeToDuel(secs: Int) {
        guard secs > 0, let defaults = sharedDefaults else { return }
        let deviceID = defaults.string(forKey: "picksy_device_id") ?? ""
        guard !deviceID.isEmpty else { return }

        guard let metaData = defaults.data(forKey: "picksy_active_duel_meta"),
              let meta = try? JSONSerialization.jsonObject(with: metaData) as? [[String: String]],
              !meta.isEmpty else {
            log("⏭️ Screen-time duel sync skipped (no cached duel meta yet)")
            return
        }

        for duelInfo in meta {
            guard let duelID = duelInfo["id"] else { continue }
            let amChallenger = duelInfo["challenger"] == "1"
            let field = amChallenger ? "challenger_screen_time" : "opponent_screen_time"
            patchDuelField(id: duelID, field: field, value: secs)
        }
    }

    /// Generic single-field PATCH on a duel row (used for screen-time sync).
    private func patchDuelField(id: String, field: String, value: Int) {
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/duels?id=eq.\(id)") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10
        req.httpBody = try? JSONSerialization.data(withJSONObject: [field: value])

        URLSession.shared.dataTask(with: req) { [weak self] _, response, error in
            if let http = response as? HTTPURLResponse {
                self?.log("⚔️ Duel screen-time PATCH → HTTP \(http.statusCode) (\(field): \(value)s)")
            } else if let error = error {
                self?.log("⚠️ Duel screen-time PATCH failed: \(error.localizedDescription)")
            }
        }.resume()
    }

    /// Applies the daily time-limit shield to the tracked apps and flags it (date-
    /// stamped) so the ShieldConfiguration extension shows the "time's up" message.
    /// Reads the selection from the App Group (written by AppSelectionStore).
    private func applyTimeLimitShield() {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "picksyAppSelection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            log("⚠️ Time limit reached but no selection to shield")
            return
        }
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        // BUGFIX: previously only shielded `applications` and bailed if empty, so a
        // CATEGORY-only selection (e.g. "Social") never locked. Shield both.
        guard !apps.isEmpty || !categories.isEmpty else {
            log("⚠️ Time limit reached but selection has no apps or categories")
            return
        }

        let store = ManagedSettingsStore(named: .init("picksy.timeLimit"))
        // Per-app first (category ticks arrive pre-expanded into app tokens);
        // category policy only for legacy category-only selections.
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories =
            (apps.isEmpty && !categories.isEmpty) ? .specific(categories) : nil
        defaults.set(milestoneTodayKey(), forKey: "picksy_timelimit_active")
        log("⏳ Daily time limit reached — shielded \(apps.count) app(s), \(categories.count) categor(y/ies)")
    }

    /// Re-applies the Accurate Mode + (if active today) time-limit shields from
    /// the saved selection. Fired by the one-shot "picksy.reshield" activity the
    /// ShieldAction extension schedules after lifting a category shield — closes
    /// the window where the whole category stays unshielded because we can't
    /// know which single app the user tapped through.
    private func reapplyCategoryShields() {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "picksyAppSelection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            log("⚠️ Re-shield fired but no selection found")
            return
        }
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens

        // Same policy as ShieldManager: per-app first, category policy only for
        // legacy category-only selections (no expanded app tokens).
        let categoryPolicy: ShieldSettings.ActivityCategoryPolicy<Application>? =
            (apps.isEmpty && !categories.isEmpty) ? .specific(categories) : nil

        if defaults.bool(forKey: "picksy_accurate_mode") {
            let store = ManagedSettingsStore(named: .init("picksy.accurateMode"))
            store.shield.applications = apps.isEmpty ? nil : apps
            store.shield.applicationCategories = categoryPolicy
            log("🛡 Re-shielded Accurate Mode (\(apps.count) apps, \(categories.count) categories)")
        }
        if defaults.string(forKey: "picksy_timelimit_active") == milestoneTodayKey() {
            let tlStore = ManagedSettingsStore(named: .init("picksy.timeLimit"))
            tlStore.shield.applications = apps.isEmpty ? nil : apps
            tlStore.shield.applicationCategories = categoryPolicy
            log("⏳ Re-shielded time-limit (limit already reached today)")
        }
    }

    /// Logging με prefix για ευκολία debugging
    private func log(_ message: String) {
        print("[PicksyDeviceActivity] \(message)")
    }
}

