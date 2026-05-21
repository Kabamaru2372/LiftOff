// DashboardView.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026

import SwiftUI

struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

// Wrapper για να χρησιμοποιήσουμε fullScreenCover(item:) αντί για boolean
struct WeeklySummaryItem: Identifiable {
    let id = UUID()
    let summary: WeeklySummary
}

struct DashboardView: View {
    @Environment(DataStore.self) var store
    @Environment(CheckInManager.self) var checkInManager
    @Environment(WeeklySummaryManager.self) var weeklyManager
    @Environment(ProManager.self) var proManager
    @Environment(CorrelationStore.self) var correlationStore
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @AppStorage("dailyGoal") private var dailyGoal: Int = 15

    @State private var shareItem: ShareImageItem? = nil
    @State private var showCheckInSheet: Bool = false
    @State private var weeklySummaryItem: WeeklySummaryItem? = nil
    @State private var showPaywall: Bool = false

    private var lang: String { appLanguage }

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch lang {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    private var dayNames: [String] {
        switch lang {
        case "Ελληνικά": return ["Δευ", "Τρι", "Τετ", "Πεμ", "Παρ", "Σαβ", "Κυρ"]
        case "Deutsch": return ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        default: return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }
    }

    // Τελευταίες 7 μέρες με σωστή σειρά (παλαιότερο → σήμερα)
    private var moodDayNames: [String] {
        let calendar = Calendar.current
        var result: [String] = []
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -(6 - i), to: Date()) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            let index = (weekday + 5) % 7
            result.append(dayNames[index])
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header with Share button
                HStack {
                    Text("Picksy")
                        .font(.system(size: 24, weight: .medium, design: .rounded))

                    Spacer()

                    Button(action: { generateAndShare() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                            Text(t("Share", "Μοιράσου", "Teilen"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.blue))
                    }
                }
                .padding(.top, 20)

                // Today
                Text(t("Today", "Σήμερα", "Heute"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    StatCard(title: t("Pickups", "Σηκώματα", "Griffe"), value: "\(store.todayPickups)")
                    StatCard(title: t("Avg time", "Μέσος χρόνος", "Ø Zeit"), value: store.averageSessionLabel)
                }

                // Active Duel Banner
                DuelBannerView()
                    .environment(store)

                // Mood Timeline
                moodSection

                // This week
                HStack {
                    Text(t("This week", "Αυτή την εβδομάδα", "Diese Woche"))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: { showWeeklyRecap() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 11))
                            Text(t("View recap", "Δες ανασκόπηση", "Rückblick anzeigen"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.blue)
                    }
                }

                WeeklyChart(data: store.weeklyPickups, dayNames: dayNames)
                    .frame(height: 120)

                // MARK: - Correlation Insights (Pro)
                CorrelationInsightView(onUnlockTap: { showPaywall = true })
                    .environment(correlationStore)

                // MARK: - Heatmap section (NEW!)
                heatmapSection

                // Streak
                Text(t("Streak", "Σερί", "Serie"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(store.currentStreak)")
                        .font(.system(size: 36, weight: .medium, design: .rounded))

                    Text(t("days under\n15 pickups", "μέρες κάτω\nαπό 15 σηκώματα", "Tage unter\n15 Griffen"))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                // All Time
                Divider().padding(.vertical, 4)

                Text(t("All time", "Συνολικά", "Gesamt"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    StatCard(title: t("Total pickups", "Συνολικά σηκώματα", "Griffe gesamt"), value: "\(store.totalPickups)")
                    StatCard(title: t("Daily avg", "Μέσος/ημέρα", "Ø pro Tag"), value: "\(store.averageDailyPickups)")
                }

                HStack(spacing: 12) {
                    StatCard(title: t("Days tracked", "Μέρες χρήσης", "Tage erfasst"), value: "\(store.totalDaysTracked)")
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 24)
        }
        .sheet(item: $shareItem) { item in
            ShareStatsSheet(image: item.image, language: appLanguage)
        }
        .sheet(isPresented: $showCheckInSheet) {
            DailyCheckInView()
                .environment(checkInManager)
        }
        .fullScreenCover(item: $weeklySummaryItem) { item in
            WeeklySummaryView(
                summary: item.summary,
                onUnlockTap: { showPaywall = true }
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView().environment(proManager)
        }
    }

    // MARK: - Heatmap Section (NEW)

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("Hourly heatmap", "Χάρτης ωρών", "Stunden-Heatmap"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                if !proManager.isPro {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 10))
                        Text("Pro")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.blue)
                }
            }

            if proManager.isPro {
                HeatmapView()
            } else {
                heatmapLockedCard
            }
        }
    }

    private var heatmapLockedCard: some View {
        Button(action: { showPaywall = true }) {
            VStack(spacing: 12) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))

                Text(t(
                    "See which hours you pick up your phone the most",
                    "Δες ποιες ώρες πιάνεις πιο πολύ το κινητό",
                    "Sieh, zu welchen Stunden du dein Handy am häufigsten greifst"
                ))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

                HStack(spacing: 6) {
                    Image(systemName: "lock.open.fill").font(.system(size: 11))
                    Text(t("Unlock with Pro", "Ξεκλείδωσε με Pro", "Mit Pro freischalten"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.blue))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    // MARK: - Weekly Recap

    private func showWeeklyRecap() {
        let summary = weeklyManager.computeSummary(
            weeklyPickups: store.weeklyPickups,
            hourlyScreenTimeSecs: store.hourlyScreenTimeSecs,
            checkInManager: checkInManager,
            streak: store.currentStreak,
            dayNames: dayNames
        )
        weeklySummaryItem = WeeklySummaryItem(summary: summary)
    }

    // MARK: - Mood Section

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("Mood this week", "Διάθεση εβδομάδας", "Stimmung diese Woche"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                if !checkInManager.hasCheckedInToday {
                    Button(action: { showCheckInSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 12))
                            Text(t("Check in", "Απολογισμός", "Check-in"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.blue)
                    }
                }
            }

            let moods = checkInManager.last7DaysMoods
            let dayLabels = moodDayNames

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(moods[index]?.color ?? Color(.systemGray5))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Group {
                                    if moods[index] == nil {
                                        Text("—")
                                            .font(.system(size: 11, weight: .regular, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            )

                        Text(dayLabels[index])
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))

            // Εμφάνισε τη σημερινή σημείωση αν υπάρχει
            if let todayEntry = checkInManager.entries.first(where: { $0.date == todayString() }),
               !todayEntry.note.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(todayEntry.note)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Share

    @MainActor
    private func generateAndShare() {
        let card = ShareCardView(
            pickups: store.todayPickups,
            goal: dailyGoal,
            streak: store.currentStreak,
            language: appLanguage
        )
        .frame(width: 400, height: 600)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            shareItem = ShareImageItem(image: image)
        }
    }
}

