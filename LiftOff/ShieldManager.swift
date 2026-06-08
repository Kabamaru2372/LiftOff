//
//  ShieldManager.swift
//  Picksy
//
//  "Accurate Mode" (opt-in): shields the user's tracked apps via ManagedSettings.
//  When a shielded app is opened, iOS shows the Picksy cover screen and invokes
//  our ShieldAction extension — which counts the pickup reliably, even while the
//  main app is suspended. This is the only iOS mechanism that gives an exact
//  per-open count in the background.
//
//  Off by default. The user enables it from Settings, accepting a quick tap each
//  time they open a tracked app in exchange for accurate pickup counts (and the
//  friction nudges them to use the phone less — a feature, not just measurement).
//

import Foundation
import FamilyControls
import ManagedSettings

final class ShieldManager {

    static let shared = ShieldManager()
    private init() {}

    /// Persisted toggle. Mirrored to the App Group so extensions can read it.
    static let accurateModeKey = "picksy_accurate_mode"

    /// Dedicated store so our shields never clash with other ManagedSettings use.
    private let store = ManagedSettingsStore(named: .init("picksy.accurateMode"))

    /// Separate store for the daily time-limit shield (applied by the monitor when
    /// the limit is reached, cleared at midnight or when the user turns it off).
    private let timeLimitStore = ManagedSettingsStore(named: .init("picksy.timeLimit"))

    private let appGroup = UserDefaults(suiteName: "group.fotiospongas.picksy")

    var isAccurateModeOn: Bool {
        UserDefaults.standard.bool(forKey: Self.accurateModeKey)
    }

    /// Toggle Accurate Mode on/off and (un)apply the shields immediately.
    func setAccurateMode(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: Self.accurateModeKey)
        appGroup?.set(on, forKey: Self.accurateModeKey)
        if on { applyShields() } else { clearShields() }
    }

    /// Re-applies the current state. Call on launch and whenever the app
    /// selection changes (so newly added apps get shielded too).
    func refresh() {
        if isAccurateModeOn { applyShields() } else { clearShields() }
    }

    // MARK: - Private

    private func applyShields() {
        let selection = AppSelectionStore.shared.selection
        let apps = selection.applicationTokens

        // Shield ONLY the individually-selected apps — NOT whole categories.
        // Shielding a category (e.g. "Social") covers dozens of apps, which felt
        // like "everything is blocked". Per-app shielding is predictable and also
        // lets the ShieldAction extension lift the shield for one specific app so
        // it can open (you can't remove a single app from a category policy).
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = nil
    }

    private func clearShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    /// Clears the daily time-limit shield + its "reached" flag. Called when the
    /// user turns the limit off (the monitor clears it at midnight otherwise).
    func clearTimeLimitShield() {
        timeLimitStore.shield.applications = nil
        timeLimitStore.shield.applicationCategories = nil
        appGroup?.removeObject(forKey: "picksy_timelimit_active")
    }

    /// Grants another full session of the chosen length: clears the time-limit
    /// shield + flag, then restarts monitoring so the cumulative usage counter
    /// resets to zero and the limit fires again after another full window.
    /// Called from the in-app passcode screen (parental use case).
    func unlockTimeLimitSession() {
        clearTimeLimitShield()
        UsageThresholdManager.shared.restartMonitoring()
    }
}
