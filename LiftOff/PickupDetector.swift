//
//  PickupDetector.swift
//  LiftOff
//
//  Created by Fotios Pongas on 24.03.26.
//
//  v1.6 UPDATE - Passive enrichment mode.
//
//  Στις προηγούμενες versions, αυτή η class έκανε pickup detection.
//  Λόγω accuracy issues (missed pickups όταν το κινητό ήταν σχετικά
//  ακίνητο, π.χ. στο τραπέζι ή στο κρεβάτι), η detection logic μεταφέρθηκε
//  στον ScreenUnlockDetector.
//
//  Αυτή η class τώρα τρέχει σε "passive mode": καταγράφει motion context
//  (stationary/in_motion) χωρίς να μετράει pickups. Τα δεδομένα μπορούν να
//  χρησιμοποιηθούν αργότερα για analytics όπως:
//  - "Πόσα pickups γίνανε ενώ ο χρήστης ήταν ξαπλωμένος;"
//  - "Pickups κατά τη διάρκεια walking vs sitting"
//

import Foundation
import CoreMotion
import SwiftUI

@Observable
class PickupDetector {

    // MARK: - State

    var isMonitoring: Bool = false

    /// Current motion state (stationary, inMotion, walking).
    /// Public για future analytics use.
    var motionState: MotionState = .unknown

    enum MotionState: String {
        case unknown
        case stationary
        case inMotion
    }

    // MARK: - CoreMotion

    private let motionManager = CMMotionManager()

    private var lastAcceleration: CMAcceleration?
    private var stationaryTimer: Timer?

    // MARK: - Configuration

    /// Threshold για detection αλλαγής στη motion state.
    private let motionThreshold: Double = 0.25

    /// Πόσο συχνά διαβάζουμε accelerometer.
    /// 0.5s είναι αρκετά για motion state tracking, χωρίς να τρώει μπαταρία.
    /// (Παλαιότερα ήταν 0.1s, αλλά τώρα δεν κάνουμε pickup detection
    /// οπότε δεν χρειαζόμαστε υψηλή ακρίβεια.)
    private let updateInterval: Double = 0.5

    // MARK: - Public API

    /// Ξεκινάει passive motion monitoring.
    /// Δεν τριγκάρει pickup detection, μόνο καταγράφει motion state.
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            log("⚠️ Accelerometer not available")
            return
        }

        guard !isMonitoring else {
            log("⚠️ Already monitoring, skip duplicate start")
            return
        }

        motionManager.accelerometerUpdateInterval = updateInterval

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            self.processAcceleration(data.acceleration)
        }

        isMonitoring = true
        log("✅ Started passive motion monitoring (enrichment mode)")
    }

    /// Σταματάει το monitoring.
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        stationaryTimer?.invalidate()
        stationaryTimer = nil
        isMonitoring = false
        motionState = .unknown
        log("🛑 Stopped motion monitoring")
    }

    // MARK: - Motion Processing

    private func processAcceleration(_ acceleration: CMAcceleration) {
        guard let last = lastAcceleration else {
            lastAcceleration = acceleration
            return
        }

        let deltaX = acceleration.x - last.x
        let deltaY = acceleration.y - last.y
        let deltaZ = acceleration.z - last.z

        let magnitude = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)

        lastAcceleration = acceleration

        if magnitude > motionThreshold {
            // Motion detected - update state
            if motionState != .inMotion {
                motionState = .inMotion
                log("📱 Motion state: in_motion")
            }

            // Reset stationary timer
            stationaryTimer?.invalidate()
            stationaryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.motionState = .stationary
                self.log("📱 Motion state: stationary")
            }
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        print("[PickupDetector] \(message)")
    }
}