// MARK: - Share Card

struct ShareCardView: View {
    let pickups: Int
    let goal: Int
    let streak: Int
    let language: String

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch language {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    private var pickupColor: Color {
        if pickups <= goal / 2 { return .green }
        if pickups <= goal { return .blue }
        return .orange
    }

    private var emoji: String {
        if pickups <= goal / 2 { return "🏆" }
        if pickups <= goal { return "💪" }
        return "📱"
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                Text("Picksy")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text(Date().formatted(.dateTime.day().month().year()))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)

            Spacer()

            VStack(spacing: 12) {
                Text(emoji).font(.system(size: 60))

                Text("\(pickups)")
                    .font(.system(size: 96, weight: .medium, design: .rounded))
                    .foregroundColor(pickupColor)

                Text(t("pickups today", "σηκώματα σήμερα", "Griffe heute"))
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(goal)").font(.system(size: 28, weight: .medium, design: .rounded))
                    Text(t("goal", "στόχος", "Ziel"))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(streak)").font(.system(size: 28, weight: .medium, design: .rounded))
                    Text(t("day streak", "μέρες σερί", "Tage Serie"))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Text(t("Track your phone habits", "Παρακολούθησε τις συνήθειές σου", "Verfolge deine Handy-Gewohnheiten"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                Text("apps.apple.com/app/picksy-be-present")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Share Sheet

struct ShareStatsSheet: UIViewControllerRepresentable {
    let image: UIImage
    let language: String

    private var caption: String {
        switch language {
        case "Ελληνικά":
            return "Κοίτα τα αποτελέσματά μου στο Picksy σήμερα! 📱 Κατέβασέ το: https://apps.apple.com/app/picksy-be-present/id6761116771"
        case "Deutsch":
            return "Schau dir meine Picksy-Ergebnisse heute an! 📱 Lade es herunter: https://apps.apple.com/app/picksy-be-present/id6761116771"
        default:
            return "Check out my Picksy stats today! 📱 Download it: https://apps.apple.com/app/picksy-be-present/id6761116771"
        }
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [image, caption],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .medium, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Weekly Chart

struct WeeklyChart: View {
    let data: [Int]
    let dayNames: [String]

    private var maxValue: Int { max(data.max() ?? 1, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index == currentDayIndex() ? Color.blue : Color.blue.opacity(0.4))
                        .frame(height: barHeight(for: data[index]))

                    Text(dayNames[index])
                        .font(.system(size: 11,
                            weight: index == currentDayIndex() ? .medium : .regular,
                            design: .rounded))
                        .foregroundColor(index == currentDayIndex() ? .primary : .secondary)
                }
            }
        }
    }

    private func barHeight(for value: Int) -> CGFloat {
        let maxHeight: CGFloat = 80
        guard maxValue > 0 else { return 4 }
        return max((CGFloat(value) / CGFloat(maxValue)) * maxHeight, 4)
    }

    private func currentDayIndex() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }
}

#Preview {
    DashboardView()
        .environment(DataStore())
        .environment(CheckInManager())
        .environment(WeeklySummaryManager())
        .environment(ProManager.shared)
        .environment(CorrelationStore.shared)
}

