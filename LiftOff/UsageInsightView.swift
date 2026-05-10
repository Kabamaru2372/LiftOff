//
//  UsageInsightView.swift
//  Picksy
//
//  Created by Fotios Pongas on 05.05.2026
//
//  v1.6 UPDATE - Fixed buttons visibility σε dark mode.
//

import SwiftUI

struct UsageInsightView: View {

    let level: Int
    let onSeeDetails: () -> Void
    let onDismiss: () -> Void

    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Properties

    private var isTestMode: Bool {
        UsageThresholdManager.isTestMode
    }

    private var displayValue: Int {
        if isTestMode {
            switch level {
            case 1: return 5
            case 2: return 10
            case 3: return 15
            default: return 0
            }
        } else {
            return level
        }
    }

    private var unitLabel: String {
        if isTestMode {
            return t("minutes", "λεπτά", "Minuten")
        } else {
            return t("hours", "ώρες", "Stunden")
        }
    }

    private var levelColor: Color {
        switch level {
        case 1: return Color.yellow
        case 2: return Color.orange
        case 3: return Color.red
        default: return Color.gray
        }
    }

    private var levelEmoji: String {
        switch level {
        case 1: return "👋"
        case 2: return "💭"
        case 3: return "⚠️"
        default: return "📱"
        }
    }

    private var levelLabel: String {
        switch level {
        case 1: return t("Heads up", "Φιλική υπενθύμιση", "Hinweis")
        case 2: return t("Take a moment", "Σκέψου το", "Pause")
        case 3: return t("Time for change", "Καιρός για αλλαγή", "Zeit für Änderung")
        default: return ""
        }
    }

    /// Solid contrasting color για το primary button (dismiss).
    /// Σε dark mode: λευκό φόντο + μαύρο κείμενο
    /// Σε light mode: μαύρο φόντο + λευκό κείμενο
    private var primaryButtonBackground: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    private var primaryButtonForeground: Color {
        colorScheme == .dark ? Color.black : Color.white
    }

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    private var notificationTitle: String {
        switch (level, appLanguage) {
        case (1, "Ελληνικά"): return "Έλα να τα πούμε! 👋"
        case (1, "Deutsch"):  return "Kurze Pause? 👋"
        case (1, _):          return "Hey, quick check-in! 👋"

        case (2, "Ελληνικά"): return "Σκέψου το λίγο 💭"
        case (2, "Deutsch"):  return "Denk mal nach 💭"
        case (2, _):          return "Take a moment 💭"

        case (3, "Ελληνικά"): return "Καιρός για αλλαγή ⚠️"
        case (3, "Deutsch"):  return "Zeit für eine Änderung ⚠️"
        case (3, _):          return "Time for a change ⚠️"

        default: return "Picksy"
        }
    }

    private var notificationBody: String {
        switch (level, appLanguage) {

        case (1, "Ελληνικά"):
            return "Πέρασες \(displayValue) \(unitLabel) στις tracked εφαρμογές σήμερα. Ένα μικρό διάλειμμα δεν θα ήταν κακή ιδέα. ☕️"
        case (1, "Deutsch"):
            return "Du hast \(displayValue) \(unitLabel) in den getrackten Apps verbracht. Eine kleine Pause könnte gut tun. ☕️"
        case (1, _):
            return "You've spent \(displayValue) \(unitLabel) on tracked apps today. A small break wouldn't hurt. ☕️"

        case (2, "Ελληνικά"):
            return "\(displayValue) \(unitLabel) στις tracked εφαρμογές. Δεν είναι λίγο, ε; Σήκωσε το βλέμμα σου για 5 λεπτά. 🌿"
        case (2, "Deutsch"):
            return "\(displayValue) \(unitLabel) in den getrackten Apps. Das ist nicht wenig. Schau mal kurz auf für 5 Minuten. 🌿"
        case (2, _):
            return "\(displayValue) \(unitLabel) on tracked apps. That's quite a lot. Look up for 5 minutes. 🌿"

        case (3, "Ελληνικά"):
            return "\(displayValue) \(unitLabel) στις tracked εφαρμογές... αυτό είναι πραγματικά πολύ. Κλείσε το κινητό για λίγο και κάνε κάτι άλλο. Ο εαυτός σου θα σε ευχαριστήσει. 🌅"
        case (3, "Deutsch"):
            return "\(displayValue) \(unitLabel) in den getrackten Apps... das ist wirklich viel. Leg das Handy für eine Weile weg. Dein Ich wird es dir danken. 🌅"
        case (3, _):
            return "\(displayValue) \(unitLabel) on tracked apps... that's really a lot. Put down the phone for a while. Your future self will thank you. 🌅"

        default:
            return "Time check: \(displayValue) \(unitLabel) on tracked apps."
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 18) {
                    // Level badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(levelColor)
                            .frame(width: 8, height: 8)
                        Text(levelLabel)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(levelColor)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(levelColor.opacity(0.15))
                    )

                    Text(levelEmoji)
                        .font(.system(size: 56))

                    Text(notificationTitle)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(notificationBody)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 4) {
                        Text(t("Time today", "Χρόνος σήμερα", "Heute"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Text("\(displayValue) \(unitLabel)")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(levelColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                .padding(.bottom, 20)
            }

            // Action buttons με σωστά χρώματα για light/dark mode
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    // Secondary button - "Δες λεπτομέρειες"
                    Button(action: onSeeDetails) {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 13, weight: .medium))
                            Text(t("See details", "Δες λεπτομέρειες", "Details"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                    }

                    // Primary button - "Κατάλαβα" με σωστό contrast
                    Button(action: onDismiss) {
                        Text(t("Got it", "Κατάλαβα", "Verstanden"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(primaryButtonForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(primaryButtonBackground)
                            )
                    }
                }
                .padding(.horizontal, 24)

                Text(t(
                    "Swipe down to close",
                    "Σύρε προς τα κάτω για κλείσιμο",
                    "Nach unten wischen zum Schließen"
                ))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.bottom, 16)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Data Model

struct UsageInsightData: Identifiable, Equatable {
    let id = UUID()
    let level: Int
}

#Preview("Level 1") {
    UsageInsightView(level: 1, onSeeDetails: {}, onDismiss: {})
}

#Preview("Level 2") {
    UsageInsightView(level: 2, onSeeDetails: {}, onDismiss: {})
}

#Preview("Level 3") {
    UsageInsightView(level: 3, onSeeDetails: {}, onDismiss: {})
}

