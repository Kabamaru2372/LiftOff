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

    /// Removes a single app from the shield set so it can launch. Picksy re-applies
    /// the full shield on its next foreground (ShieldManager.refresh).
    private func liftShield(for token: ApplicationToken) {
        var apps = store.shield.applications ?? []
        apps.remove(token)
        store.shield.applications = apps.isEmpty ? nil : apps
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
