//
//  PasscodeManager.swift
//  Picksy
//
//  Optional 4-digit passcode for the daily time limit (parental use): when the
//  limit is reached, tracked apps lock and only the passcode grants another
//  session of the same length. The passcode is the parent's tool to resist the
//  child (or the user themselves) — stored as a SHA-256 hash in the App Group so
//  the shield extensions can read whether a passcode is required (they never need
//  the code itself; only the main app verifies it).
//

import Foundation
import CryptoKit
import DeviceActivity

final class PasscodeManager {

    static let shared = PasscodeManager()
    private init() {}

    private let appGroup = UserDefaults(suiteName: "group.fotiospongas.picksy")
    private let appGroupID = "group.fotiospongas.picksy"

    /// Read by the Shield extensions to decide whether the time-limit shield can
    /// be bypassed (false) or strictly requires the in-app passcode (true).
    static let requiredKey = "picksy_timelimit_password_required"
    private let hashKey = "picksy_timelimit_passcode_hash"

    /// True when a passcode is set and required for the time limit.
    var isRequired: Bool {
        (appGroup?.bool(forKey: Self.requiredKey) ?? false) && isSet
    }

    var isSet: Bool {
        !(appGroup?.string(forKey: hashKey)?.isEmpty ?? true)
    }

    /// Sets a new passcode and turns the requirement on.
    func setPasscode(_ code: String) {
        appGroup?.set(hash(code), forKey: hashKey)
        appGroup?.set(true, forKey: Self.requiredKey)
        // If the time limit already fired today, write the file-based lock marker so
        // the ShieldAction extension (which may have a stale UserDefaults cache) picks
        // up the newly-required passcode immediately.
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        if appGroup?.string(forKey: "picksy_timelimit_active") == today,
           let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.fotiospongas.picksy")?
            .appendingPathComponent("picksy_timelimit_lock.txt") {
            try? today.data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }

    /// Turns the passcode requirement off and forgets the code.
    func disable() {
        appGroup?.set(false, forKey: Self.requiredKey)
        appGroup?.removeObject(forKey: hashKey)
        // Clear the file-based lock marker so the ShieldAction extension no longer
        // treats the time limit as passcode-locked.
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.fotiospongas.picksy")?
            .appendingPathComponent("picksy_timelimit_lock.txt") {
            try? "".data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }

    /// Returns true if the entered code matches the stored one.
    func verify(_ code: String) -> Bool {
        guard lockoutRemaining <= 0 else { return false }
        guard let stored = appGroup?.string(forKey: hashKey), !stored.isEmpty else { return false }
        if stored == hash(code) {
            appGroup?.set(0, forKey: Self.failCountKey)
            appGroup?.removeObject(forKey: Self.lockUntilKey)
            return true
        }
        registerFailure()
        return false
    }

    // MARK: - Attempt limiting (a 4-digit code is otherwise trivially brute-forced)

    private static let failCountKey = "picksy_passcode_fail_count"
    private static let lockUntilKey = "picksy_passcode_lock_until"
    /// Free attempts before the first lockout.
    static let freeAttempts = 5

    /// Seconds left of the current lockout (0 when entry is allowed).
    var lockoutRemaining: TimeInterval {
        let until = appGroup?.double(forKey: Self.lockUntilKey) ?? 0
        let left = until - Date().timeIntervalSince1970
        // A clock moved far back must not shorten the lockout: the longest one is 15 min.
        guard left > 0 else { return 0 }
        return min(left, 15 * 60)
    }

    private func registerFailure() {
        let fails = (appGroup?.integer(forKey: Self.failCountKey) ?? 0) + 1
        appGroup?.set(fails, forKey: Self.failCountKey)
        guard fails >= Self.freeAttempts else { return }
        // 30 s, 60 s, 2 min, 4 min ... capped at 15 min.
        let seconds = min(30.0 * pow(2.0, Double(fails - Self.freeAttempts)), 15 * 60)
        appGroup?.set(Date().timeIntervalSince1970 + seconds, forKey: Self.lockUntilKey)
    }

    // MARK: - Management gate (changing tracked apps / limits while a passcode is required)

    /// In-memory on purpose: it is forgotten when the app is killed, and re-locked
    /// explicitly when Settings closes or the app goes to the background.
    private static var managementUnlockedAt: Date?
    private static let managementWindow: TimeInterval = 5 * 60

    /// True when no passcode is required, or it was entered in the last few minutes.
    var isManagementUnlocked: Bool {
        guard isRequired else { return true }
        guard let at = Self.managementUnlockedAt else { return false }
        let age = Date().timeIntervalSince(at)
        return age >= 0 && age < Self.managementWindow
    }

    func markManagementUnlocked() { Self.managementUnlockedAt = Date() }
    func lockManagement() { Self.managementUnlockedAt = nil }

    /// True when App Lock is switched on.
    var isAppLockEnabled: Bool { appGroup?.bool(forKey: "picksy_app_lock_enabled") ?? false }

    // MARK: - App Lock (always-on, selectable duration)

    /// Writes an unlock window for the App Lock feature. Called from the main app
    /// after the user enters the correct passcode. Extensions read the file to
    /// decide whether to block or allow the current shield tap.
    func unlockAppLock(durationMinutes: Int) {
        let unlockUntil = Date().timeIntervalSince1970 + Double(max(durationMinutes, 1) * 60)
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("picksy_app_lock_unlock_until.txt") {
            try? "\(unlockUntil)".data(using: .utf8)?.write(to: url, options: .atomic)
        }
        appGroup?.set(unlockUntil, forKey: "picksy_app_lock_unlock_until")
        scheduleAppLockReshield(at: Date(timeIntervalSince1970: unlockUntil))
    }

    /// Longest unlock window offered in Settings (60 min) plus slack. An unlock stamp
    /// further in the future than this means the clock was moved back: treat as expired.
    static let maxUnlockWindow: TimeInterval = 65 * 60

    /// Wakes the monitor extension when the unlock window ends so apps that were
    /// opened during the window are shielded again, even if Picksy never returns
    /// to the foreground. Best effort (iOS requires a 15 min minimum interval).
    private func scheduleAppLockReshield(at end: Date) {
        let cal = Calendar.current
        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(comps, from: end),
            intervalEnd: cal.dateComponents(comps, from: end.addingTimeInterval(30 * 60)),
            repeats: false
        )
        try? DeviceActivityCenter().startMonitoring(DeviceActivityName("picksy.applock.reshield"), during: schedule)
    }

    /// True when the user has entered the passcode and the unlock window is still active.
    /// File-first so long-running extension processes see fresh state.
    func isAppLockUnlocked() -> Bool {
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("picksy_app_lock_unlock_until.txt"),
           let raw = try? String(contentsOf: url, encoding: .utf8),
           let ts = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return Self.windowIsOpen(until: ts)
        }
        let ts = appGroup?.double(forKey: "picksy_app_lock_unlock_until") ?? 0
        return Self.windowIsOpen(until: ts)
    }

    private static func windowIsOpen(until ts: Double) -> Bool {
        let left = ts - Date().timeIntervalSince1970
        return left > 0 && left <= maxUnlockWindow
    }

    /// Clears the App Lock unlock window (called when disabling the feature).
    func clearAppLockUnlockWindow() {
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("picksy_app_lock_unlock_until.txt") {
            try? "0".data(using: .utf8)?.write(to: url, options: .atomic)
        }
        appGroup?.removeObject(forKey: "picksy_app_lock_unlock_until")
    }

    private func hash(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
