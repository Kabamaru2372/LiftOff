//
//  ScreenUnlockDetector.swift
//  Picksy
//
//  Created by Fotios Pongas on 04.05.2026
//
//  Primary pickup detection mechanism για Picksy v1.6.
//
//  Φιλοσοφία: Pickup = συνειδητό unlock από lock state.
//  ΟΧΙ app switching, ΟΧΙ foreground/background transitions, ΟΧΙ notifications.
//
//  Detection: Μόνο `protectedDataDidBecomeAvailable` notification
//  το οποίο fires όταν Face ID/Touch ID/Passcode επιτυχώς ξεκλειδώνει.
//
//  Cooldown: 30 seconds μεταξύ pickups.
//  Persisted στο UserDefaults για να επιβιώνει σε app suspensions/restarts.
//

import Foundation
import UIKit

// MARK: - Notification Name

extension Notification.Name {
    /// Posted όταν ο ScreenUnlockDetector detect-άρει νέο pickup
    /// (μετά το cooldown check). Listeners μπορούν να αντιδράσουν
    /// για UI updates, animations, κλπ.
    static let picksyPickupDetected = Notification.Name("picksy.pickupDetected")

    /// Posted από το DuelManager όταν μια μονομαχία ολοκληρωθεί/expire.
    /// Χρησιμοποιείται από το LiftOffApp για να καθαρίσει το Dynamic Island
    /// από το stale duel state (⚔️ + παλιά scores).
    static let picksyDuelFinalized  = Notification.Name("picksy.duelFinalized")
}

@Observable
class ScreenUnlockDetector {

    // MARK: - Singleton

    static let shared = ScreenUnlockDetector()

    // MARK: - State

    /// True αν το monitoring είναι ενεργό
    var isMonitoring: Bool = false

    /// Counter για debugging (πόσα pickups έχουν detect-αριστεί σε αυτή τη session)
    var sessionPickupCount: Int = 0

    /// Timestamp του τελευταίου detected pickup.
    /// Persisted στο UserDefaults για να επιβιώνει σε app suspensions.
    private(set) var lastPickupTime: Date {
        get {
            let timestamp = UserDefaults.standard.double(forKey: Self.lastPickupKey)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : .distantPast
        }
        set {
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: Self.lastPickupKey)
        }
    }

    // MARK: - Configuration

    /// Cooldown μεταξύ pickups σε δευτερόλεπτα.
    /// 30s αποφεύγει διπλομέτρηση από quick lock/unlock cycles.
    private let cooldownSeconds: TimeInterval = 30

    /// Key για persistence του lastPickupTime
    private static let lastPickupKey = "ScreenUnlockDetector.lastPickupTime"

    // MARK: - Callback

    /// Καλείται κάθε φορά που detect-άρεται νέο pickup
    /// (μετά από cooldown check). Set this from DataStore initialization.
    var onPickupDetected: (() -> Void)?

    /// Καλείται όταν η οθόνη κλειδώνει, με τη διάρκεια της session σε δευτερόλεπτα.
    /// Χρησιμοποιείται για screen time tracking.
    var onScreenSessionEnded: ((Int) -> Void)?

    /// Timestamp που ξεκίνησε η τρέχουσα screen session (unlock time).
    private var sessionStartTime: Date?

    // MARK: - Init

    private init() {}

    // MARK: - Monitoring

    /// Ξεκινάει το monitoring για screen unlock events.
    /// Listens ΜΟΝΟ για το `protectedDataDidBecomeAvailable` notification
    /// που fires σε πραγματικό device unlock.
    ///
    /// ΣΗΜΑΝΤΙΚΟ: Αφαιρέθηκαν τα `willEnterForeground` και `didBecomeActive`
    /// observers γιατί τριγκάρουν σε app switching, όχι σε actual unlocks.
    func startMonitoring() {
        // Defensive cleanup
        NotificationCenter.default.removeObserver(self)

        // ΜΟΝΟ το protectedDataDidBecomeAvailable.
        // Αυτό fires όταν device unlocks με Face ID/Touch ID/Passcode.
        // ΔΕΝ fires σε app foreground/background transitions.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePotentialPickup(_:)),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )

        // Screen lock detection — fires when device is about to lock
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenLock(_:)),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )

        isMonitoring = true

        let timeSinceLast = Date().timeIntervalSince(lastPickupTime)
        if lastPickupTime != .distantPast {
            log("✅ Started monitoring (last pickup: \(Int(timeSinceLast))s ago)")
        } else {
            log("✅ Started monitoring (no previous pickup)")
        }
    }

    /// Σταματάει το monitoring (για testing ή cleanup).
    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
        isMonitoring = false
        log("🛑 Stopped monitoring")
    }

    // MARK: - Detection Logic

    /// Καλείται όταν device γίνεται "available" (unlock detected).
    /// Εφαρμόζει cooldown logic και τριγκάρει το callback.
    @objc private func handlePotentialPickup(_ notification: Notification) {
        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastPickupTime)

        // Cooldown check
        guard timeSinceLast > cooldownSeconds else {
            log("⏭️ Skipped (cooldown): \(Int(timeSinceLast))s/\(Int(cooldownSeconds))s")
            return
        }

        // Νέο pickup detected!
        let isFirstPickup = lastPickupTime == .distantPast
        lastPickupTime = now
        sessionPickupCount += 1
        sessionStartTime = now  // ξεκινάει μέτρηση screen time

        if isFirstPickup {
            log("🎯 PICKUP DETECTED via screen_unlock (session: \(sessionPickupCount), first pickup)")
        } else {
            log("🎯 PICKUP DETECTED via screen_unlock (session: \(sessionPickupCount), \(Int(timeSinceLast))s since last)")
        }

        DispatchQueue.main.async { [weak self] in
            // (1) Direct callback για main app integration (DataStore recording)
            self?.onPickupDetected?()

            // (2) Broadcast για άλλους listeners (π.χ. NudgeView)
            NotificationCenter.default.post(
                name: .picksyPickupDetected,
                object: nil,
                userInfo: ["source": "screen_unlock"]
            )
        }
    }

    // MARK: - Screen Lock

    @objc private func handleScreenLock(_ notification: Notification) {
        guard let start = sessionStartTime else { return }
        let duration = max(1, Int(Date().timeIntervalSince(start)))
        sessionStartTime = nil
        log("🔒 Screen locked — session duration: \(duration)s")
        DispatchQueue.main.async { [weak self] in
            self?.onScreenSessionEnded?(duration)
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        print("[ScreenUnlockDetector] \(message)")
    }
}

