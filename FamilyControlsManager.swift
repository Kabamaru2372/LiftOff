//
//  FamilyControlsManager.swift
//  Picksy
//
//  Created by Fotios Pongas on 26.04.2026
//
//  Διαχειρίζεται την authorization και την πρόσβαση στα Family Controls.
//  Αν ο user εγκρίνει, χρησιμοποιούμε DeviceActivity για ακριβή pickup data.
//  Αν αρνηθεί, fallback σε CoreMotion (PickupDetector).

import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

@Observable
class FamilyControlsManager {

    // MARK: - State

    /// True αν ο user έχει εγκρίνει Family Controls
    var isAuthorized: Bool = false

    /// True αν ζητήσαμε ήδη permission (για να μη ζητήσουμε ξανά)
    var hasRequestedAuthorization: Bool {
        UserDefaults.standard.bool(forKey: "picksyHasRequestedFamilyControls")
    }

    /// Σφάλμα από τελευταία απόπειρα authorization
    var lastError: String? = nil

    // MARK: - Singleton

    static let shared = FamilyControlsManager()

    private init() {
        // ΣΗΜΑΝΤΙΚΟ: ΜΗΝ καλείς το startMonitoring() εδώ.
        // Το init() μπορεί να τρέξει σε background thread ή πολύ νωρίς
        // στο app lifecycle, οπότε προκαλεί race conditions.
        // Το monitoring ξεκινάει από LiftOffApp.swift μετά το launch.
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Ελέγχει την τρέχουσα κατάσταση authorization (χωρίς να ζητήσει)
    @MainActor
    func checkAuthorizationStatus() {
        let status = AuthorizationCenter.shared.authorizationStatus
        isAuthorized = (status == .approved)
        print("🔍 Authorization status: \(status), isAuthorized: \(isAuthorized)")
    }

    /// Καλείται από το LiftOffApp.swift κατά το app launch
    /// Περιμένει λίγο και μετά ελέγχει το status (cold start race fix)
    @MainActor
    func refreshAuthorizationStatusOnLaunch() async {
        // Δίνουμε χρόνο στο AuthorizationCenter να φορτώσει το πραγματικό status
        // από το system. Αλλιώς στο cold start επιστρέφει .notDetermined.
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        checkAuthorizationStatus()

        // Αν είμαστε authorized ΚΑΙ έχουμε apps, ξεκίνα το monitoring
        if isAuthorized && AppSelectionStore.shared.hasSelectedApps {
            PickupScheduler.shared.startMonitoring()
        }
    }

    /// Ζητάει από τον user να εγκρίνει Family Controls
    /// Καλείται από το onboarding ή από settings
    @MainActor
    func requestAuthorization() async -> Bool {
        UserDefaults.standard.set(true, forKey: "picksyHasRequestedFamilyControls")

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
            lastError = nil
            print("✅ Family Controls authorized")

            // Ξεκινάμε αμέσως το DeviceActivity monitoring
            if AppSelectionStore.shared.hasSelectedApps {
                PickupScheduler.shared.startMonitoring()
            }

            return true
        } catch {
            isAuthorized = false
            lastError = error.localizedDescription
            print("❌ Family Controls authorization failed: \(error)")
            return false
        }
    }

    /// Ανακαλεί την authorization (αν χρειαστεί)
    func revokeAuthorization() {
        // Σταμάτα πρώτα το monitoring
        PickupScheduler.shared.stopMonitoring()

        AuthorizationCenter.shared.revokeAuthorization { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.isAuthorized = false
                    print("✅ Family Controls revoked")
                case .failure(let error):
                    self.lastError = error.localizedDescription
                    print("❌ Failed to revoke: \(error)")
                }
            }
        }
    }
}
