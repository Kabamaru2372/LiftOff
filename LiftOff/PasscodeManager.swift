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

final class PasscodeManager {

    static let shared = PasscodeManager()
    private init() {}

    private let appGroup = UserDefaults(suiteName: "group.fotiospongas.picksy")

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
        guard let stored = appGroup?.string(forKey: hashKey), !stored.isEmpty else { return false }
        return stored == hash(code)
    }

    private func hash(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
