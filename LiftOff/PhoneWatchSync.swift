//
//  PhoneWatchSync.swift
//  Picksy (iOS)
//
//  Sends live pickup / screen-time / goal data to the paired Apple Watch via
//  WatchConnectivity. Uses `updateApplicationContext` so the Watch always has
//  the latest snapshot, even if it was asleep when the update happened.
//

import Foundation
import WatchConnectivity

final class PhoneWatchSync: NSObject, WCSessionDelegate {

    static let shared = PhoneWatchSync()

    private override init() { super.init() }

    /// Call once at app launch.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Push the latest snapshot to the Watch. Safe to call frequently —
    /// updateApplicationContext coalesces to the most recent value.
    func send(pickups: Int,
              totalSeconds: Int,
              goal: Int,
              streak: Int,
              language: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let ctx: [String: Any] = [
            "pickups":      pickups,
            "totalSeconds": totalSeconds,
            "goal":         goal,
            "streak":       streak,
            "language":     language,
            "ts":           Date().timeIntervalSince1970
        ]

        do {
            try session.updateApplicationContext(ctx)
        } catch {
            print("[PhoneWatchSync] updateApplicationContext failed: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate (iOS requires all three)

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            print("[PhoneWatchSync] activation error: \(error.localizedDescription)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so a newly-switched watch keeps receiving data.
        WCSession.default.activate()
    }
}
