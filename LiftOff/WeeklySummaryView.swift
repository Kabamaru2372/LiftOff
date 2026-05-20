//
//  WeeklySummaryView.swift
//  Picksy
//
//  Created by Fotios Pongas on 22.04.2026

import SwiftUI

struct WeeklySummaryView: View {
    let summary: WeeklySummary
    @Environment(\.dismiss) private var dismiss
    @Environment(ProManager.self) private var proManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    /// Callback fired when the locked Pro card is tapped — caller presents the paywall.
    var onUnlockTap: (() -> Void)? = nil

    @State private var shareItem: ShareImageItem? = nil
    @State private var showStats: Bool = false

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {

                    // Header
                    VStack(spacing: 8) {
                        Text("📊")
                            .font(.system(size: 60))

                        Text(t("Your week", "Η εβδομάδα σου", "Deine Woche"))
                            .font(.system(size: 32, weight: .medium, design: .rounded))

                        Text(t("A look back at the last 7 days", "Μια ματιά στις τελευταίες 7 μέρες", "Ein Blick auf die letzten 7 Tage"))
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    if showStats {
                        // ALWAYS shown — Total pickups headline
                        summaryCard(
                            icon: "hand.raised.fill",
                            iconColor: .blue,
                            title: t("Total pickups", "Συνολικά σηκώματα", "Griffe gesamt"),
                            value: "\(summary.totalPickups)",
                            subtitle: t(
                                "\(summary.dailyAverage) per day on average",
                                "\(summary.dailyAverage) ανά μέρα κατά μέσο όρο",
                                "\(summary.dailyAverage) pro Tag im Durchschnitt"
                            )
                        )
                        .transition(.slide.combined(with: .opacity))

                        if proManager.isPro {
                            // PRO — Best & Worst day comparison
                            HStack(spacing: 12) {
                                miniCard(
                                    emoji: "🏆",
                                    title: t("Best day", "Καλύτερη", "Bester Tag"),
                                    value: summary.bestDay.name,
                                    subtitle: "\(summary.bestDay.pickups) " + t("pickups", "σηκώματα", "Griffe")
                                )

                                miniCard(
                                    emoji: "📱",
                                    title: t("Worst day", "Χειρότερη", "Schlechtester Tag"),
                                    value: summary.worstDay.name,
                                    subtitle: "\(summary.worstDay.pickups) " + t("pickups", "σηκώματα", "Griffe")
                                )
                            }
                            .transition(.slide.combined(with: .opacity))

                            // PRO — Mood overview
                            if summary.daysWithCheckIn > 0 {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(t("How you felt", "Πώς ένιωσες", "Wie du dich gefühlt hast"))
                                        .font(.system(size: 16, weight: .medium, design: .rounded))

                                    HStack(spacing: 16) {
                                        moodPill(emoji: "🟢", count: summary.greatDays, label: t("Great", "Τέλεια", "Großartig"))
                                        moodPill(emoji: "🟡", count: summary.okayDays, label: t("Okay", "Μέτρια", "Okay"))
                                        moodPill(emoji: "🔴", count: summary.roughDays, label: t("Rough", "Δύσκολα", "Schwierig"))
                                    }
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                                .transition(.slide.combined(with: .opacity))
                            }

                            // PRO — Streak card
                            if summary.streak > 0 {
                                summaryCard(
                                    icon: "flame.fill",
                                    iconColor: .orange,
                                    title: t("Current streak", "Τρέχον σερί", "Aktuelle Serie"),
                                    value: "\(summary.streak)",
                                    subtitle: t(
                                        "days under your goal",
                                        "μέρες κάτω από τον στόχο",
                                        "Tage unter deinem Ziel"
                                    )
                                )
                                .transition(.slide.combined(with: .opacity))
                            }

                            // PRO — Personalized motivational message
                            Text(motivationalMessage)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .transition(.opacity)
                        } else {
                            // FREE — Locked Pro card showing what they unlock
                            lockedProCard
                                .transition(.slide.combined(with: .opacity))
                        }

                        // ALWAYS — Share button (drives organic growth)
                        Button(action: { generateAndShare() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                                Text(t("Share your week", "Μοιράσου την εβδομάδα σου", "Deine Woche teilen"))
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue))
                        }
                        .padding(.horizontal, 24)
                        .transition(.opacity)

                        // Close button
                        Button(action: { dismiss() }) {
                            Text(t("Close", "Κλείσιμο", "Schließen"))
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 24)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
                showStats = true
            }
        }
        .sheet(item: $shareItem) { item in
            WeeklyShareSheet(image: item.image, language: appLanguage)
        }
    }

    // MARK: - Motivational Message

    private var motivationalMessage: String {
        if summary.totalPickups == 0 {
            return t(
                "Start tracking this week to see your progress!",
                "Ξεκίνα να παρακολουθείς αυτή την εβδομάδα για να δεις την πρόοδό σου!",
                "Fang diese Woche an zu tracken, um deinen Fortschritt zu sehen!"
            )
        } else if summary.dailyAverage <= 10 {
            return t(
                "Incredible discipline! You're mastering your relationship with your phone. 🏆",
                "Απίστευτη πειθαρχία! Κατακτάς τη σχέση σου με το κινητό. 🏆",
                "Unglaubliche Disziplin! Du meisterst deine Beziehung zum Handy. 🏆"
            )
        } else if summary.dailyAverage <= 20 {
            return t(
                "Solid week! You're on the right track. Keep building the habit. 💪",
                "Στέρεη εβδομάδα! Είσαι στον σωστό δρόμο. Συνέχισε να χτίζεις τη συνήθεια. 💪",
                "Solide Woche! Du bist auf dem richtigen Weg. Bau die Gewohnheit weiter auf. 💪"
            )
        } else {
            return t(
                "Awareness is the first step. Next week is a fresh start. You've got this.",
                "Η επίγνωση είναι το πρώτο βήμα. Η επόμενη εβδομάδα ξεκινάει από μηδέν. Τα καταφέρνεις.",
                "Bewusstsein ist der erste Schritt. Nächste Woche ist ein Neustart. Du schaffst das."
            )
        }
    }

    // MARK: - Locked Pro Card (Free users)

    private var lockedProCard: some View {
        Button(action: {
            // Dismiss the weekly summary first, then trigger paywall after
            // the cover animation so the two presentations don't stack awkwardly.
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onUnlockTap?()
            }
        }) {
            VStack(spacing: 20) {

                // Header
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                    Text(t(
                        "Unlock your full weekly story",
                        "Ξεκλείδωσε όλη την εβδομαδιαία ιστορία",
                        "Schalte deine volle Wochengeschichte frei"
                    ))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                }

                // Feature list
                VStack(alignment: .leading, spacing: 12) {
                    proFeatureRow(icon: "chart.bar.xaxis", text: t(
                        "Best & worst day comparison",
                        "Σύγκριση καλύτερης & χειρότερης μέρας",
                        "Bester & schlechtester Tag im Vergleich"
                    ))
                    proFeatureRow(icon: "face.smiling", text: t(
                        "Mood patterns across your week",
                        "Μοτίβα διάθεσης μέσα στην εβδομάδα",
                        "Stimmungsmuster durch die Woche"
                    ))
                    proFeatureRow(icon: "flame.fill", text: t(
                        "Streak progress and motivation",
                        "Πρόοδος σερί και κίνητρα",
                        "Serien-Fortschritt und Motivation"
                    ))
                    proFeatureRow(icon: "sparkle", text: t(
                        "Personalized weekly insights",
                        "Εξατομικευμένα εβδομαδιαία insights",
                        "Personalisierte Wocheneinblicke"
                    ))
                }
                .padding(.horizontal, 4)

                // CTA
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill").font(.system(size: 14))
                    Text(t(
                        "Unlock with Picksy Pro",
                        "Ξεκλείδωσε με Picksy Pro",
                        "Mit Picksy Pro freischalten"
                    ))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.blue))
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        }
        .buttonStyle(.plain)
    }

    private func proFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    // MARK: - Helper Views

    private func summaryCard(icon: String, iconColor: Color, title: String, value: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(iconColor)
                .frame(width: 56, height: 56)
                .background(Circle().fill(iconColor.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
    }

    private func miniCard(emoji: String, title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji).font(.system(size: 32))
            Text(title)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .rounded))
            Text(subtitle)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
    }

    private func moodPill(emoji: String, count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 22))
            Text("\(count)")
                .font(.system(size: 18, weight: .medium, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Share

    @MainActor
    private func generateAndShare() {
        let card = WeeklyShareCardView(summary: summary, language: appLanguage)
            .frame(width: 400, height: 700)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            shareItem = ShareImageItem(image: image)
        }
    }
}

