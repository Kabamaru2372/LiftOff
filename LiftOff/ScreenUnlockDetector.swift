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
    static let picksyAskWhyPickup       = Notification.Name("picksy.askWhyPickup")
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

    /// Καλείται όταν ο χρήστης επιστρέφει στο Picksy μετά από σύντομη απουσία
    /// (< 10 λεπτά, π.χ. Control Center ή γρήγορο app switch). Αντί να ξεκινάει
    /// η μέτρηση από μηδέν, κάνει resume τα notifications με τον σωστό
    /// εναπομείναντα χρόνο από το αρχικό unlock.
    var onScreenSessionResumed: (() -> Void)?

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

        // AUDIO LOCK FIX: Secondary lock detection via willResignActive.
        // protectedDataWillBecomeUnavailable does NOT fire when the screen
        // auto-locks during audio playback (music, podcasts) because iOS
        // keeps Protected Data available for the audio session. This causes
        // continuous-session timers to keep running — the user listens to
        // music for 1.5h and gets a "3h on your phone" notification.
        //
        // willResignActive fires when the screen turns off EVEN during audio
        // playback. We use it ONLY to cancel the continuous-session timers
        // (NOT for pickup counting — it also fires on app switching, Control
        // Center, Notification Center, etc., which would miscount pickups).
        // The complementary didBecomeActive handler re-schedules the timers
        // if the user returns quickly (was just in Control Center, etc.).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResignActive(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
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

        // Protected data just became available (device unlocked).
        _protectedDataAvailable = true

        // Clear the resign-active flag — a real unlock supersedes any stale state.
        resignedActiveWhileProtectedDataAvailable = false
        resignedActiveTimestamp = nil

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
        // Protected data is about to become unavailable (device locking).
        _protectedDataAvailable = false

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
        // Synchronous cancellation: iOS can suspend the process between here and
        // the DispatchQueue.main.async block below, so we cancel immediately while
        // we are guaranteed to be executing. The async block also cancels via
        // onScreenSessionEnded as a secondary guarantee.
        ScreenTimeMilestoneNotifier.shared.cancelContinuousSession()
        DispatchQueue.main.async { [weak self] in
            self?.onScreenSessionEnded?(duration)
        }
    }

    // MARK: - Resign Active / Become Active (Audio Lock Fix)

    /// AUDIO LOCK FIX: Handles the case where the screen auto-locks while audio
    /// is playing (music, podcasts, audiobooks). In this scenario:
    ///   - protectedDataWillBecomeUnavailable does NOT fire (audio keeps it available)
    ///   - willResignActive DOES fire (the app is no longer active)
    ///
    /// We cancel continuous-session timers here so a user listening to music for
    /// 1.5h doesn't get a false "3h on your phone" notification. We do NOT record
    /// a screen session end (no onScreenSessionEnded callback) because willResignActive
    /// also fires for Control Center, Notification Center, incoming calls, etc. —
    /// recording screen time from those would be inaccurate.
    ///
    /// The complementary didBecomeActive handler re-schedules the timers if the
    /// user was just briefly inactive (Control Center, etc.) and returned to the
    /// phone — so we don't permanently lose the continuous-session tracking.
    @objc private func handleResignActive(_ notification: Notification) {
        guard _protectedDataAvailable else {
            // protectedData is unavailable → handleScreenLock will handle it (or already did)
            return
        }
        resignedActiveWhileProtectedDataAvailable = true
        resignedActiveTimestamp = Date()
        // Preserve session start timestamp so resumeContinuousSession can
        // re-schedule with the correct remaining time if this was a brief
        // interruption (Control Center, quick app switch). If the user doesn't
        // return within 10 min, handleBecomeActive skips the resume entirely.
        ScreenTimeMilestoneNotifier.shared.cancelContinuousSession(preserveSessionStart: true)
        log("📴 Resign active (protected data still available — possible audio lock) — cancelled continuous-session timers")
    }

    /// Resumes or drops the continuous session when the user returns to Picksy
    /// after a resign-active event. Uses elapsed time to distinguish:
    ///   • Brief absence (< 10 min): Control Center, Notification Center, quick
    ///     app switch — RESUME with the correct remaining time from the original
    ///     unlock (via onScreenSessionResumed). No clock reset.
    ///   • Long absence (≥ 10 min): likely audio-lock (music playing with screen
    ///     off) or the user was genuinely away — DON'T resume. The next real
    ///     unlock (protectedDataDidBecomeAvailable) will start a fresh session.
    @objc private func handleBecomeActive(_ notification: Notification) {
        guard resignedActiveWhileProtectedDataAvailable else { return }
        resignedActiveWhileProtectedDataAvailable = false

        let elapsed = Date().timeIntervalSince(resignedActiveTimestamp ?? .distantPast)
        resignedActiveTimestamp = nil

        if elapsed < 600 { // < 10 minutes: brief interruption
            DispatchQueue.main.async { [weak self] in
                self?.onScreenSessionResumed?()
            }
            log("📱 Became active after brief absence (\(Int(elapsed))s) — resuming session with remaining time")
        } else {
            // Long absence — likely audio-lock or user was away. Don't resume;
            // the next protectedDataDidBecomeAvailable will start fresh.
            // Clean up the preserved session start (cancelContinuousSession was
            // called with preserveSessionStart:true — now that we've decided not
            // to resume, clear it so BGAppRefresh doesn't misinterpret it).
            ScreenTimeMilestoneNotifier.shared.cancelContinuousSession()
            log("⏭ Became active after long absence (\(Int(elapsed))s) — session fully cancelled (likely audio-lock)")
        }
    }

    /// Tracks whether the last resign-active happened while protected data was
    /// still available (meaning it might be an audio-lock, not a normal lock).
    /// Reset by handleBecomeActive (user returned) or handlePotentialPickup (new unlock).
    private var resignedActiveWhileProtectedDataAvailable = false

    /// Tracks whether protected data is currently available (device unlocked).
    /// Updated by our existing protectedDataDidBecomeAvailable / WillBecomeUnavailable
    /// observers. Replaces UIApplication.shared.isProtectedDataAvailable which is
    /// unavailable in app extension targets.
    private var _protectedDataAvailable = false

    /// Timestamp of the last willResignActive while protected data was available.
    /// Used by handleBecomeActive to decide whether to RESUME the continuous session
    /// (brief absence < 10min → resume with remaining time) or skip (long absence
    /// → likely audio-lock, wait for next real unlock).
    private var resignedActiveTimestamp: Date?

    // MARK: - Logging

    private func log(_ message: String) {
        print("[ScreenUnlockDetector] \(message)")
    }
}

