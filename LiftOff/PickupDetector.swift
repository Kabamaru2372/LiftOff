//
//  PickupDetector.swift
//  LiftOff
//
//  Created by Fotios Pongas on 24.03.26.
//
//  Χρησιμοποιεί τον accelerometer για να ανιχνεύσει
//  πότε ο χρήστης σηκώνει το κινητό — αυτόματα.

import Foundation
import CoreMotion
import SwiftUI

@Observable
class PickupDetector {

    private let motionManager = CMMotionManager()

    var isMonitoring: Bool = false
    var pickupDetected: Bool = false

    // Callback — καλείται αυτόματα κάθε φορά που ανιχνεύεται pickup
    var onPickupDetected: (() -> Void)?

    private var lastAcceleration: CMAcceleration?
    private var isPhoneStationary: Bool = true
    private var stationaryTimer: Timer?

    // Threshold: πόση αλλαγή = pickup
    private let pickupThreshold: Double = 0.25

    // Πόσο συχνά ελέγχουμε
    private let updateInterval: Double = 0.1

    // Cooldown: μετά από pickup, περίμενε πριν ανιχνεύσεις άλλο
    private var lastPickupTime: Date = .distantPast
    private let cooldownSeconds: Double = 30

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available")
            return
        }

        motionManager.accelerometerUpdateInterval = updateInterval

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            self.processAcceleration(data.acceleration)
        }

        isMonitoring = true
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        stationaryTimer?.invalidate()
        isMonitoring = false
    }

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

        if magnitude > pickupThreshold {
            if isPhoneStationary {
                // Ήταν ακίνητο → τώρα κινείται = PICKUP!
                handlePickup()
            }

            isPhoneStationary = false

            stationaryTimer?.invalidate()
            stationaryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.isPhoneStationary = true
            }
        }
    }

    private func handlePickup() {
        let timeSinceLastPickup = Date().timeIntervalSince(lastPickupTime)
        guard timeSinceLastPickup > cooldownSeconds else { return }

        lastPickupTime = Date()

        // Αυτόματη καταγραφή — χωρίς να χρειάζεται ο χρήστης να πατήσει κάτι
        onPickupDetected?()

        // Ενημέρωσε το UI
        pickupDetected = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func acknowledgePickup() {
        pickupDetected = false
    }
}

