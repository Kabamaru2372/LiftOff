//
//  ProManager.swift
//  LiftOff
//
//  Created by Fotios Pongas on 24.03.26.
//
//  Διαχειρίζεται αν ο χρήστης έχει LiftOff Pro ή όχι.
//  Συνδεδεμένο με StoreKit 2 για πραγματικό purchase.
//

import Foundation
import SwiftUI
import StoreKit

@Observable
class ProManager {

    static let shared = ProManager()

    // Public state
    var isCheckingEntitlements: Bool = true
    var isPro: Bool = false
    var product: Product? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let productID = "dev.fotiospongas.liftoff.pro"
    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProduct()
            await checkEntitlements()
        }
    }

    // MARK: - Load product

    @MainActor
    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {
            errorMessage = "Δεν ήταν δυνατή η φόρτωση: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    @MainActor
    func purchasePro() async {
        guard let product else {
            errorMessage = "Το προϊόν δεν είναι διαθέσιμο."
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
                await transaction.finish()
            case .pending: break        // γονική έγκριση
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            errorMessage = "Αποτυχία αγοράς: \(error.localizedDescription)"
        }
    }

    // MARK: - Restore

    @MainActor
    func restorePurchase() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            errorMessage = "Αποτυχία επαναφοράς: \(error.localizedDescription)"
        }
    }

    // MARK: - Check entitlements on launch

    @MainActor
    private func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if let tx = try? verify(result), tx.productID == productID {
                isPro = true
                isCheckingEntitlements = false
                return
            }
        }
        isPro = false
        isCheckingEntitlements = false
    }

    // MARK: - Background transaction listener (Swift 6 safe)

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await MainActor.run {
                        ProManager.shared.isPro = true
                    }
                    await tx.finish()
                }
            }
        }
    }

    // MARK: - Verify

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw ProError.failedVerification
        case .verified(let safe): return safe
        }
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Pro features list

    static let proFeatures: [(icon: String, titleEN: String, titleGR: String, descEN: String, descGR: String)] = [
        ("square.grid.3x3.fill", "Heatmap", "Χάρτης θερμότητας",
         "See your worst hours and track improvement",
         "Δες τις χειρότερες ώρες σου και παρακολούθησε τη βελτίωσή σου"),
        ("gift", "Rewards", "Επιβραβεύσεις",
         "Unlock quote packs, badges, and gift codes",
         "Ξεκλείδωσε πακέτα quotes, badges και κωδικούς δώρων"),
        ("text.quote", "Quote packs", "Πακέτα quotes",
         "Stoic, humor, and philosophy collections",
         "Συλλογές στωικισμού, χιούμορ και φιλοσοφίας"),
        ("chart.line.uptrend.xyaxis", "Monthly reports", "Μηνιαίες αναφορές",
         "Track your progress over weeks and months",
         "Παρακολούθησε την πρόοδό σου σε εβδομάδες και μήνες"),
        ("person.2", "Pay it forward", "Πρόσφερέ το",
         "Gift LiftOff Pro to friends when you improve",
         "Χάρισε LiftOff Pro σε φίλους όταν βελτιώνεσαι"),
        ("paintpalette", "Themes", "Θέματα",
         "Custom colors and app icons",
         "Προσαρμοσμένα χρώματα και εικονίδια"),
    ]
}

enum ProError: Error {
    case failedVerification
}

