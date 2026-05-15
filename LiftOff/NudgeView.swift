// NudgeView.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026
//
// v1.6 FINAL - Idle-only mode.
// v1.7 UPDATE - "Τι να κάνω τώρα;" button με activity suggestions.
//

import SwiftUI
import DeviceActivity
import FamilyControls

struct NudgeView: View {
    @Environment(DataStore.self) var store
    @Environment(WeatherManager.self) var weatherManager
    @Environment(ActivityPreferences.self) var activityPrefs
    @Environment(FocusSessionManager.self) var focusManager
    @Environment(LiveActivityManager.self) var liveActivity
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @AppStorage("dailyGoal") private var dailyGoal: Int = 15
    @AppStorage("lastPickupTimestamp") private var lastPickupTimestamp: Double = 0

    @State private var currentQuote: String = ""
    @State private var minutesSinceLastPickup: Int = 0
    @State private var refreshTimer: Timer? = nil
    @State private var showAccuracyInfo: Bool = false

    // v1.7: Activity suggestions sheet
    @State private var showActivitySuggestions: Bool = false

    // Focus Session sheet
    @State private var showFocusSession: Bool = false

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

    private var zoneColor: Color {
        store.currentZone.color
    }

    private var timeOfDay: TimeOfDay {
        TimeOfDay.from(
            sunrise: weatherManager.currentWeather?.sunrise,
            sunset:  weatherManager.currentWeather?.sunset
        )
    }

    private var isLightBackground: Bool {
        let isDaytime = (timeOfDay == .morning || timeOfDay == .midday)
        let isClearWeather = (weatherManager.activeCondition == .sunny ||
                              weatherManager.activeCondition == .partlyCloudy)
        return isDaytime && isClearWeather
    }

