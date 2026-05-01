//
//  PrivacyBadge.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.04.2026
//
//  Reusable component που υπενθυμίζει στον χρήστη ότι τα δεδομένα
//  μένουν στη συσκευή του. Χρησιμοποιείται σε screens που ζητάνε
//  πληροφορίες.

import SwiftUI

struct PrivacyBadge: View {
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    var style: Style = .compact

    enum Style {
        case compact   // μικρό, inline
        case banner    // πιο προβεβλημένο, για onboarding
    }

    private var message: String {
        switch appLanguage {
        case "Ελληνικά":
            return "Όλα τα δεδομένα μένουν στη συσκευή σου. Τίποτα δεν μοιράζεται ή πωλείται."
        case "Deutsch":
            return "Alle Daten bleiben auf deinem Gerät. Nichts wird geteilt oder verkauft."
        default:
            return "All data stays on your device. Nothing is shared or sold."
        }
    }

    var body: some View {
        switch style {
        case .compact:
            compactView
        case .banner:
            bannerView
        }
    }

    private var compactView: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 11))
                .foregroundColor(.green)
            Text(message)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.08))
        )
    }

    private var bannerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16))
                .foregroundColor(.green)

            Text(message)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        PrivacyBadge(style: .compact)
        PrivacyBadge(style: .banner)
    }
    .padding()
}

