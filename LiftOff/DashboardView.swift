// DashboardView.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026

import SwiftUI
import DeviceActivity

// ShareImageItem moved to ShareImageItem.swift so it stays available to the
// Live Activity extension (which compiles WeeklySummaryView) after DashboardView
// was excluded from that target.

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
    @Environment(HourlyTracker.self) var hourly
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

                todaySection

                // Coach Card
                CoachCardView(
                    todayPickups: store.todayPickups,
                    weeklyPickups: store.weeklyPickups,
                    streak: store.currentStreak,
                    goal: dailyGoal,
                    worstHours: hourly.worstHours,
                    language: appLanguage
                )

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

                // Streak Card
                streakCard

                // Journey Card
                journeyCard

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            // Pull the latest Apps-tab total from the App Group so the Screen
            // Time card and Picksy Score match every other surface on entry.
            store.refreshConfirmedScreenTime()
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

    // MARK: - Today Section

    private var avgSessionSeconds: Int {
        guard store.todayPickups > 0 else { return 0 }
        return store.todayTotalSeconds / store.todayPickups
    }

    /// Short sessions = green (mindful), long sessions = red (sucked in)
    private var avgTimeAccentColor: Color {
        let s = avgSessionSeconds
        if s == 0    { return .secondary }
        if s < 60    { return .green }
        if s < 180   { return .blue }
        if s < 600   { return .orange }
        return .red
    }

    private var pickupsAccentColor: Color {
        let p = store.todayPickups
        if p == 0             { return .blue }
        if p <= dailyGoal / 2 { return .green }
        if p <= dailyGoal     { return .blue }
        if p <= dailyGoal + 10 { return .orange }
        return .red
    }

    private var todaySection: some View {
        VStack(spacing: 12) {

            // ── Row 1: Pickups + Screen Time ─────────────────────────
            HStack(spacing: 12) {

                // Pickups card
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 11))
                            .foregroundColor(pickupsAccentColor)
                        Text(t("Pickups", "Σηκώματα", "Griffe"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    // Apple's REAL pickup count (matches Settings → Screen Time),
                    // rendered by the report extension. The app-side detector can
                    // miss unlocks while the app is suspended (friends saw "30" in
                    // Settings but the app showed 9), so we display the exact number
                    // here — same approach as the Screen Time card next to it.
                    DeviceActivityReport(.statsPickups, filter: deviceTotalFilter)
                        .frame(height: 36)

                    Spacer()

                    Text(t("goal \(dailyGoal)", "στόχος \(dailyGoal)", "Ziel \(dailyGoal)"))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(pickupsAccentColor.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(pickupsAccentColor.opacity(0.18), lineWidth: 1))
                )

                // Screen Time card
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 11))
                            .foregroundColor(screenTimeAccentColor)
                        Text(t("Screen Time", "Χρόνος Χρήσης", "Bildschirmzeit"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    // Whole-device total, rendered by the report extension
                    // (the number can't be passed back to the app, so it's
                    // drawn here — same value the Apps tab shows, independent
                    // of which apps are selected).
                    DeviceActivityReport(.statsTotalTime, filter: deviceTotalFilter)
                        .frame(height: 36)

                    Spacer()

                    Text(t("today", "σήμερα", "heute"))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(screenTimeAccentColor.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(screenTimeAccentColor.opacity(0.18), lineWidth: 1))
                )
            }
            .frame(height: 112)

            // ── Row 2: Picksy Score ───────────────────────────────────
            // Computed + rendered by the report extension from the same
            // whole-device total (the app can't read that number back). The card
            // chrome uses a fixed accent; the number itself is color-coded inside.
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.indigo)
                        Text("Picksy Score")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Text(t("Lower = better", "Χαμηλότερο = καλύτερο", "Niedriger = besser"))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                DeviceActivityReport(.statsScore, filter: deviceTotalFilter)
                    .frame(width: 86, height: 38)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(t("How it's calculated", "Πώς υπολογίζεται", "Berechnung"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(t("(pickups + min × 5) ÷ 20", "(σηκώματα + λεπτά × 5) ÷ 20", "(Griffe + Min. × 5) ÷ 20"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.indigo.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.indigo.opacity(0.18), lineWidth: 1))
            )
        }
    }

    /// Whole-device, today filter (no app/category scope) for the hosted
    /// screen-time total report.
    private var deviceTotalFilter: DeviceActivityFilter {
        DeviceActivityFilter(
            segment: .daily(
                during: Calendar.current.dateInterval(of: .day, for: Date())!
            ),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    /// Fixed chrome color for the Screen Time card. The number itself is
    /// duration-colored inside the hosted report; the app no longer knows the
    /// value, so the card frame uses a stable accent.
    private var screenTimeAccentColor: Color { .indigo }

    // MARK: - Streak Card

    @ViewBuilder
    private var streakCard: some View {
        let milestones = [3, 7, 14, 21, 30, 60, 90, 365]
        let nextMilestone = milestones.first(where: { $0 > store.currentStreak })
        let prevMilestone = milestones.last(where: { $0 <= store.currentStreak }) ?? 0
        let progress: CGFloat = {
            let next = nextMilestone ?? (prevMilestone + 10)
            let span = next - prevMilestone
            return span > 0 ? CGFloat(store.currentStreak - prevMilestone) / CGFloat(span) : 1.0
        }()
        let ringColor: Color = {
            if store.currentStreak >= 30 { return .purple }
            if store.currentStreak >= 14 { return .orange }
            if store.currentStreak >= 7  { return .yellow }
            if store.currentStreak >= 3  { return .green }
            return .blue
        }()

        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 5)
                    .frame(width: 64, height: 64)
                if store.currentStreak > 0 {
                    Circle()
                        .trim(from: 0, to: max(progress, 0.05))
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: progress)
                }
                VStack(spacing: 0) {
                    Text("\(store.currentStreak)")
                        .font(.system(size: store.currentStreak >= 100 ? 16 : 20,
                                      weight: .bold, design: .rounded))
                    if store.currentStreak > 0 {
                        Text("🔥").font(.system(size: 10))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(store.currentStreak > 0
                     ? t("\(store.currentStreak)-day streak 🔥",
                         "\(store.currentStreak) μέρες σερί 🔥",
                         "\(store.currentStreak)-Tage-Serie 🔥")
                     : t("Start your streak!", "Ξεκίνα το σερί σου!", "Starte deine Serie!"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Text(t("Under \(dailyGoal) pickups per day",
                        "Κάτω από \(dailyGoal) σηκώματα/μέρα",
                        "Unter \(dailyGoal) Griffen/Tag"))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)

                if let next = nextMilestone {
                    let daysLeft = next - store.currentStreak
                    Text(t("Next milestone: \(next) days (\(daysLeft) to go)",
                            "Επόμενο: \(next) μέρες (\(daysLeft) ακόμα)",
                            "Nächstes: \(next) Tage (noch \(daysLeft))"))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text(t("Legendary! 🏆", "Θρυλικό! 🏆", "Legendär! 🏆"))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.purple)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    // MARK: - Journey Card

    @ViewBuilder
    private var journeyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "map.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(t("Your journey", "Η πορεία σου", "Dein Weg"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.totalPickups)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(t("pickups tracked", "σηκώματα καταγεγραμμένα", "Griffe aufgezeichnet"))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.secondary)
            }

            if store.totalPickups > 0 && store.totalDaysTracked > 0 {
                let estimatedHours = max(1, (store.totalPickups * 2) / 60)
                Text(t("Roughly \(estimatedHours)h of screen time across \(store.totalDaysTracked) days",
                        "Περίπου \(estimatedHours)ω χρόνος οθόνης σε \(store.totalDaysTracked) μέρες",
                        "Ca. \(estimatedHours)h Bildschirmzeit über \(store.totalDaysTracked) Tage"))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.averageDailyPickups)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(t("daily avg", "μέσος/ημέρα", "Ø/Tag"))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.totalDaysTracked)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(t("days tracked", "μέρες χρήσης", "Tage erfasst"))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Milestone approaching
            let pickupMilestones = [100, 250, 500, 1000, 2500, 5000]
            if let next = pickupMilestones.first(where: { $0 > store.totalPickups }) {
                let remaining = next - store.totalPickups
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text(t("\(remaining) pickups to the \(next) milestone 🏆",
                            "\(remaining) σηκώματα μέχρι το milestone των \(next) 🏆",
                            "Noch \(remaining) Griffe bis zum \(next)-Meilenstein 🏆"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
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

    // Static formatter — was allocating on every moodSection render (triggered by every pickup).
    private static let todayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private func todayString() -> String {
        return Self.todayFormatter.string(from: Date())
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
        // Compute once per render — was calling Calendar.current.component 7× per ForEach cell.
        let today = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        let maxH   = maxValue
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                let isToday = index == today
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isToday ? Color.blue : Color.blue.opacity(0.4))
                        .frame(height: barHeight(for: data[index], max: maxH))

                    Text(dayNames[index])
                        .font(.system(size: 11,
                            weight: isToday ? .medium : .regular,
                            design: .rounded))
                        .foregroundColor(isToday ? .primary : .secondary)
                }
            }
        }
    }

    private func barHeight(for value: Int, max maxValue: Int) -> CGFloat {
        let maxHeight: CGFloat = 80
        guard maxValue > 0 else { return 4 }
        return max((CGFloat(value) / CGFloat(maxValue)) * maxHeight, 4)
    }
}

#Preview {
    DashboardView()
        .environment(DataStore())
        .environment(CheckInManager())
        .environment(WeeklySummaryManager())
        .environment(ProManager.shared)
        .environment(CorrelationStore.shared)
        .environment(HourlyTracker())
}