    private var todayFilter: DeviceActivityFilter {
        DeviceActivityFilter(
            segment: .daily(
                during: Calendar.current.dateInterval(of: .day, for: Date())!
            ),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    private var shouldShowTopApps: Bool {
        FamilyControlsManager.shared.isAuthorized &&
        AppSelectionStore.shared.hasSelectedApps
    }

    var body: some View {
        ZStack {
            WeatherBackground(
                timeOfDay: timeOfDay,
                condition: weatherManager.activeCondition,
                isDimmed: false
            )

            idleContent
        }
        .alert(
            t("About pickup count", "Σχετικά με τα σηκώματα", "Über die Griff-Zählung"),
            isPresented: $showAccuracyInfo
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(t(
                "Picksy counts pickups via screen unlocks (with a 30s cooldown to match Apple's behavior). For detailed app usage time, see the Apps tab.",
                "Το Picksy μετράει σηκώματα μέσω ξεκλειδωμάτων (με 30s cooldown ώστε να ταιριάζει με τη συμπεριφορά της Apple). Για αναλυτικό χρόνο χρήσης ανά εφαρμογή, δες το tab Εφαρμογές.",
                "Picksy zählt Griffe per Bildschirm-Entsperrungen (mit 30s Cooldown zur Apple-Konformität). Für detaillierte App-Nutzungszeiten siehe Apps-Tab."
            ))
        }
        // v1.7: Activity suggestions sheet
        .sheet(isPresented: $showActivitySuggestions) {
            ActivitySuggestionView(onDismiss: {
                showActivitySuggestions = false
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        // Focus Session sheet
        .sheet(isPresented: $showFocusSession) {
            FocusSessionView(
                onFocusStart: { endTime in
                    liveActivity.updateForFocus(
                        pickupCount: store.todayPickups,
                        focusEndTime: endTime,
                        focusPickupCount: 0
                    )
                },
                onFocusEnd: {
                    liveActivity.update(pickupCount: store.todayPickups)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .onChange(of: focusManager.sessionState) { _, newState in
            // Auto-open sheet when session completes so user sees results
            if case .completed = newState {
                showFocusSession = true
            }
        }
        .onAppear {
            currentQuote = ActivityBank.random(weather: weatherManager.activeCondition, categories: activityPrefs.effectiveCategories)
            updateMinutesSinceLastPickup()
            startRefreshTimer()

            NotificationCenter.default.addObserver(
                forName: .picksyPickupDetected,
                object: nil,
                queue: .main
            ) { _ in
                lastPickupTimestamp = Date().timeIntervalSince1970
                updateMinutesSinceLastPickup()
                currentQuote = ActivityBank.random(
                    weather: weatherManager.activeCondition,
                    categories: activityPrefs.effectiveCategories
                )
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            NotificationCenter.default.removeObserver(
                self,
                name: .picksyPickupDetected,
                object: nil
            )
        }
        .onChange(of: appLanguage) { _, _ in
            currentQuote = ActivityBank.random(weather: weatherManager.activeCondition, categories: activityPrefs.effectiveCategories)
        }
    }

    // MARK: - Idle screen

    private var idleContent: some View {
        VStack(spacing: 20) {
            // Temperature pill
            if let weather = weatherManager.currentWeather {
                HStack {
                    temperaturePill(weather: weather)
                        .padding(.leading, 20)
                        .padding(.top, 20)
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
                HStack {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Button(action: {
                        currentQuote = ActivityBank.random(
                            weather: weatherManager.activeCondition,
                            categories: activityPrefs.effectiveCategories
                        )
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Text(currentQuote)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
            .padding(.horizontal, 32)

            // Top 3 apps card
            if shouldShowTopApps {
                topAppsCard
                    .padding(.horizontal, 32)
            }

            // Last pickup info
            if lastPickupTimestamp > 0 {
                lastPickupCard
                    .padding(.horizontal, 32)
            }

            // Focus Session button
            focusSessionButton
                .padding(.horizontal, 32)

            // v1.7: "Τι να κάνω τώρα;" button
            activitySuggestionsButton
                .padding(.horizontal, 32)

            Spacer()

            // Stats card
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text(t("Today", "Σήμερα", "Heute"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))

                    Button(action: { showAccuracyInfo = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Text(store.currentZone.displayName(language: appLanguage))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(zoneColor.opacity(0.85))
                        )

                    Text("\(store.todayPickups) / \(dailyGoal)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(zoneColor)
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

    // MARK: - Focus Session Button

    private var focusSessionButton: some View {
        Button(action: { showFocusSession = true }) {
            HStack(spacing: 8) {
                Text("⏱")
                    .font(.system(size: 16))

                if focusManager.isActive {
                    Text(focusManager.formattedTimeRemaining + " " + t("remaining", "απομένουν", "verbleibend"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                } else {
                    Text(t("Focus Session", "Περίοδος Εστίασης", "Fokus-Session"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(focusManager.isActive ? .orange.opacity(0.8) : .white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(focusManager.isActive
                          ? Color.orange.opacity(0.18)
                          : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .opacity(0.7)
                    )
            )
        }
    }

    // MARK: - Activity Suggestions Button (v1.7)

    private var activitySuggestionsButton: some View {
        Button(action: { showActivitySuggestions = true }) {
            HStack(spacing: 8) {
                Text("✨")
                    .font(.system(size: 16))

                Text(t(
                    "What should I do?",
                    "Τι να κάνω τώρα;",
                    "Was soll ich tun?"
                ))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
            )
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
        Button(action: {
            Task { await weatherManager.manualRefresh() }
        }) {
            HStack(spacing: 5) {
                // Weather icon or loading spinner
                if weatherManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(.white)
                        .frame(width: 16)
                } else {
                    Text(displayEmoji(for: weather.condition))
                        .font(.system(size: 13))
                }

                // Temperature
                Text("\(Int(weather.temperature))°")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                // Condition name (merged into pill — no more second line)
                let condition = conditionName(for: weather.condition)
                if !condition.isEmpty {
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                    Text(condition)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }

                // City name
                if !weather.cityName.isEmpty && weather.cityName != "Current Location" {
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                    Text(weather.cityName)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    if isLightBackground {
                        Capsule().fill(Color.black.opacity(0.3))
                    }
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(isLightBackground ? 0.4 : 0.65)
                }
            )
            .shadow(color: .black.opacity(0.25), radius: 4)
        }
        .buttonStyle(.plain)
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

    // MARK: - Timer

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
        .environment(WeatherManager())
        .environment(ActivityPreferences())
        .environment(FocusSessionManager())
}

