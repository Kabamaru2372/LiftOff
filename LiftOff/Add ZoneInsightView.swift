//
//  ZoneInsightView.swift
//  Picksy
//
//  Created by Fotios Pongas on 04.05.2026
//
//  Modal sheet που εμφανίζεται όταν ο χρήστης πατάει zone notification.
//  Δείχνει τα τρέχοντα στατιστικά + alternative activity που θα μπορούσε
//  να κάνει στον χρόνο που ξόδεψε στο κινητό.
//
//  Architecture:
//  - Παρουσιάζεται ως .sheet(isPresented:) από το ContentView ή το tab root
//  - Detents: .medium (περίπου 50% ύψος) με drag indicator
//  - Hint text στο κάτω μέρος για το swipe-to-close
//

import SwiftUI

struct ZoneInsightView: View {

    // MARK: - Inputs

    /// Number of pickups που τριγκάρισε το zone notification
    let pickupCount: Int

    /// The zone for this pickup count
    let zone: PickupZone

    /// Closure to dismiss the sheet
    let onDismiss: () -> Void

    // MARK: - State

    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @State private var currentActivity: AlternativeActivity

    // MARK: - Init

    init(pickupCount: Int, zone: PickupZone, onDismiss: @escaping () -> Void) {
        self.pickupCount = pickupCount
        self.zone = zone
        self.onDismiss = onDismiss
        self._currentActivity = State(
            initialValue: AlternativeActivityBank.pickActivity(forPickups: pickupCount)
        )
    }

    // MARK: - Computed

    private var estimatedMinutes: Int {
        AlternativeActivityBank.totalMinutes(forPickups: pickupCount)
    }

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {

            // Drag indicator (visual hint for swipe-to-close)
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            // Zone badge
            HStack(spacing: 6) {
                Circle()
                    .fill(zone.color)
                    .frame(width: 8, height: 8)
                Text(zone.displayName(language: appLanguage))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(zone.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(zone.color.opacity(0.15))
            )

            // Big pickup count
            VStack(spacing: 4) {
                Text("\(pickupCount)")
                    .font(.system(size: 64, weight: .light, design: .rounded))
                    .foregroundColor(.primary)

                Text(t("pickups today", "σηκώματα σήμερα", "Griffe heute"))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            // Estimated time card
            VStack(spacing: 4) {
                Text(t("Estimated time", "Εκτιμώμενος χρόνος", "Geschätzte Zeit"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(formattedTime(minutes: estimatedMinutes))
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .padding(.horizontal, 24)

            // Activity suggestion card
            VStack(spacing: 8) {
                Text(t(
                    "In that time, you could",
                    "Σε αυτόν τον χρόνο θα μπορούσες να",
                    "In dieser Zeit könntest du"
                ))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

                Text(currentActivity.description(language: appLanguage))
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .id(currentActivity.descriptionEN) // Force re-render on change
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(zone.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.3), value: currentActivity.descriptionEN)

            Spacer()

            // Action buttons
            HStack(spacing: 10) {
                // Another idea button
                Button(action: pickAnotherActivity) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .medium))
                        Text(t("Another idea", "Άλλη ιδέα", "Andere Idee"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }

                // Got it button
                Button(action: onDismiss) {
                    Text(t("Got it", "Κατάλαβα", "Verstanden"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary)
                        )
                }
            }
            .padding(.horizontal, 24)

            // Swipe hint
            Text(t(
                "Swipe down to close",
                "Σύρε προς τα κάτω για κλείσιμο",
                "Nach unten wischen zum Schließen"
            ))
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundColor(.secondary.opacity(0.7))
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Actions

    private func pickAnotherActivity() {
        var newActivity: AlternativeActivity

        // Try to get a different activity (max 5 attempts)
        var attempts = 0
        repeat {
            newActivity = AlternativeActivityBank.pickActivity(forPickups: pickupCount)
            attempts += 1
        } while newActivity.descriptionEN == currentActivity.descriptionEN && attempts < 5

        withAnimation(.easeInOut(duration: 0.3)) {
            currentActivity = newActivity
        }
    }

    // MARK: - Formatting

    private func formattedTime(minutes: Int) -> String {
        if minutes < 60 {
            return t(
                "~\(minutes) min",
                "~\(minutes) λεπτά",
                "~\(minutes) Min."
            )
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return t(
                    "~\(hours)h",
                    "~\(hours) ώρες",
                    "~\(hours) Std."
                )
            } else {
                return t(
                    "~\(hours)h \(mins)m",
                    "~\(hours)ώ \(mins)λ",
                    "~\(hours)h \(mins)m"
                )
            }
        }
    }
}

#Preview {
    ZoneInsightView(
        pickupCount: 153,
        zone: .heavy,
        onDismiss: {}
    )
}
