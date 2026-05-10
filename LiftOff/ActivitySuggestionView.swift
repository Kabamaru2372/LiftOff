//
//  ActivitySuggestionView.swift
//  Picksy
//
//  Created by Fotios Pongas on 10.05.2026
//
//  Sheet που εμφανίζεται όταν ο user πατάει "Τι να κάνω τώρα;"
//  Δείχνει 3 random activity suggestions με real links.
//

import SwiftUI

struct ActivitySuggestionView: View {

    let onDismiss: () -> Void

    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @Environment(\.colorScheme) private var colorScheme
    @State private var suggestions: [AlternativeActivity] = []

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Drag indicator
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // Header
            VStack(spacing: 6) {
                Text("✨")
                    .font(.system(size: 36))

                Text(t("What should I do?", "Τι να κάνω τώρα;", "Was soll ich tun?"))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text(t(
                    "Here are some ideas to get you off your phone",
                    "Μερικές ιδέες για να βάλεις κάτω το κινητό",
                    "Ein paar Ideen, um das Handy wegzulegen"
                ))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 20)

            // 3 Activity cards
            VStack(spacing: 12) {
                ForEach(suggestions.indices, id: \.self) { index in
                    ActivityCard(
                        activity: suggestions[index],
                        language: appLanguage,
                        index: index
                    )
                }
            }
            .padding(.horizontal, 24)

            // Shuffle button
            Button(action: shuffle) {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 13))
                    Text(t("Show me more ideas", "Δείξε μου άλλες ιδέες", "Mehr Ideen anzeigen"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(.secondary)
                .padding(.vertical, 12)
            }
            .padding(.top, 8)

            // Dismiss button
            Button(action: onDismiss) {
                Text(t("Got it, thanks!", "Ωραία, ευχαριστώ!", "Danke, verstanden!"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.white : Color.black)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            shuffle()
        }
    }

    private func shuffle() {
        suggestions = AlternativeActivityBank.pickEveningActivities(count: 3)
    }
}

// MARK: - Activity Card

struct ActivityCard: View {

    let activity: AlternativeActivity
    let language: String
    let index: Int

    @Environment(\.colorScheme) private var colorScheme

    private var cardEmoji: String {
        let emojis = ["🌿", "⚡", "🎯"]
        return emojis[index % emojis.count]
    }

    private var cardColor: Color {
        let colors: [Color] = [.green, .orange, .blue]
        return colors[index % colors.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 8) {
                Text(cardEmoji)
                    .font(.system(size: 20))

                Text(activity.description(language: language))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Duration badge
                Text("~\(activity.durationMinutes)m")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(cardColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(cardColor.opacity(0.12))
                    )
            }

            // Link button (αν υπάρχει)
            if let url = activity.link(language: language),
               let label = activity.linkLabel(language: language) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 11))
                        Text(label)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(cardColor)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

#Preview {
    ActivitySuggestionView(onDismiss: {})
}

