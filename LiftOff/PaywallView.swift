//
//  PaywallView.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.03.26.

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(ProManager.self) var proManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @Environment(\.dismiss) private var dismiss

    @State private var showThankYou: Bool = false

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Close button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                    .padding(.trailing, 8)
                    .padding(.top, 16)
                }

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)

                    Text("Picksy Pro")
                        .font(.system(size: 28, weight: .medium, design: .rounded))

                    Text(t("Unlock everything. Once.",
                           "Ξεκλείδωσε τα πάντα. Μία φορά.",
                           "Alles freischalten. Einmalig."))
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
                                .background(Circle().fill(Color.blue.opacity(0.1)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(appLanguage == "Ελληνικά" ? feature.titleGR :
                                     appLanguage == "Deutsch" ? feature.titleDE : feature.titleEN)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))

                                Text(appLanguage == "Ελληνικά" ? feature.descGR :
                                     appLanguage == "Deutsch" ? feature.descDE : feature.descEN)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 12)

                        if index < ProManager.proFeatures.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 0.5))
                )

                // Price
                VStack(spacing: 6) {
                    Text(proManager.product?.displayPrice ?? "€4.99")
                        .font(.system(size: 36, weight: .medium, design: .rounded))

                    Text(t("One time, forever. No subscriptions.",
                           "Μία φορά, για πάντα. Χωρίς συνδρομές.",
                           "Einmalig, für immer. Kein Abo."))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                // Purchase button
                Button(action: { Task { await proManager.purchasePro() } }) {
                    Group {
                        if proManager.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(t("Get Picksy Pro", "Απόκτησε το Picksy Pro", "Picksy Pro kaufen"))
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
                }
                .disabled(proManager.isLoading)

                if let error = proManager.errorMessage {
                    Text(error)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // Restore
                Button(action: { Task { await proManager.restorePurchase() } }) {
                    Text(t("Restore purchase", "Επαναφορά αγοράς", "Kauf wiederherstellen"))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                // Honest note
                Text(t(
                    "Picksy was built to help you, not to take your money. The free version works great. Pro is for those who want to go the extra mile.",
                    "Το Picksy δημιουργήθηκε για να σε βοηθήσει, όχι να σου πάρει χρήματα. Η δωρεάν έκδοση κάνει τη δουλειά της. Το Pro είναι για όσους θέλουν να πάνε ένα βήμα παραπάνω.",
                    "Picksy wurde entwickelt, um dir zu helfen – nicht um dein Geld zu nehmen. Die kostenlose Version funktioniert hervorragend. Pro ist für alle, die einen Schritt weitergehen möchten."
                ))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: proManager.isPro) { _, newValue in
            if newValue { showThankYou = true }
        }
        .alert(t("Thank you!", "Ευχαριστούμε!", "Danke!"), isPresented: $showThankYou) {
            Button("OK") { dismiss() }
        } message: {
            Text(t(
                "Welcome to Picksy Pro! All features are now unlocked.",
                "Καλωσήρθες στο Picksy Pro! Όλα τα features είναι ξεκλειδωμένα.",
                "Willkommen bei Picksy Pro! Alle Funktionen sind jetzt freigeschaltet."
            ))
        }
    }
}

#Preview {
    PaywallView().environment(ProManager.shared)
}