// MARK: - Weekly Share Card

struct WeeklyShareCardView: View {
    let summary: WeeklySummary
    let language: String

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch language {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    var body: some View {
        VStack(spacing: 20) {

            // Header
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                Text("Picksy")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                Spacer()
                Text(t("My week", "Η εβδομάδα μου", "Meine Woche"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)

            Spacer()

            // Big number
            VStack(spacing: 8) {
                Text("📊").font(.system(size: 50))
                Text("\(summary.totalPickups)")
                    .font(.system(size: 80, weight: .medium, design: .rounded))
                    .foregroundColor(.blue)
                Text(t("total pickups this week", "σηκώματα αυτή την εβδομάδα", "Griffe diese Woche"))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Stats grid
            VStack(spacing: 12) {
                HStack {
                    shareStat(label: t("Daily avg", "Μέσος/ημέρα", "Ø pro Tag"), value: "\(summary.dailyAverage)")
                    Divider().frame(height: 40)
                    shareStat(label: t("Best day", "Καλύτερη", "Bester Tag"), value: "\(summary.bestDay.pickups)")
                    Divider().frame(height: 40)
                    shareStat(label: t("Streak", "Σερί", "Serie"), value: "\(summary.streak)")
                }
            }
            .padding(.horizontal, 28)

            if summary.daysWithCheckIn > 0 {
                HStack(spacing: 20) {
                    if summary.greatDays > 0 {
                        Text("🟢 \(summary.greatDays)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    if summary.okayDays > 0 {
                        Text("🟡 \(summary.okayDays)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    if summary.roughDays > 0 {
                        Text("🔴 \(summary.roughDays)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                }
                .padding(.top, 8)
            }

            Spacer()

            // Footer
            VStack(spacing: 4) {
                Text(t("Track your phone habits", "Παρακολούθησε τις συνήθειές σου", "Verfolge deine Handy-Gewohnheiten"))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                Text("apps.apple.com/app/picksy-be-present")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.05), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func shareStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .medium, design: .rounded))
            Text(label)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Weekly Share Sheet

struct WeeklyShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    let language: String

    private var caption: String {
        switch language {
        case "Ελληνικά":
            return "Η εβδομάδα μου στο Picksy! 📊 Κατέβασέ το: https://apps.apple.com/app/picksy-be-present/id6761116771"
        case "Deutsch":
            return "Meine Woche mit Picksy! 📊 Lade es herunter: https://apps.apple.com/app/picksy-be-present/id6761116771"
        default:
            return "My week with Picksy! 📊 Download it: https://apps.apple.com/app/picksy-be-present/id6761116771"
        }
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image, caption], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
