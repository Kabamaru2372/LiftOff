//
//  ActivityPreferencesView.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.04.2026
//
//  UI για επιλογή activity categories.
//  Χρησιμοποιείται σε onboarding (inline) και settings (sheet).

import SwiftUI

struct ActivityPreferencesView: View {
    @Environment(ActivityPreferences.self) var preferences
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    var showPrivacyBadge: Bool = true

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Helper text
            Text(t(
                "Pick what fits you. We'll suggest activities from your selections.",
                "Διάλεξε ό,τι σου ταιριάζει. Θα προτείνουμε δραστηριότητες από τις επιλογές σου.",
                "Wähle, was zu dir passt. Wir schlagen Aktivitäten aus deiner Auswahl vor."
            ))
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
            .lineSpacing(3)

            // Privacy badge
            if showPrivacyBadge {
                PrivacyBadge(style: .banner)
            }

            // Categories grid
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ActivityCategory.allCases) { category in
                    categoryButton(category)
                }
            }

            // Quick actions
            HStack(spacing: 12) {
                Button(action: { preferences.selectAll() }) {
                    Text(t("Select all", "Όλα", "Alle"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.blue)
                }

                Text("•").foregroundColor(.secondary)

                Button(action: { preferences.clearAll() }) {
                    Text(t("Clear all", "Κανένα", "Keine"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.blue)
                }

                Spacer()

                Text(t(
                    "\(preferences.selected.count) selected",
                    "\(preferences.selected.count) επιλεγμένα",
                    "\(preferences.selected.count) ausgewählt"
                ))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            }
            .padding(.top, 4)

            // Info message
            if preferences.selected.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text(t(
                        "No selection means all activities are active.",
                        "Χωρίς επιλογή, όλες οι δραστηριότητες είναι ενεργές.",
                        "Ohne Auswahl sind alle Aktivitäten aktiv."
                    ))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    private func categoryButton(_ category: ActivityCategory) -> some View {
        let isSelected = preferences.isSelected(category)

        return Button(action: { preferences.toggle(category) }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.emoji)
                        .font(.system(size: 22))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                }

                Text(category.title(language: appLanguage))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(category.description(language: appLanguage))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.10) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                    )
            )
        }
    }
}

// MARK: - Standalone Sheet για Settings

struct ActivityPreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ActivityPreferencesView(showPrivacyBadge: true)
                    .padding(20)
            }
            .navigationTitle(t("Activity preferences", "Προτιμήσεις", "Präferenzen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text(t("Done", "Τέλος", "Fertig"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                }
            }
        }
    }
}

#Preview {
    ActivityPreferencesSheet()
        .environment(ActivityPreferences())
}
