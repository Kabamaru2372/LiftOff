//
//  WatchConnectivityManager.swift
//  Picksy Watch
//
//  Receives live data from the iPhone via WatchConnectivity and feeds it into
//  WatchDataModel. Uses `updateApplicationContext` (latest-state, low-overhead)
//  as the primary channel, with `transferUserInfo` as a fallback.
//

import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject, WCSessionDelegate {

    static let shared = WatchConnectivityManager()

    private override init() { super.init() }

    /// Call once at app launch.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            print("[WatchSync] activation error: \(error.localizedDescription)")
            return
        }
        // On activation, immediately apply whatever the phone last sent.
        applyContext(session.receivedApplicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        applyContext(applicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        applyContext(userInfo)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        applyContext(message)
    }

    // MARK: - Apply

    private func applyContext(_ ctx: [String: Any]) {
        guard !ctx.isEmpty else { return }
        DispatchQueue.main.async {
            let m = WatchDataModel.shared
            m.apply(
                pickups:      ctx["pickups"]      as? Int    ?? m.todayPickups,
                totalSeconds: ctx["totalSeconds"] as? Int    ?? m.todayTotalSeconds,
                goal:         ctx["goal"]         as? Int    ?? m.dailyGoal,
                streak:       ctx["streak"]       as? Int    ?? m.currentStreak,
                language:     ctx["language"]     as? String ?? m.appLanguage
            )
        }
    }
}
