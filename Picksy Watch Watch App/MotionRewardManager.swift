//
//  MotionRewardManager.swift
//  Picksy Watch
//
//  Rewards the user for walking instead of staring at the phone.
//
//  Uses CMPedometer (live step counting) rather than CMMotionActivityManager —
//  on older watches the activity classifier often reports "unknown", whereas the
//  pedometer reliably reports steps. We treat "steps increased recently" as the
//  signal that the user is actively walking, and reward sustained walking.
//
//  ⚡️ Battery: this is CALLBACK-DRIVEN. There is no always-on polling timer.
//  CMPedometer only delivers updates while the user is actually moving, so when
//  the wrist is still we do zero work. A single one-shot "stopped walking" timer
//  is armed only while moving and is torn down the moment movement stops. The
//  manager is also paused when the app leaves the foreground (see Picksy_WatchApp).
//
//  Requires the "Privacy - Motion Usage Description" (NSMotionUsageDescription)
//  key in the watch app's Info settings.
//

import Foundation
import CoreMotion
import WatchKit
import Observation

@Observable
final class MotionRewardManager {

    static let shared = MotionRewardManager()

    private let pedometer = CMPedometer()

    // ── Tunables ──────────────────────────────────────────────────────────
    /// Continuous walking required before the first reward (seconds).
    private let rewardAfter: TimeInterval = 120        // 2 minutes
    /// Minimum gap between two rewards (seconds).
    private let rewardCooldown: TimeInterval = 8 * 60  // 8 minutes
    /// Max seconds since the last new step to still count as "walking".
    private let staleWindow: TimeInterval = 6

    // ── Published state (read by the UI) ──────────────────────────────────
    var isMoving = false
    var showReward = false
    var activeMinutesToday = 0

    // ── Internal ──────────────────────────────────────────────────────────
    private var isRunning = false
    private var lastSteps = 0
    private var lastStepAt: Date?
    private var movingStart: Date?
    private var lastRewardAt: Date?
    private var activeSecondsAccum: TimeInterval = 0
    private var staleTimer: Timer?
    private var dayKey: String = ""

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        guard CMPedometer.isStepCountingAvailable() else {
            print("[MotionReward] Step counting unavailable.")
            return
        }
        isRunning = true
        resetForDayIfNeeded()

        // CMPedometer delivers updates ONLY while the user is moving. numberOfSteps
        // is cumulative from the start date. No polling timer needed.
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            let steps = data.numberOfSteps.intValue
            DispatchQueue.main.async { self.handleSteps(steps) }
        }
    }

    /// Pause all motion work — call when the app leaves the foreground so nothing
    /// runs (and no battery is spent) while the watch face is down.
    func pause() {
        guard isRunning else { return }
        isRunning = false
        pedometer.stopUpdates()
        staleTimer?.invalidate()
        staleTimer = nil
        if isMoving { isMoving = false }
        movingStart = nil
        lastStepAt = nil
    }

    /// Backwards-compatible alias.
    func stop() { pause() }

    // MARK: - Step handling (callback-driven)

    private func handleSteps(_ steps: Int) {
        resetForDayIfNeeded()

        // Only react to genuinely new steps.
        guard steps > lastSteps else { return }

        let now = Date()

        // Accumulate active time from the gap since the last step (if it was
        // recent enough to count as continuous movement).
        if let last = lastStepAt {
            let gap = now.timeIntervalSince(last)
            if gap <= staleWindow {
                activeSecondsAccum += gap
                while activeSecondsAccum >= 60 {
                    activeMinutesToday += 1
                    activeSecondsAccum -= 60
                }
            } else {
                // Long gap → previous walk had already ended; start fresh.
                movingStart = nil
            }
        }

        lastSteps = steps
        lastStepAt = now
        if movingStart == nil { movingStart = now }
        if !isMoving { isMoving = true }

        // Reward sustained continuous walking.
        if let start = movingStart, now.timeIntervalSince(start) >= rewardAfter {
            fireRewardIfReady()
        }

        armStaleTimer()
    }

    /// One-shot timer that marks movement as stopped if no new steps arrive within
    /// `staleWindow`. Re-armed on every step; torn down when it fires. This is the
    /// only timer in the manager and it exists only while moving.
    private func armStaleTimer() {
        staleTimer?.invalidate()
        let timer = Timer(timeInterval: staleWindow, repeats: false) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isMoving = false
                self.movingStart = nil
                self.staleTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        staleTimer = timer
    }

    private func fireRewardIfReady() {
        let now = Date()
        if let last = lastRewardAt, now.timeIntervalSince(last) < rewardCooldown { return }
        lastRewardAt = now

        WKInterfaceDevice.current().play(.success)

        showReward = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.showReward = false
        }

        // Restart the continuous-walk clock so the next reward needs another
        // sustained stretch.
        movingStart = now
    }

    private func resetForDayIfNeeded() {
        let key = Self.todayKey()
        if key != dayKey {
            dayKey = key
            activeMinutesToday = 0
            activeSecondsAccum = 0
            movingStart = nil
            lastRewardAt = nil
        }
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
