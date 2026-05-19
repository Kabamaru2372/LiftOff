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
    @Environment(TabSelection.self) var tabSelection
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @AppStorage("dailyGoal") private var dailyGoal: Int = 15
    @AppStorage("lastPickupTimestamp") private var lastPickupTimestamp: Double = 0
    @AppStorage("challengeDisplayName") private var displayName: String = ""

    @State private var currentQuote: String = ""
    @State private var minutesSinceLastPickup: Int = 0
    @State private var refreshTimer: Timer? = nil
    @State private var showAccuracyInfo: Bool = false

    // v1.7: Activity suggestions sheet
    @State private var showActivitySuggestions: Bool = false

    // Focus Session sheet
    @State private var showFocusSession: Bool = false

    // Challenge share
    @State private var showChallengeBanner: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var challengeShareItems: [Any] = []

    // Together banner (friends also overusing right now)
    @State private var togetherBanners: [TogetherBannerData] = []
    @State private var messagingPair: RegisteredPair? = nil

    // Animations
    @State private var appeared: Bool = false
    @State private var counterScale: CGFloat = 1.0
    @State private var badgePulse: Bool = false
    @State private var titleShimmer: Bool = false



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
        // Challenge share sheet
        .sheet(isPresented: $showShareSheet) {
            ActivityShareSheet(items: challengeShareItems)
        }
        // Together banner → messaging sheet
        .sheet(item: $messagingPair) { pair in
            MessageView(pair: pair)
                .presentationDetents([.large])
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
            checkChallengeBanner()
            checkTogetherBanner()

            // Entrance animation
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
            // Title shimmer (subtle breathing)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                titleShimmer = true
            }
            // Zone badge pulse (only in danger zone)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                badgePulse = store.currentZone == .problematic || store.currentZone == .heavy
            }

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
                // Counter spring bounce on new pickup
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    counterScale = 1.35
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        counterScale = 1.0
                    }
                }
                // Update danger zone pulse
                badgePulse = store.currentZone == .problematic || store.currentZone == .heavy
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            appeared = false
            titleShimmer = false
            badgePulse = false
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

            // Weather pill — first item so SwiftUI places it naturally just below
            // the safe area boundary (status bar / Dynamic Island). No manual padding needed.
            if let weather = weatherManager.currentWeather {
                HStack {
                    temperaturePill(weather: weather)
                        .padding(.leading, 20)
                    Spacer()
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -8)
                .animation(.easeOut(duration: 0.4), value: appeared)
            }

            // Small fixed gap so Picksy stays near the top
            Spacer().frame(maxHeight: 20)

            // Picksy title — subtle shimmer
            Text("Picksy")
                .font(.system(size: 32, weight: .light, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)
                .scaleEffect(titleShimmer ? 1.03 : 1.0)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.05), value: appeared)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: titleShimmer)

            // Large flexible gap — the animation shows through here
            Spacer()

            // Inspirational quote card — crossfade on quote change
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentQuote = ActivityBank.random(
                                weather: weatherManager.activeCondition,
                                categories: activityPrefs.effectiveCategories
                            )
                        }
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
                    .id(currentQuote)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 8)),
                        removal:   .opacity.combined(with: .offset(y: -8))
                    ))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

            // Top 3 apps card
            if shouldShowTopApps {
                topAppsCard
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: appeared)
            }

            // Last pickup info
            if lastPickupTimestamp > 0 {
                lastPickupCard
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.22), value: appeared)
            }

            // Focus Session button
            focusSessionButton
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.26), value: appeared)

            // v1.7: "Τι να κάνω τώρα;" button
            activitySuggestionsButton
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.30), value: appeared)

            // Together banner — εμφανίζεται όταν εσύ και φίλος είστε ταυτόχρονα στο κινητό
            ForEach(togetherBanners) { data in
                togetherBannerView(data: data)
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Challenge share banner — εμφανίζεται μόνο σε καλή μέρα μετά τις 16:00
            if showChallengeBanner {
                challengeBanner
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer().frame(maxHeight: 16)

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

                    // Zone badge — pulses in danger zone
                    Text(store.currentZone.displayName(language: appLanguage))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(zoneColor.opacity(0.85))
                        )
                        .scaleEffect(badgePulse ? 1.08 : 1.0)
                        .animation(
                            store.currentZone == .problematic || store.currentZone == .heavy
                                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                : .default,
                            value: badgePulse
                        )

                    // Counter — spring bounce on pickup
                    Text("\(store.todayPickups) / \(dailyGoal)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(counterScale)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(zoneColor)
                            .frame(width: geo.size.width * goalProgress, height: 6)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: goalProgress)
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
            .padding(.bottom, 25)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.38), value: appeared)
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
        Button(action: {
            withAnimation { tabSelection.selectedTab = 2 }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                    Text(t("Top apps today", "Κορυφαίες εφαρμογές σήμερα", "Top-Apps heute"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                DeviceActivityReport(.top3Activity, filter: todayFilter)
                    .frame(height: 110)
                    .allowsHitTesting(false)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Temperature Pill

    private func temperaturePill(weather: WeatherData) -> some View {
        Button(action: {
            Task { await weatherManager.manualRefresh() }
        }) {
            let condition = conditionName(for: weather.condition)
            let city = weather.cityName.isEmpty || weather.cityName == "Current Location"
                       ? "" : weather.cityName
            let subtitle = [condition, city].filter { !$0.isEmpty }.joined(separator: " · ")

            VStack(alignment: .leading, spacing: 2) {
                // Row 1: emoji + temperature
                HStack(spacing: 5) {
                    if weatherManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.65)
                            .tint(.white)
                            .frame(width: 16)
                    } else {
                        Text(displayEmoji(for: weather.condition))
                            .font(.system(size: 13))
                    }
                    Text("\(Int(weather.temperature))°")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                // Row 2: condition · city (only if present)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isLightBackground {
                        RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3))
                    }
                    RoundedRectangle(cornerRadius: 12)
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

    // MARK: - Challenge Banner

    private var challengeBanner: some View {
        HStack(spacing: 12) {
            Text("🏆")
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(t("Great day!", "Εξαιρετική μέρα!", "Toller Tag!"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(t(
                    "Challenge a friend to beat your score?",
                    "Προκάλεσε έναν φίλο να τα πάει καλύτερα;",
                    "Fordere einen Freund heraus?"
                ))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            Button(action: shareChallenge) {
                Text(t("Share", "Μοιράσου", "Teilen"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.yellow))
            }
            .buttonStyle(.plain)

            Button(action: {
                withAnimation(.easeOut(duration: 0.25)) {
                    showChallengeBanner = false
                }
                ChallengeManager.markSuggestedToday()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [Color(red: 0.2, green: 0.55, blue: 0.9), Color(red: 0.4, green: 0.3, blue: 0.9)],
                    startPoint: .leading, endPoint: .trailing
                ))
        )
    }

    private func checkChallengeBanner() {
        let show = ChallengeManager.shouldSuggestShare(
            pickups: store.todayPickups,
            dailyGoal: dailyGoal > 0 ? dailyGoal : 15
        )
        withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
            showChallengeBanner = show
        }
    }

    private func shareChallenge() {
        guard let url = ChallengeManager.buildURL(
            displayName: displayName,
            weeklyPickups: store.weeklyPickups,
            streak: store.currentStreak,
            dailyGoal: dailyGoal > 0 ? dailyGoal : 15
        ) else { return }

        let payload = ChallengePayload(
            name: displayName.isEmpty ? "A friend" : displayName,
            weekly: store.weeklyPickups,
            streak: store.currentStreak,
            goal: dailyGoal > 0 ? dailyGoal : 15,
            sentAt: Date().timeIntervalSince1970
        )
        let msg = ChallengeManager.shareMessage(payload: payload, language: appLanguage)
        challengeShareItems = [msg, url.absoluteString]
        showShareSheet = true
        ChallengeManager.markSuggestedToday()
        withAnimation { showChallengeBanner = false }
    }

    // MARK: - Together Banner

    private func checkTogetherBanner() {
        guard FriendSyncManager.shared.hasPairs else { return }
        let myScreenTimeSecs = store.screenTimeLastTwoHours
        Task {
            let banners = await FriendSyncManager.shared.checkForTogetherBanner(
                myScreenTimeSecs: myScreenTimeSecs
            )
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.35).delay(0.6)) {
                    togetherBanners = banners
                }
            }
        }
    }

    private func togetherBannerView(data: TogetherBannerData) -> some View {
        HStack(spacing: 12) {
            Text("📱")
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(t(
                    "You & \(data.pair.name) are on your phones",
                    "Εσύ και ο \(data.pair.name) είστε στο κινητό",
                    "Du und \(data.pair.name) seid am Handy"
                ))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

                Text(t(
                    "\(data.totalMins) min in the last 2h — plan something more productive?",
                    "\(data.totalMins) λεπτά τις τελευταίες 2ώρ — κάντε κάτι πιο επικοδομητικό;",
                    "\(data.totalMins) Min. in 2h — wie wäre etwas Sinnvolleres?"
                ))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Button(action: {
                    FriendSyncManager.shared.markBannerShown(for: data.pair.deviceID)
                    messagingPair = data.pair
                    withAnimation { togetherBanners.removeAll { $0.id == data.id } }
                }) {
                    Text(t("Message", "Μήνυμα", "Schreiben"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)

                Button(action: {
                    FriendSyncManager.shared.markBannerShown(for: data.pair.deviceID)
                    withAnimation { togetherBanners.removeAll { $0.id == data.id } }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [Color(red: 0.9, green: 0.35, blue: 0.2), Color(red: 0.85, green: 0.2, blue: 0.55)],
                    startPoint: .leading, endPoint: .trailing
                ))
        )
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

