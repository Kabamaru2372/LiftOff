// NudgeView.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026

import SwiftUI
import DeviceActivity
import FamilyControls

struct NudgeView: View {
    @Environment(DataStore.self) var store
    @Environment(PickupDetector.self) var detector
    @Environment(LiveActivityManager.self) var liveActivity
    @Environment(HourlyTracker.self) var hourlyTracker
    @Environment(RewardManager.self) var rewardManager
    @Environment(WeatherManager.self) var weatherManager
    @Environment(ActivityPreferences.self) var activityPrefs
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @AppStorage("dailyGoal") private var dailyGoal: Int = 15
    @AppStorage("lastPickupTimestamp") private var lastPickupTimestamp: Double = 0

    @State private var currentQuote: String = ""
    @State private var secondsOnScreen: Int = 0
    @State private var timer: Timer? = nil
    @State private var showingContinueConfirm: Bool = false
    @State private var showNudge: Bool = false
    @State private var minutesSinceLastPickup: Int = 0
    @State private var refreshTimer: Timer? = nil
    @State private var showAccuracyInfo: Bool = false

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    private var goalProgress: Double {
        let goal = dailyGoal > 0 ? dailyGoal : 15
        return min(Double(store.todayPickups) / Double(goal), 1.0)
    }

    private var goalColor: Color {
        switch goalProgress {
        case 0..<0.5: return .blue
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    private var timeOfDay: TimeOfDay {
        TimeOfDay.from()
    }

    /// True αν το background είναι "φωτεινό" (μέρα με ήλιο)
    private var isLightBackground: Bool {
        let isDaytime = (timeOfDay == .morning || timeOfDay == .midday)
        let isClearWeather = (weatherManager.activeCondition == .sunny ||
                              weatherManager.activeCondition == .partlyCloudy)
        return isDaytime && isClearWeather
    }

    /// Filter για το top 3 widget
    private var todayFilter: DeviceActivityFilter {
        DeviceActivityFilter(
            segment: .daily(
                during: Calendar.current.dateInterval(of: .day, for: Date())!
            ),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    /// True αν πρέπει να εμφανίζεται το top 3 card
    private var shouldShowTopApps: Bool {
        FamilyControlsManager.shared.isAuthorized &&
        AppSelectionStore.shared.hasSelectedApps
    }

    var body: some View {
        ZStack {
            WeatherBackground(
                timeOfDay: timeOfDay,
                condition: weatherManager.activeCondition,
                isDimmed: showNudge
            )

            if showNudge {
                nudgeContent.transition(.opacity)
            } else {
                idleContent.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showNudge)
        .alert(
            t("About pickup count", "Σχετικά με τα σηκώματα", "Über die Griff-Zählung"),
            isPresented: $showAccuracyInfo
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(t(
                "Due to iOS limitations, the pickup count is approximate. It only counts when Picksy is open in the foreground. For accurate app usage data, see the Apps tab.",
                "Λόγω περιορισμών του iOS, ο αριθμός σηκωμάτων είναι κατά προσέγγιση. Μετράει μόνο όταν το Picksy είναι ανοιχτό στο προσκήνιο. Για ακριβή στατιστικά χρήσης εφαρμογών, δες το tab Εφαρμογές.",
                "Aufgrund von iOS-Einschränkungen ist die Griff-Zählung ungefähr. Sie zählt nur, wenn Picksy im Vordergrund geöffnet ist. Für genaue App-Nutzungsdaten siehe den Apps-Tab."
            ))
        }
        .onAppear {
            currentQuote = ActivityBank.random(weather: weatherManager.activeCondition, categories: activityPrefs.effectiveCategories)
            updateMinutesSinceLastPickup()
            detector.onPickupDetected = { triggerNudge() }
            detector.startMonitoring()
            startRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
        .onChange(of: appLanguage) { _, _ in
            currentQuote = ActivityBank.random(weather: weatherManager.activeCondition, categories: activityPrefs.effectiveCategories)
        }
        .onChange(of: detector.pickupDetected) { _, newValue in
            if newValue == true { triggerNudge() }
        }
    }

    // MARK: - Idle screen

    private var idleContent: some View {
        VStack(spacing: 20) {
            // Temperature pill στο πάνω αριστερά
            if let weather = weatherManager.currentWeather {
                HStack {
                    temperaturePill(weather: weather)
                        .padding(.leading, 24)
                        .padding(.top, 8)
                    Spacer()
                }
            }

            Spacer()

            // Picksy title
            Text("Picksy")
                .font(.system(size: 32, weight: .light, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)

            Text(t("Be present", "Να είσαι παρών", "Sei präsent"))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 2)

            Spacer()

            // Inspirational quote card
            VStack(spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))

                Text(currentQuote)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
            .padding(.horizontal, 32)

            // Top 3 apps card (αν είναι authorized)
            if shouldShowTopApps {
                topAppsCard
                    .padding(.horizontal, 32)
            }

            // Last pickup info
            if lastPickupTimestamp > 0 {
                lastPickupCard
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Stats card στο κάτω μέρος (με info button για disclaimer)
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text(t("Today", "Σήμερα", "Heute"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))

                    // Info button — ανοίγει disclaimer
                    Button(action: { showAccuracyInfo = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()
                    Text(t(
                        "\(store.todayPickups) / \(dailyGoal)",
                        "\(store.todayPickups) / \(dailyGoal)",
                        "\(store.todayPickups) / \(dailyGoal)"
                    ))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(goalColor)
                            .frame(width: geo.size.width * goalProgress, height: 6)
                            .animation(.easeInOut(duration: 0.4), value: goalProgress)
                    }
                }
                .frame(height: 6)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 90)
        }
    }

    // MARK: - Top Apps Card

    private var topAppsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
                Text(t("Top apps today", "Κορυφαίες εφαρμογές σήμερα", "Top-Apps heute"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }

            DeviceActivityReport(.top3Activity, filter: todayFilter)
                .frame(height: 110)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        )
    }

    // MARK: - Temperature Pill

    private func temperaturePill(weather: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(displayEmoji(for: weather.condition))
                    .font(.system(size: 14))
                Text("\(Int(weather.temperature))°")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isLightBackground {
                        Capsule()
                            .fill(Color.black.opacity(0.35))
                    }
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(isLightBackground ? 0.4 : 0.6)
                }
            )
            .shadow(color: .black.opacity(0.3), radius: 3)

            Text(conditionName(for: weather.condition))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.leading, 12)
                .shadow(color: .black.opacity(0.5), radius: 3)
        }
    }

