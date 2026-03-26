//
//  PaywallView.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
// Η οθόνη αγοράς LiftOff+ — minimal, zen, honest.

//
//  PaywallView.swift
//  LiftOff
//
// Η οθόνη αγοράς LiftOff Pro — minimal, zen, honest.

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(ProManager.self) var proManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @Environment(\.dismiss) private var dismiss

    private var isGreek: Bool { appLanguage == "Ελληνικά" }

    @State private var showThankYou: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                        .padding(.top, 40)

                    Text("LiftOff Pro")
                        .font(.system(size: 28, weight: .medium, design: .rounded))

                    Text(isGreek
                         ? "Ξεκλείδωσε τα πάντα. Μία φορά."
                         : "Unlock everything. Once.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                // Features list
                VStack(spacing: 0) {
                    ForEach(ProManager.proFeatures.indices, id: \.self) { index in
                        let feature = ProManager.proFeatures[index]

                        HStack(spacing: 14) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(isGreek ? feature.titleGR : feature.titleEN)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))

                                Text(isGreek ? feature.descGR : feature.descEN)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 12)

                        if index < ProManager.proFeatures.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray5), lineWidth: 0.5)
                        )
                )

                // Price — shows live from StoreKit if loaded, fallback to €4.99
                VStack(spacing: 6) {
                    Text(proManager.product?.displayPrice ?? "€4.99")
                        .font(.system(size: 36, weight: .medium, design: .rounded))

                    Text(isGreek
                         ? "Μία φορά, για πάντα. Χωρίς συνδρομές."
                         : "One time, forever. No subscriptions.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                // Purchase button
                Button(action: {
                    Task { await proManager.purchasePro() }
                }) {
                    Group {
                        if proManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isGreek ? "Απόκτησε το LiftOff Pro" : "Get LiftOff Pro")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.blue)
                    )
                }
                .disabled(proManager.isLoading || proManager.product == nil)

                // Error message
                if let error = proManager.errorMessage {
                    Text(error)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // Restore
                Button(action: {
                    Task { await proManager.restorePurchase() }
                }) {
                    Text(isGreek ? "Επαναφορά αγοράς" : "Restore purchase")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                // Honest note
                Text(isGreek
                     ? "Το LiftOff δημιουργήθηκε για να σε βοηθήσει, όχι να σου πάρει χρήματα. Η δωρεάν έκδοση κάνει τη δουλειά της. Το Pro είναι για όσους θέλουν να πάνε ένα βήμα παραπάνω."
                     : "LiftOff was built to help you, not to take your money. The free version works great. Pro is for those who want to go the extra mile.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .onChange(of: proManager.isPro) { _, newValue in
            if newValue { showThankYou = true }
        }
        .alert(
            isGreek ? "Ευχαριστούμε!" : "Thank you!",
            isPresented: $showThankYou
        ) {
            Button("OK") { dismiss() }
        } message: {
            Text(isGreek
                 ? "Καλωσήρθες στο LiftOff Pro! Όλα τα features είναι ξεκλειδωμένα."
                 : "Welcome to LiftOff Pro! All features are now unlocked.")
        }
    }
}

#Preview {
    PaywallView()
        .environment(ProManager.shared)
}
