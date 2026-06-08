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
            // Count the pickup, then LIFT the shield for THIS app so it actually
            // opens (.none alone does not launch a still-shielded app). The shield
            // is re-applied next time Picksy comes to the foreground.
            countPickup()
            liftShield(for: application)
            completionHandler(.none)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - Category

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            countPickup()
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

        // Time-limit store: free this app so it opens (re-applied at next limit/midnight).
        let tlStore = ManagedSettingsStore(named: .init("picksy.timeLimit"))
        if var s = tlStore.shield.applications {
            s.remove(token)
            tlStore.shield.applications = s.isEmpty ? nil : s
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
