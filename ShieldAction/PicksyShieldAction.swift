//
//  PicksyShieldAction.swift
//  PicksyShieldAction
//
//  Handles taps on the Picksy shield (Accurate Mode). When the user taps the
//  primary button ("Open") we count a real pickup — reliably, even with the main
//  app suspended — then dismiss the shield so the app opens. The secondary button
//  ("Not now") keeps the app closed (a "save").
//
//  Counting writes directly to the App Group, sharing the SAME cooldown key as
//  ScreenUnlockDetector + DeviceActivityMonitor so an unlock immediately followed
//  by opening a shielded app is not double-counted.
//

import ManagedSettings
import FamilyControls
import DeviceActivity
import Foundation
import WidgetKit

class ShieldActionHandler: ShieldActionDelegate {

    private let appGroupID = "group.fotiospongas.picksy"

    /// Same named store the main app uses, so we can lift a shield from here.
    private let store = ManagedSettingsStore(named: .init("picksy.accurateMode"))

    // MARK: - Application

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Passcode-locked (time limit + passcode required) → NO bypass. The
            // user must open Picksy and enter the code to get another session.
            if isPasscodeLocked() {
                completionHandler(.close)
                return
            }
            // Count the pickup, then LIFT the shield for THIS app so it actually
            // opens (.none alone does not launch a still-shielded app). The shield
            // is re-applied next time Picksy comes to the foreground.
            countPickup()
            writeShieldDebug("app handler → lift")
            liftShield(for: application)
            completionHandler(.none)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    /// True when today's time limit is reached AND a passcode is required.
    /// Primary check is file-based: the ShieldAction extension process can run for
    /// hours with a stale UserDefaults cache (same issue as the pickup count display
    /// bug fixed with today_pickups.txt). The lock file is written by the main app
    /// and DeviceActivityMonitor at the moment conditions become true; it is cleared
    /// at midnight and when the user unlocks via the in-app passcode screen.
    private func isPasscodeLocked() -> Bool {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("picksy_timelimit_lock.txt"),
           let raw = try? String(contentsOf: url, encoding: .utf8),
           raw.trimmingCharacters(in: .whitespacesAndNewlines) == today {
            return true
        }
        // Fallback: UserDefaults (may be stale in long-running extension process)
        guard let d = UserDefaults(suiteName: appGroupID) else { return false }
        let limitActiveToday = d.string(forKey: "picksy_timelimit_active") == today
        let passwordRequired = d.bool(forKey: "picksy_timelimit_password_required")
        return limitActiveToday && passwordRequired
    }

