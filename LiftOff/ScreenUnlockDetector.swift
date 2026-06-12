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
    static let picksyDuelFinalized      = Notification.Name("picksy.duelFinalized")

    /// Posted από το NotificationDelegate όταν ο χρήστης πατήσει duel/message
    /// push notification. Το FriendsView το ακούει για να κάνει re-poll και
    /// να δείξει DuelResultView αν υπάρχει νέο αποτέλεσμα.
    static let picksyDuelNotifTapped    = Notification.Name("picksy.duelNotificationTapped")
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
    /// Fix #1: Αποθηκεύεται στο App Group UserDefaults ώστε να μοιράζεται
    /// με το DeviceActivity extension — ένα κοινό cooldown και για τα δύο systems.
    private(set) var lastPickupTime: Date {
        get {
            let defaults = UserDefaults(suiteName: "group.fotiospongas.picksy") ?? .standard
            let timestamp = defaults.double(forKey: Self.lastPickupKey)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : .distantPast
        }
        set {
            let defaults = UserDefaults(suiteName: "group.fotiospongas.picksy") ?? .standard
            defaults.set(newValue.timeIntervalSince1970, forKey: Self.lastPickupKey)
        }
    }

    // MARK: - Configuration

    /// Cooldown μεταξύ pickups σε δευτερόλεπτα.
    ///
    /// `protectedDataDidBecomeAvailable` fires once per REAL unlock (Face ID /
    /// passcode) — never on a notification waking the lock screen (that's why our
    /// count is more honest than Apple's "Pickups", which inflates with
    /// notifications). 30s was far too long: two genuine unlocks within half a
    /// minute were merged into one, undercounting badly. 3s only dedups the same
    /// physical pickup (unlock + the tracked-app-open that follows ~1-2s later,
    /// via the shared timestamp), while counting every distinct real unlock.
    private let cooldownSeconds: TimeInterval = 3

    /// Shared key — ίδιο με το DeviceActivity extension για κοινό cooldown (fix #1)
    private static let lastPickupKey = "picksy_last_pickup_timestamp"

    // MARK: - Callback

    /// Καλείται κάθε φορά που detect-άρεται νέο pickup
    /// (μετά από cooldown check). Set this from DataStore initialization.
    var onPickupDetected: (() -> Void)?

    /// Καλείται όταν η οθόνη κλειδώνει, με τη διάρκεια της session σε δευτερόλεπτα.
    /// Χρησιμοποιείται για screen time tracking.
    var onScreenSessionEnded: ((Int) -> Void)?

    /// Καλείται σε ΚΑΘΕ unlock (πριν το pickup cooldown), δηλαδή στην αρχή κάθε
    /// συνεχόμενης χρήσης οθόνης. Χρησιμοποιείται για τις ειδοποιήσεις
    /// "συνεχόμενης χρήσης" (continuous-use), που προγραμματίζονται από αυτή τη
    /// στιγμή και ακυρώνονται στο lock.
    var onScreenSessionStarted: (() -> Void)?

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

        // Continuous-use session START — fires on EVERY unlock (independent of the
        // pickup cooldown). Restarts the continuous clock from this moment.
        DispatchQueue.main.async { [weak self] in
            self?.onScreenSessionStarted?()
        }

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
        // Always notify session end so continuous-use alerts get cancelled — even
        // if we never recorded a start (e.g. the unlock fell inside the pickup
        // cooldown, which previously left sessionStartTime nil and SKIPPED the
        // cancel, letting a stale "you've been on your phone" alert fire later).
        let duration: Int
        if let start = sessionStartTime {
            duration = max(1, Int(Date().timeIntervalSince(start)))
            sessionStartTime = nil
        } else {
            duration = 0
        }
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

