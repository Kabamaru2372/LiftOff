//
//  PickupDetector.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
// Χρησιμοποιεί τον accelerometer του iPhone για να ανιχνεύσει
// πότε ο χρήστης σηκώνει το κινητό.
//
// Πώς δουλεύει:
// - Ο accelerometer μετράει τη βαρύτητα + κίνηση σε 3 άξονες (x, y, z)
// - Όταν το κινητό είναι ακίνητο σε τραπέζι: σταθερές τιμές
// - Όταν το σηκώνεις: απότομη αλλαγή στις τιμές
// - Εμείς ανιχνεύουμε αυτή την αλλαγή

import Foundation
import CoreMotion
import SwiftUI

@Observable
class PickupDetector {
    
    // CMMotionManager = η "γέφυρα" προς τους sensors του iPhone
    private let motionManager = CMMotionManager()
    
    // Κατάσταση
    var isMonitoring: Bool = false
    var pickupDetected: Bool = false
    
    // Ρυθμίσεις ανίχνευσης
    private var lastAcceleration: CMAcceleration?
    private var isPhoneStationary: Bool = true
    private var stationaryTimer: Timer?
    
    // Threshold = πόση αλλαγή χρειάζεται για να θεωρηθεί "pickup"
    // Μικρότερο = πιο ευαίσθητο, Μεγαλύτερο = λιγότερο ευαίσθητο
    private let pickupThreshold: Double = 0.3
    
    // Πόσο συχνά ελέγχουμε (σε δευτερόλεπτα)
    private let updateInterval: Double = 0.1  // 10 φορές/δεύτερο
    
    // Cooldown: μετά από ένα pickup, περίμενε τόσο πριν ανιχνεύσεις άλλο
    private var lastPickupTime: Date = .distantPast
    private let cooldownSeconds: Double = 30
    
    func startMonitoring() {
        // Τσέκαρε αν ο accelerometer είναι διαθέσιμος
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available")
            return
        }
        
        // Ρύθμισε πόσο συχνά θέλουμε updates
        motionManager.accelerometerUpdateInterval = updateInterval
        
        // Ξεκίνα να λαμβάνεις δεδομένα
        // OperationQueue.main = τρέξε στο κύριο thread (για UI updates)
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            // [weak self] = αποφυγή memory leak
            // Αν το self (δηλαδή αυτό το object) δεν υπάρχει πια, σταμάτα
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
        // Αν δεν έχουμε προηγούμενη μέτρηση, αποθήκευσε και περίμενε
        guard let last = lastAcceleration else {
            lastAcceleration = acceleration
            return
        }
        
        // Υπολόγισε τη "δύναμη" της αλλαγής
        // Αν το κινητό είναι ακίνητο, αυτό θα είναι ~0
        // Αν το σηκώσεις, θα αυξηθεί απότομα
        let deltaX = acceleration.x - last.x
        let deltaY = acceleration.y - last.y
        let deltaZ = acceleration.z - last.z
        
        // Magnitude = η συνολική "ένταση" της κίνησης
        // sqrt(x² + y² + z²) = Πυθαγόρειο θεώρημα σε 3D
        let magnitude = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
        
        // Αποθήκευσε για την επόμενη σύγκριση
        lastAcceleration = acceleration
        
        if magnitude > pickupThreshold {
            // Κίνηση ανιχνεύτηκε!
            
            if isPhoneStationary {
                // Ήταν ακίνητο → τώρα κινείται = PICKUP!
                handlePickup()
            }
            
            isPhoneStationary = false
            
            // Reset τον stationary timer
            stationaryTimer?.invalidate()
            stationaryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                // Αν περάσουν 2 δεύτερα χωρίς κίνηση = ακίνητο ξανά
                self?.isPhoneStationary = true
            }
        }
    }
    
    private func handlePickup() {
        // Τσέκαρε cooldown
        let timeSinceLastPickup = Date().timeIntervalSince(lastPickupTime)
        guard timeSinceLastPickup > cooldownSeconds else { return }
        
        lastPickupTime = Date()
        
        // Ενημέρωσε το UI (στο main thread)
        pickupDetected = true
        
        // Haptic feedback — μια μικρή δόνηση
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // Καλείται μετά που ο χρήστης πάτησε "LiftOff" ή "Continue"
    func acknowledgePickup() {
        pickupDetected = false
    }
}