    // MARK: - Category

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Same passcode gate as the application handler: when the time limit
            // is reached and a passcode is required, there is NO tap-through.
            if isPasscodeLocked() {
                completionHandler(.close)
                return
            }
            countPickup()
            // iOS doesn't pass the app token here — but the ShieldConfiguration
            // extension recorded which app's shield was just displayed. Use it to
            // except ONLY that app (everything else stays shielded); fall back to
            // lifting the whole category if the handoff is missing/stale.
            if let token = lastShieldedToken() {
                writeShieldDebug("cat → except (token ok)")
                liftShield(for: token)
            } else {
                writeShieldDebug("cat → fallback (no token)")
                liftCategoryShield()
            }
            completionHandler(.none)
        default:
            completionHandler(.close)
        }
    }

    // MARK: - Web domain

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            countPickup()
            completionHandler(.none)
        default:
            completionHandler(.close)
        }
    }

    /// Lets the just-opened app launch by rebuilding the FULL shielded set from the
    /// saved selection, minus this one app. Rebuilding (instead of only removing)
    /// means any app whose shield was previously lifted snaps back to shielded the
    /// moment the user hits any shield again — so the user doesn't have to reopen
    /// Picksy for earlier apps to re-lock. (iOS can't wake us exactly on screen
    /// lock, so this + the foreground/background re-shield is the best coverage.)
    private func liftShield(for token: ApplicationToken) {
        // Accurate-mode store: rebuild full set minus this app (re-shields others)
        // only if Accurate Mode is on; otherwise make sure it isn't shielding it.
        let accurateOn = UserDefaults(suiteName: appGroupID)?.bool(forKey: "picksy_accurate_mode") ?? false
        if accurateOn {
            var shielded = selectedAppTokens()
            shielded.remove(token)
            store.shield.applications = shielded.isEmpty ? nil : shielded
        } else if var s = store.shield.applications {
            s.remove(token)
            store.shield.applications = s.isEmpty ? nil : s
        }

        // Category policy (user selected e.g. "Social" instead of single apps):
        // keep the category shield but except THIS app so it actually opens.
        // Rebuilding the except-set fresh each time re-shields any previously
        // excepted app — same semantics as the per-app rebuild above.
        if store.shield.applicationCategories != nil {
            let cats = selectedCategoryTokens()
            store.shield.applicationCategories = cats.isEmpty
                ? nil : .specific(cats, except: [token])
        }

        // Time-limit store: free this app so it opens (re-applied at next limit/midnight).
        let tlStore = ManagedSettingsStore(named: .init("picksy.timeLimit"))
        if var s = tlStore.shield.applications {
            s.remove(token)
            tlStore.shield.applications = s.isEmpty ? nil : s
        }
        if tlStore.shield.applicationCategories != nil {
            let cats = selectedCategoryTokens()
            tlStore.shield.applicationCategories = cats.isEmpty
                ? nil : .specific(cats, except: [token])
        }
    }

    /// Fallback when iOS reports a tap via the CATEGORY handler (no app token
    /// available, so no except is possible): lift the category policy entirely so
    /// the tapped app opens. ShieldManager.refresh() re-applies it on Picksy's
    /// next foreground / device lock — the same re-shield net the app path uses.
    private func liftCategoryShield() {
        if store.shield.applicationCategories != nil {
            store.shield.applicationCategories = nil
        }
        let tlStore = ManagedSettingsStore(named: .init("picksy.timeLimit"))
        if tlStore.shield.applicationCategories != nil {
            tlStore.shield.applicationCategories = nil
        }
        scheduleCategoryReshield()
    }

    /// Schedules a one-shot DeviceActivity (~15 min out) whose intervalDidStart
    /// makes the monitor extension re-apply the category shields. Guarantees the
    /// lifted category re-locks even if Picksy's process is dead and the screen
    /// is never locked in between. Best-effort: if starting monitoring is not
    /// permitted from this extension, the lock/foreground re-shield nets remain.
    private func scheduleCategoryReshield() {
        let start = Date().addingTimeInterval(15 * 60)
        let end   = start.addingTimeInterval(30 * 60)   // ≥15 min interval required
        let cal = Calendar.current
        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(comps, from: start),
            intervalEnd:   cal.dateComponents(comps, from: end),
            repeats: false
        )
        do {
            try DeviceActivityCenter().startMonitoring(
                DeviceActivityName("picksy.reshield"),
                during: schedule
            )
        } catch {
            // Lock/foreground nets still cover re-shielding.
        }
    }

    /// The user's selected app tokens, decoded from the App Group (written by
    /// AppSelectionStore). Falls back to whatever is currently shielded.
    private func selectedAppTokens() -> Set<ApplicationToken> {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: "picksyAppSelection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return store.shield.applications ?? []
        }
        return selection.applicationTokens
    }

    /// The user's selected category tokens, decoded from the App Group.
    private func selectedCategoryTokens() -> Set<ActivityCategoryToken> {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: "picksyAppSelection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return [] }
        return selection.categoryTokens
    }

    /// Token of the app whose shield was most recently DISPLAYED, written by the
    /// ShieldConfiguration extension. Freshness-gated: the shield renders moments
    /// before any button press, so a stale value means the handoff didn't happen.
    /// Tries the App Group FILE first (survives sandboxes that drop the config
    /// extension's UserDefaults writes), then falls back to UserDefaults.
    private func lastShieldedToken() -> ApplicationToken? {
        // 1) File handoff — freshness via modification date
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("last_shield_token.json"),
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let mod = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(mod) < 120,
           let data = try? Data(contentsOf: url),
           let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) {
            return token
        }
        // 2) UserDefaults handoff
        if let d = UserDefaults(suiteName: appGroupID),
           let data = d.data(forKey: "picksy_last_shield_token") {
            let ts = d.double(forKey: "picksy_last_shield_token_ts")
            if ts > 0, Date().timeIntervalSince1970 - ts < 120 {
                return try? JSONDecoder().decode(ApplicationToken.self, from: data)
            }
        }
        return nil
    }

    /// DEV breadcrumb shown in Settings → DEV ONLY (this extension's defaults
    /// writes are proven to work — countPickup uses the same mechanism).
    private func writeShieldDebug(_ info: String) {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        UserDefaults(suiteName: appGroupID)?
            .set("\(f.string(from: Date())) \(info)", forKey: "picksy_shield_debug")
    }

    // MARK: - Counting (App Group, shared cooldown)

    /// Cooldown between counted pickups (seconds). Dedups an unlock + the shielded
    /// app-open that follows ~1-2s later into a single pickup.
    private let cooldownSeconds: TimeInterval = 6

    private func countPickup() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        let sharedCooldownKey = "picksy_last_pickup_timestamp"
        let now = Date().timeIntervalSince1970
        let last = defaults.double(forKey: sharedCooldownKey)
        guard last == 0 || now - last > cooldownSeconds else {
            // Too soon after the last counted pickup → same physical pickup.
            return
        }
        defaults.set(now, forKey: sharedCooldownKey)

        // Per-day key (yyyy-MM-dd) — mirrors DeviceActivityMonitor's scheme.
        let today = dayKey()
        let dayCount = defaults.integer(forKey: today) + 1
        defaults.set(dayCount, forKey: today)

        // Authoritative widget/app counter — only increase.
        let current = defaults.integer(forKey: "todayPickups")
        if dayCount > current {
            defaults.set(dayCount, forKey: "todayPickups")
        }
        // File mirror — keeps the sealed ShieldConfiguration's count fresh.
        // Write ONLY dayCount (the per-day key value), NOT max(dayCount, current).
        // Using max risks writing a stale todayPickups from yesterday's cached process
        // state — "34 yesterday" would become "today|34" in a long-running process.
        // The per-day key (picksy_pickups_yyyy-MM-dd) is always fresh because it's a
        // new key each day; the stale todayPickups key is never used for the file.
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("today_pickups.txt") {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            try? "\(f.string(from: Date()))|\(dayCount)"
                .data(using: .utf8)?.write(to: url, options: .atomic)
        }

        WidgetCenter.shared.reloadAllTimelines()

        // Poke the main app (if alive) to refresh its in-memory count.
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("dev.fotiospongas.picksy.pickupRecorded" as CFString),
            nil, nil, true
        )
    }

    private func dayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "picksy_pickups_\(f.string(from: Date()))"
    }
}
