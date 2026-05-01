//
//  ProManager.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.03.26.

import Foundation
import SwiftUI
import StoreKit

@Observable
class ProManager {

    static let shared = ProManager()

    var isCheckingEntitlements: Bool = true
    var isPro: Bool = false
    var isTrialActive: Bool = false
    var trialDaysRemaining: Int = 0
    var product: Product? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let productID = "dev.fotiospongas.liftoff.pro"
    private let trialDuration: TimeInterval = 7 * 24 * 3600 // 7 μέρες
    private let trialKey = "picksyProTrialStartDate"
    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        checkTrial()
        Task {
            await loadProduct()
            await checkEntitlements()
        }
    }

    // MARK: - Trial

    /// Ξεκινάει το 7-day Pro trial.
    /// Αποθηκεύεται στο Keychain — παραμένει ακόμα και μετά τη διαγραφή.
    func startTrial() {
        guard !KeychainHelper.exists(trialKey) else { return } // Ένα trial μόνο
        KeychainHelper.save(trialKey, date: Date())
        checkTrial()
    }

    /// Ελέγχει αν το trial είναι ενεργό.
    func checkTrial() {
        guard let trialStart = KeychainHelper.loadDate(trialKey) else {
            isTrialActive = false
            trialDaysRemaining = 0
            updateProStatus()
            return
        }

        let elapsed = Date().timeIntervalSince(trialStart)
        let remaining = trialDuration - elapsed

        if remaining > 0 {
            isTrialActive = true
            trialDaysRemaining = max(1, Int(ceil(remaining / 86400)))
        } else {
            isTrialActive = false
            trialDaysRemaining = 0
        }

        updateProStatus()
    }

    /// Ελέγχει αν το trial έχει ήδη χρησιμοποιηθεί ποτέ.
    var hasUsedTrial: Bool {
        return KeychainHelper.exists(trialKey)
    }

    private func updateProStatus() {
        if !isPro {
            isPro = isTrialActive
        }
    }

    // MARK: - StoreKit

    @MainActor
    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {
            print("Could not load product: \(error.localizedDescription)")
        }
    }

    @MainActor
    func purchasePro() async {
        if product == nil {
            isLoading = true
            await loadProduct()
            isLoading = false
        }

        guard let product else {
            errorMessage = localizedString(
                en: "Please try again in a moment.",
                gr: "Παρακαλώ δοκίμασε ξανά σε λίγο.",
                de: "Bitte versuche es gleich erneut."
            )
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verify(verification)
                isPro = true
                isTrialActive = false
                await transaction.finish()
            case .pending: break
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            errorMessage = localizedString(
                en: "Purchase failed: \(error.localizedDescription)",
                gr: "Αποτυχία αγοράς: \(error.localizedDescription)",
                de: "Kauf fehlgeschlagen: \(error.localizedDescription)"
            )
        }
    }

    @MainActor
    func restorePurchase() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            errorMessage = localizedString(
                en: "Restore failed: \(error.localizedDescription)",
                gr: "Αποτυχία επαναφοράς: \(error.localizedDescription)",
                de: "Wiederherstellung fehlgeschlagen: \(error.localizedDescription)"
            )
        }
    }

    @MainActor
    private func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if let tx = try? verify(result), tx.productID == productID {
                isPro = true
                isTrialActive = false
                isCheckingEntitlements = false
                return
            }
        }
        // Αν δεν έχει αγοράσει, ελέγχει το trial
        checkTrial()
        isCheckingEntitlements = false
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await MainActor.run {
                        ProManager.shared.isPro = true
                        ProManager.shared.isTrialActive = false
                    }
                    await tx.finish()
                }
            }
        }
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw ProError.failedVerification
        case .verified(let safe): return safe
        }
    }

    private func localizedString(en: String, gr: String, de: String) -> String {
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        switch language {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Pro features list (EN/GR/DE)

    static let proFeatures: [(icon: String, titleEN: String, titleGR: String, titleDE: String, descEN: String, descGR: String, descDE: String)] = [
        ("square.grid.3x3.fill",
         "Heatmap", "Χάρτης θερμότητας", "Heatmap",
         "See your worst hours and track improvement",
         "Δες τις χειρότερες ώρες σου και παρακολούθησε τη βελτίωσή σου",
         "Sieh deine schlechtesten Stunden und verfolge deine Verbesserung"),

        ("gift",
         "Rewards", "Επιβραβεύσεις", "Belohnungen",
         "Unlock quote packs, badges, and gift codes",
         "Ξεκλείδωσε πακέτα quotes, badges και κωδικούς δώρων",
         "Schalte Zitatpakete, Abzeichen und Geschenkcodes frei"),

        ("text.quote",
         "Quote packs", "Πακέτα quotes", "Zitatpakete",
         "Stoic, humor, and philosophy collections",
         "Συλλογές στωικισμού, χιούμορ και φιλοσοφίας",
         "Stoische, humorvolle und philosophische Sammlungen"),

        ("chart.line.uptrend.xyaxis",
         "Monthly reports", "Μηνιαίες αναφορές", "Monatsberichte",
         "Track your progress over weeks and months",
         "Παρακολούθησε την πρόοδό σου σε εβδομάδες και μήνες",
         "Verfolge deinen Fortschritt über Wochen und Monate"),

        ("person.2",
         "Pay it forward", "Πρόσφερέ το", "Weitergeben",
         "Share Picksy and gift a friend 7 days of Pro",
         "Μοιράσου το Picksy και χάρισε σε φίλο 7 μέρες Pro",
         "Teile Picksy und schenke einem Freund 7 Tage Pro"),

        ("paintpalette",
         "Themes", "Θέματα", "Designs",
         "Custom colors and app icons",
         "Προσαρμοσμένα χρώματα και εικονίδια",
         "Benutzerdefinierte Farben und App-Symbole"),
    ]
}

enum ProError: Error {
    case failedVerification
}

