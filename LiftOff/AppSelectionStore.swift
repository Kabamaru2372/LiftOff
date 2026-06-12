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

    /// Οι επιλεγμένες apps του user.
    /// includeEntireCategory:true → ticking a category in the picker expands it
    /// to the category's CURRENT apps as individual tokens, so shielding stays
    /// per-app (precise tap-through lifting — a category-token policy can't tell
    /// which app was opened). Trade-off: apps installed later into a ticked
    /// category aren't auto-added until the user re-opens the picker.
    var selection: FamilyActivitySelection = FamilyActivitySelection(includeEntireCategory: true) {
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
            var decoded = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)

            // Migration: selections saved before includeEntireCategory was on.
            // Rebuild with the flag set (app tokens carry over) so future
            // category ticks expand to per-app tokens. A bare category token
            // from the old format can't be expanded retroactively — the user
            // re-ticks the category once in the picker to expand it.
            if !decoded.includeEntireCategory {
                var migrated = FamilyActivitySelection(includeEntireCategory: true)
                migrated.applicationTokens = decoded.applicationTokens
                migrated.categoryTokens = decoded.categoryTokens
                decoded = migrated
                // Persist directly — saveSelection()'s monitoring refresh must
                // not run here (singleton init; PickupScheduler reads us back).
                if let migratedData = try? JSONEncoder().encode(migrated) {
                    defaults.set(migratedData, forKey: selectionKey)
                }
                print("🔁 App selection migrated to includeEntireCategory format")
            }

            selection = decoded
            isLoading = false
            print("✅ App selection loaded: \(selectedAppsCount) apps, \(selectedCategoriesCount) categories")
        } catch {
            isLoading = false
            print("❌ Failed to load selection: \(error)")
        }
    }

    /// Καθαρίζει την επιλογή
    func clearSelection() {
        selection = FamilyActivitySelection(includeEntireCategory: true)
    }
}
