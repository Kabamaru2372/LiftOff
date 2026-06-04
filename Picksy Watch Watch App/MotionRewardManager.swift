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
    /// How often we re-evaluate.
    private let tickInterval: TimeInterval = 2
    /// Max seconds since the last new step to still count as "walking".
    private let staleWindow: TimeInterval = 6

    // ── Published state (read by the UI) ──────────────────────────────────
    var isMoving = false
    var showReward = false
    var activeMinutesToday = 0
    /// Debug: live step / cadence read-out.
    var lastActivityLabel = "—"

    // ── Internal ──────────────────────────────────────────────────────────
    private var lastSteps = 0
    private var lastStepAt: Date?
    private var movingStart: Date?
    private var lastRewardAt: Date?
    private var activeSecondsAccum: TimeInterval = 0
    private var tickTimer: Timer?
    private var dayKey: String = ""

    private init() {}

    func start() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("[MotionReward] Step counting unavailable.")
            lastActivityLabel = "unavailable"
            return
        }
        resetForDayIfNeeded()

        // Pedometer fires updates while the user is moving; numberOfSteps is
        // cumulative from the start date.
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { self.lastActivityLabel = "err: \(error.localizedDescription)" }
                return
            }
            guard let data else { return }
            let steps = data.numberOfSteps.intValue
            let cadence = data.currentCadence?.doubleValue ?? 0   // steps/sec
            DispatchQueue.main.async {
                if steps > self.lastSteps {
                    self.lastStepAt = Date()
                }
                self.lastSteps = steps
                self.lastActivityLabel = "steps \(steps) · cad \(String(format: "%.1f", cadence))"
            }
        }

        tickTimer?.invalidate()
        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    func stop() {
        pedometer.stopUpdates()
        tickTimer?.invalidate()
        tickTimer = nil
    }

    // MARK: - Tick

    private func tick() {
        resetForDayIfNeeded()

        let walking: Bool
        if let last = lastStepAt {
            walking = Date().timeIntervalSince(last) <= staleWindow
        } else {
            walking = false
        }

        let now = Date()
        if walking {
            if movingStart == nil { movingStart = now }
            if !isMoving { isMoving = true }

            activeSecondsAccum += tickInterval
            if activeSecondsAccum >= 60 {
                activeMinutesToday += Int(activeSecondsAccum / 60)
                activeSecondsAccum = activeSecondsAccum.truncatingRemainder(dividingBy: 60)
            }

            if let start = movingStart, now.timeIntervalSince(start) >= rewardAfter {
                fireRewardIfReady()
            }
        } else {
            movingStart = nil
            if isMoving { isMoving = false }
        }
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
