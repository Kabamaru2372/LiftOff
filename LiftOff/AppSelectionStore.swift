//
//  AppSelectionStore.swift
//  Picksy
//
//  Created by Fotios Pongas on 27.04.2026
//
//  Διαχειρίζεται τις επιλεγμένες apps για tracking.
//  Αποθηκεύει το FamilyActivitySelection στο shared App Group
//  ώστε να το βλέπει και το extension.

import Foundation
import FamilyControls
import ManagedSettings

@Observable
class AppSelectionStore {

    // MARK: - State

    /// Οι επιλεγμένες apps του user
    var selection: FamilyActivitySelection = FamilyActivitySelection() {
        didSet {
            // Σώζουμε ΜΟΝΟ αν αυτή η αλλαγή δεν προέρχεται από load
            guard !isLoading else { return }
            saveSelection()
        }
    }

    /// Flag για να αποτρέψουμε το didSet να triggerάρει save κατά το load
    private var isLoading: Bool = false

    /// True αν ο user έχει επιλέξει τουλάχιστον μια app
    var hasSelectedApps: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    /// Πόσες individual apps έχει επιλέξει
    var selectedAppsCount: Int {
        selection.applicationTokens.count
    }

    /// Πόσες categories έχει επιλέξει
    var selectedCategoriesCount: Int {
        selection.categoryTokens.count
    }

    // MARK: - Storage

    private let appGroupID = "group.fotiospongas.picksy"
    private let selectionKey = "picksyAppSelection"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Singleton

    static let shared = AppSelectionStore()

    private init() {
        loadSelection()
    }

    // MARK: - Save / Load

    private func saveSelection() {
        guard let defaults = sharedDefaults else { return }

        do {
            let data = try JSONEncoder().encode(selection)
            defaults.set(data, forKey: selectionKey)
            print("✅ App selection saved: \(selectedAppsCount) apps, \(selectedCategoriesCount) categories")

            // Restart monitoring με τις νέες apps
            // ΜΟΝΟ αν είμαστε authorized και έχουμε apps
            if FamilyControlsManager.shared.isAuthorized && hasSelectedApps {
                PickupScheduler.shared.refreshMonitoring()
            }
        } catch {
            print("❌ Failed to save selection: \(error)")
        }
    }

    private func loadSelection() {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: selectionKey) else {
            return
        }

        do {
            isLoading = true
            selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            isLoading = false
            print("✅ App selection loaded: \(selectedAppsCount) apps, \(selectedCategoriesCount) categories")
        } catch {
            isLoading = false
            print("❌ Failed to load selection: \(error)")
        }
    }

    /// Καθαρίζει την επιλογή
    func clearSelection() {
        selection = FamilyActivitySelection()
    }
}