    private func displayEmoji(for condition: WeatherCondition) -> String {
        if condition == .sunny && timeOfDay == .night {
            return "🌙"
        }
        return condition.emoji
    }

    private func conditionName(for condition: WeatherCondition) -> String {
        switch condition {
        case .sunny:
            if timeOfDay == .night {
                return t("Clear", "Αίθριος", "Klar")
            }
            return t("Sunny", "Ηλιοφάνεια", "Sonnig")
        case .partlyCloudy: return t("Partly cloudy", "Μερικώς συννεφιά", "Teilweise bewölkt")
        case .cloudy:       return t("Cloudy", "Συννεφιά", "Bewölkt")
        case .rainy:        return t("Rainy", "Βροχή", "Regnerisch")
        case .thunderstorm: return t("Storm", "Καταιγίδα", "Gewitter")
        case .snow:         return t("Snow", "Χιόνι", "Schnee")
        case .foggy:        return t("Foggy", "Ομίχλη", "Neblig")
        case .hot:          return t("Hot", "Ζέστη", "Heiß")
        case .cold:         return t("Cold", "Κρύο", "Kalt")
        case .unknown:      return ""
        }
    }

    // MARK: - Last Pickup Card

    private var lastPickupCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))

            Text(lastPickupText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        )
    }

    private var lastPickupText: String {
        if minutesSinceLastPickup < 1 {
            return t("Just now", "Μόλις τώρα", "Gerade eben")
        } else if minutesSinceLastPickup < 60 {
            return t(
                "Last pickup: \(minutesSinceLastPickup) min ago",
                "Τελευταίο σήκωμα: \(minutesSinceLastPickup) λ. πριν",
                "Letzter Griff: vor \(minutesSinceLastPickup) Min."
            )
        } else {
            let hours = minutesSinceLastPickup / 60
            let mins = minutesSinceLastPickup % 60
            return t(
                "Last pickup: \(hours)h \(mins)m ago",
                "Τελευταίο σήκωμα: \(hours)ώ \(mins)λ πριν",
                "Letzter Griff: vor \(hours)h \(mins)m"
            )
        }
    }

    // MARK: - Nudge screen

    private var nudgeContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(formatTime(secondsOnScreen))
                .font(.system(size: 56, weight: .light, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.3), radius: 4)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.2), value: secondsOnScreen)

            Text(currentQuote)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .shadow(color: .black.opacity(0.3), radius: 2)

            Spacer()

            HStack(spacing: 16) {
                Button(action: { putItDown() }) {
                    Text(t("Put it down", "Κατέβασέ το", "Leg es weg"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                        )
                }

                Button(action: { showingContinueConfirm = true }) {
                    Text(t("Continue", "Συνέχεια", "Weiter"))
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        )
                }
            }

            if store.currentStreak > 0 {
                Text(t(
                    "\(store.currentStreak)-day streak",
                    "\(store.currentStreak) μέρες σερί",
                    "\(store.currentStreak) Tage in Folge"
                ))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 2)
            }

            Spacer().frame(height: 100)
        }
        .alert(t("Are you sure?", "Είσαι σίγουρος;", "Bist du sicher?"),
               isPresented: $showingContinueConfirm) {
            Button(t("Yes, I need my phone", "Ναι, χρειάζομαι το κινητό", "Ja, ich brauche mein Handy"),
                   role: .destructive) { dismissNudge() }
            Button(t("You're right, I'll put it down", "Έχεις δίκιο, κατεβάζω το κινητό", "Du hast recht, ich lege es weg"),
                   role: .cancel) { putItDown() }
        }
    }

    // MARK: - Actions

    private func triggerNudge() {
        guard !showNudge else { return }
        currentQuote = ActivityBank.random(weather: weatherManager.activeCondition, categories: activityPrefs.effectiveCategories)
        store.recordPickup()
        hourlyTracker.recordPickup()
        lastPickupTimestamp = Date().timeIntervalSince1970
        secondsOnScreen = 0
        showNudge = true
        startTimer()
        liveActivity.update(pickupCount: store.todayPickups)
        rewardManager.checkForRewards(tracker: hourlyTracker)
    }

    private func putItDown() {
        stopTimer()
        dismissNudge()
    }

    private func dismissNudge() {
        stopTimer()
        showNudge = false
        detector.acknowledgePickup()
    }

    private func startTimer() {
        timer?.invalidate()
        secondsOnScreen = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            secondsOnScreen += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        store.addUsageTime(seconds: secondsOnScreen)
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Last pickup tracking

    private func updateMinutesSinceLastPickup() {
        guard lastPickupTimestamp > 0 else {
            minutesSinceLastPickup = 0
            return
        }
        let elapsed = Date().timeIntervalSince1970 - lastPickupTimestamp
        minutesSinceLastPickup = Int(elapsed / 60)
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            updateMinutesSinceLastPickup()
        }
    }
}

#Preview {
    NudgeView()
        .environment(DataStore())
        .environment(PickupDetector())
        .environment(LiveActivityManager())
        .environment(HourlyTracker())
        .environment(RewardManager())
        .environment(WeatherManager())
        .environment(ActivityPreferences())
}

