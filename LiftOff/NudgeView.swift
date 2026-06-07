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
    @AppStorage("dailyGoal") private var dailyGoal: Int = 50
    // C10 fix: read from the App Group suite — the extension writes here, not standard defaults
    @AppStorage("lastPickupTimestamp", store: UserDefaults(suiteName: "group.fotiospongas.picksy"))
    private var lastPickupTimestamp: Double = 0
    @AppStorage("challengeDisplayName") private var displayName: String = ""

    @State private var currentQuote: String = ""
    @State private var minutesSinceLastPickup: Int = 0
    @State private var refreshTimer: Timer? = nil
    @State private var showAccuracyInfo: Bool = false

    // v1.7: Activity suggestions sheet
    @State private var showActivitySuggestions: Bool = false

    // Focus Session sheet
    @State private var showFocusSession: Bool = false

    // Together banner (friends also overusing right now)
    @State private var togetherBanners: [TogetherBannerData] = []
    @State private var togetherNudgePair: TogetherBannerData? = nil   // for nudge dialog

    // Animations
    @State private var refreshTrigger = AppsViewRefreshTrigger.shared
    @State private var appeared: Bool = false
    @State private var counterScale: CGFloat = 1.0
    @State private var badgePulse: Bool = false
    @State private var titleShimmer: Bool = false
    @State private var moonGlow: Bool = false
    // Separate display state so we can drive .contentTransition via withAnimation
    @State private var displayPickups: Int = 0
    // C4 fix: store the closure-based observer token so we can properly remove it
    @State private var pickupObserverToken: NSObjectProtocol? = nil

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    /// Uncapped progress toward the personal daily goal (can exceed 1.0).
    private var goalRatio: Double {
        let goal = dailyGoal > 0 ? dailyGoal : 50
        return Double(store.todayPickups) / Double(goal)
    }

    private var goalProgress: Double {
        min(goalRatio, 1.0)
    }

    /// Home-screen zone is GOAL-relative (color + badge follow how close you are
    /// to YOUR daily goal), not the absolute research zones used elsewhere.
    private var goalZone: PickupZone {
        PickupZone.goalZone(progress: goalRatio)
    }

    private var zoneColor: Color {
        goalZone.color
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
        // NO app/category filter on purpose: this hosted report computes the
        // WHOLE-DEVICE screen-time total (all apps) for today, which is what
        // users understand as "screen time". That total (always ≥ the Apps
        // tab's selected-apps total) becomes the canonical value persisted to
        // the App Group and shown on the Nudge and Stats screens.
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
        ZStack(alignment: .top) {
            WeatherBackground(
                timeOfDay: timeOfDay,
                condition: weatherManager.activeCondition,
                isDimmed: false
            )

            // Celestial glow — κρύβεται όταν έχει συννεφιά/βροχή/ομίχλη
            let glowHidden = weatherManager.activeCondition == .cloudy ||
                             weatherManager.activeCondition == .rainy  ||
                             weatherManager.activeCondition == .thunderstorm ||
                             weatherManager.activeCondition == .foggy  ||
                             weatherManager.activeCondition == .snow
            if !glowHidden {
                let isDay = timeOfDay == .morning || timeOfDay == .midday
                let glowColor: Color = isDay ? .yellow : .cyan
                let celestialPos: (x: Double, y: Double) = timeOfDay == .night
                    ? TimeOfDay.moonCelestialPosition()
                    : (x: timeOfDay.celestialX, y: timeOfDay.celestialY)
                RadialGradient(
                    colors: [glowColor.opacity(moonGlow ? 0.35 : 0.06), .clear],
                    center: .init(x: celestialPos.x, y: celestialPos.y),
                    startRadius: 5,
                    endRadius: 180
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: moonGlow)
            }

            idleContent

            WeatherPillFABView()
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
        // Together nudge — confirmation dialog με preset μηνύματα
        .confirmationDialog(
            togetherNudgePair.map {
                t("Poke \($0.pair.name)", "Μήνυμα στον \($0.pair.name)", "\($0.pair.name) poken")
            } ?? "",
            isPresented: Binding(
                get: { togetherNudgePair != nil },
                set: { if !$0 { togetherNudgePair = nil } }
            ),
            titleVisibility: .visible
        ) {
            let messages = togetherMessages
            ForEach(messages, id: \.self) { msg in
                Button(msg) {
                    guard let pair = togetherNudgePair else { return }
                    let name = displayName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? "A friend" : displayName
                    Task {
                        await DuelManager.shared.sendNudge(
                            toDeviceID: pair.pair.deviceID,
                            text: msg,
                            senderName: name
                        )
                    }
                    withAnimation { togetherBanners.removeAll { $0.id == pair.id } }
                    togetherNudgePair = nil
                }
            }
            Button(t("Cancel", "Άκυρο", "Abbrechen"), role: .cancel) {
                togetherNudgePair = nil
            }
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
            // Pull the latest confirmed screen-time total from the App Group so
            // the score pill matches the Stats tab and Apps tab immediately.
            // The hosted Top-3 DeviceActivityReport (separate process) needs a
            // few seconds to warm up and write today's total; the Darwin
            // notification handles that, and these delayed reads are a safety net.
            store.refreshConfirmedScreenTime()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { store.refreshConfirmedScreenTime() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) { store.refreshConfirmedScreenTime() }
            startRefreshTimer()
            checkTogetherBanner()
            displayPickups = store.todayPickups   // seed ring counter on every appear
            // Entrance animation — τρέχει ΜΟΝΟ την πρώτη φορά (όχι σε κάθε tab switch)
            if !appeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appeared = true
                }
            }
            // Title shimmer (subtle breathing)
            if !titleShimmer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    titleShimmer = true
                }
            }
            // Moon glow pulse — ξεκινά μία φορά, τρέχει για πάντα
            if !moonGlow {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    moonGlow = true
                }
            }
            // Zone badge pulse (only in danger zone)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                badgePulse = goalZone == .problematic || goalZone == .heavy
            }

            // C4 fix: save the token so onDisappear can properly remove this observer.
            // The closure-based addObserver API requires removeObserver(token), NOT removeObserver(self, name:).
            if pickupObserverToken == nil {
                pickupObserverToken = NotificationCenter.default.addObserver(
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
                    // Ring counter rolls up via numericText transition
                    withAnimation(.bouncy(duration: 0.45)) {
                        displayPickups = store.todayPickups
                    }
                    // Ring number spring bounce
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                        counterScale = 1.35
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            counterScale = 1.0
                        }
                    }
                    // Update danger zone pulse
                    badgePulse = goalZone == .problematic || goalZone == .heavy
                }
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            // Δεν κάνουμε reset το appeared — οι κάρτες μένουν ορατές στο tab switch
            // Μόνο τα looping animations σταματούν για να μην τρέχουν off-screen
            titleShimmer = false
            badgePulse = false
            // C4 fix: use the stored token (closure-based API requires this form)
            if let token = pickupObserverToken {
                NotificationCenter.default.removeObserver(token)
                pickupObserverToken = nil
            }
        }
        .onChange(of: appLanguage) { _, _ in
            currentQuote = ActivityBank.random(weather: weatherManager.activeCondition, categories: activityPrefs.effectiveCategories)
        }
        // Smooth appearance of topAppsCard when FamilyControls auth resolves
        .animation(.easeOut(duration: 0.35), value: shouldShowTopApps)
    }

    // MARK: - Idle screen

    private var idleContent: some View {
        VStack(spacing: 16) {

            // Flexible top spacer — centers the whole block vertically
            // so the content isn't bunched at the top with empty space below.
            Spacer(minLength: 16)

            // Picksy title — subtle shimmer
            Text("Picksy")
                .font(.system(size: 32, weight: .light, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)
                .scaleEffect(titleShimmer ? 1.03 : 1.0)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.05), value: appeared)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: titleShimmer)

            Spacer(minLength: 12)

            // ── HERO: Pickup ring ─────────────────────────────────────
            pickupRingCard

            // ── Screen Time pill ─────────────────────────────────────
            // The ring above shows today's pickups (this device). Here we show the
            // whole-device screen-time total — the metric the duel now uses —
            // rendered by the report extension (it can't pass the number back to
            // the app, so the value is drawn here exactly like the Apps tab).
            HStack(spacing: 5) {
                Image(systemName: "hourglass")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
                DeviceActivityReport(.nudgeTotalTime, filter: todayFilter)
                    .id(refreshTrigger.reportIdentity)
                    .frame(width: 72, height: 20)
                Text(t("screen time today", "χρόνος οθόνης σήμερα", "Bildschirmzeit heute"))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(.ultraThinMaterial).opacity(0.5)
            )
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.42), value: appeared)

            Spacer(minLength: 12)

            // ── Utility cards ─────────────────────────────────────────

            // Top 3 apps card
            if shouldShowTopApps {
                topAppsCard
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: appeared)
                    .transition(.opacity.combined(with: .offset(y: 8)))
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

            // "Τι να κάνω τώρα;" button
            activitySuggestionsButton
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.30), value: appeared)

            // Together banner
            ForEach(togetherBanners) { data in
                togetherBannerView(data: data)
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer(minLength: 12)
        }
    }

    // MARK: - Pickup Ring Card

    /// Replaces the old thin progress bar. Shows:
    ///  • Circular arc filling toward daily goal (zone-colored, rounded linecap)
    ///  • Glowing tip dot orbiting the arc end
    ///  • Large center number with rolling-digit transition + spring bounce on pickup
    ///  • Ambient glow that breathes in danger zones
    ///  • Zone badge + info button below
    private var pickupRingCard: some View {
        let ringSize:  CGFloat = 180
        let lineWidth: CGFloat = 12
        let tipRadius: CGFloat = ringSize / 2

        // The glow lives in .background so it does NOT contribute to the ZStack's
        // measured height (which caused the 200pt glow to compress all Spacers,
        // pushing the "Picksy" title behind the Dynamic Island).
        return ZStack {
            // ── Track ring ────────────────────────────────────────────────
            Circle()
                .stroke(Color.white.opacity(0.13), lineWidth: lineWidth)

            // ── Progress arc ──────────────────────────────────────────────
            Circle()
                .trim(from: 0, to: min(goalProgress, 1.0))
                .stroke(zoneColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: zoneColor.opacity(0.55), radius: 8)
                .animation(.spring(response: 0.7, dampingFraction: 0.78), value: goalProgress)

            // ── Glowing tip dot ───────────────────────────────────────────
            if goalProgress > 0.02 && goalProgress < 1.0 {
                Circle()
                    .fill(zoneColor)
                    .frame(width: 14, height: 14)
                    .shadow(color: zoneColor, radius: 7)
                    .offset(y: -tipRadius)
                    .rotationEffect(.degrees(360 * goalProgress))
                    .animation(.spring(response: 0.7, dampingFraction: 0.78), value: goalProgress)
            }

            // ── Goal-reached outer pulse ring ─────────────────────────────
            if goalProgress >= 1.0 {
                Circle()
                    .stroke(zoneColor.opacity(0.35), lineWidth: 2)
                    .frame(width: ringSize + 18, height: ringSize + 18)
                    .scaleEffect(badgePulse ? 1.07 : 0.97)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: badgePulse)
            }

            // ── Center: rolling number + goal + zone badge ────────────────
            VStack(spacing: 3) {
                Text("\(displayPickups)")
                    .font(.system(size: 58, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: zoneColor.opacity(0.55), radius: 10)
                    .scaleEffect(counterScale)
                    .contentTransition(.numericText(countsDown: false))

                Text("/ \(dailyGoal)")
                    .font(.system(size: 13, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.50))

                Spacer().frame(height: 4)

                // Zone badge + info — inside the ring so nothing overflows below
                HStack(spacing: 5) {
                    Text(goalZone.goalDisplayName(language: appLanguage))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(zoneColor.opacity(0.80)))
                        .scaleEffect(badgePulse ? 1.08 : 1.0)
                        .animation(
                            goalZone == .problematic || goalZone == .heavy
                                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                : .default,
                            value: badgePulse
                        )

                    Button(action: { showAccuracyInfo = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.40))
                    }
                }
            }
        }
        // Explicit frame keeps ZStack at exactly ringSize — the glow circle is in
        // .background so it extends visually beyond the frame without affecting layout.
        .frame(width: ringSize, height: ringSize)
        .background(
            Circle()
                .fill(zoneColor.opacity(badgePulse ? 0.30 : 0.14))
                .frame(width: 200, height: 200)
                .blur(radius: 30)
                .animation(
                    goalZone == .problematic || goalZone == .heavy
                        ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                        : .easeOut(duration: 0.7),
                    value: badgePulse
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)
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
                    "What can I do instead?",
                    "Τι άλλο μπορώ να κάνω;",
                    "Was kann ich stattdessen tun?"
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
            // Just navigate — the Apps tab's onAppear syncs the report scope.
            // We deliberately do NOT force a rebuild here: that tore the report
            // view down on every tap and caused the blank-card flash.
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
                    .id(refreshTrigger.reportIdentity)
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

    // MARK: - Together Banner

    /// 5 preset together-nudge messages, localized.
    private var togetherMessages: [String] {
        switch appLanguage {
        case "Ελληνικά":
            return [
                "📱 Πάλι στο κινητό είμαστε — πάμε για καφέ;",
                "😅 Κάνουμε και οι δυο doom scrolling... σταμάτα πρώτος!",
                "📞 Κατέβασε το κινητό και πάρε με τηλέφωνο να τα πούμε",
                "☕ Βλέπω ότι είσαι online — πάμε κάπου;",
                "🤙 Ψηφιακή αποτοξίνωση μαζί; Εσύ πρώτα."
            ]
        case "Deutsch":
            return [
                "📱 Mal wieder am Handy — Lust auf einen Kaffee?",
                "😅 Wir beide doomscrolln... hör zuerst auf!",
                "📞 Leg das Handy weg und ruf mich an",
                "☕ Ich seh, du bist online — sollen wir was machen?",
                "🤙 Digital Detox zusammen? Du fängst an."
            ]
        default:
            return [
                "📱 We're both on our phones again — wanna grab a coffee?",
                "😅 Doom scrolling together... you stop first!",
                "📞 Put the phone down and give me a call",
                "☕ I can see you're online — let's do something instead",
                "🤙 Digital detox together? You go first."
            ]
        }
    }

    private func checkTogetherBanner() {
        guard FriendSyncManager.shared.hasPairs else { return }
        // Together banner is a Pro feature (Friend Accountability)
        guard ProManager.shared.isPro else { return }
        let myScreenTimeSecs = store.screenTimeLastTwoHours
        Task {
            let banners = await FriendSyncManager.shared.checkForTogetherBanner(
                myScreenTimeSecs: myScreenTimeSecs
            )
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.35).delay(0.6)) {
                    togetherBanners = banners
                }
                // Mark as shown immediately on display — not just on tap.
                // Without this, navigating away and back re-shows the banner
                // repeatedly within the same 2-hour slot.
                for banner in banners {
                    FriendSyncManager.shared.markBannerShown(for: banner.pair.deviceID)
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
                    togetherNudgePair = data
                }) {
                    Text(t("Poke", "Μήνυμα", "Poke"))
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
            // Safety net: pull the latest whole-device total each minute in case
            // the cross-process Darwin notification was missed.
            store.refreshConfirmedScreenTime()
        }
    }
}

// MARK: - Draggable Weather Pill
//
// Separate struct gives SwiftUI a stable identity — no re-renders on every
// NudgeView state change.  Pattern mirrors ChallengeFABView exactly:
//   • pillContent is a plain View (NOT Button) — DragGesture on a Button conflicts
//   • .contentShape() makes the whole pill hittable
//   • .onTapGesture handles refresh; .gesture(DragGesture) handles dragging
//   • dragStart captured at gesture begin → 1:1 finger tracking, no drift
//   • AppStorage persists position across sessions

private struct WeatherPillFABView: View {

    @Environment(WeatherManager.self) private var weatherManager
    @AppStorage("appLanguage")      private var appLanguage: String = "English"
    @AppStorage("weatherPillX_v1")  private var pillX: Double = 0
    @AppStorage("weatherPillY_v1")  private var pillY: Double = 0

    @State private var dragStart: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var appeared: Bool = false

    private var timeOfDay: TimeOfDay {
        TimeOfDay.from(
            sunrise: weatherManager.currentWeather?.sunrise,
            sunset:  weatherManager.currentWeather?.sunset
        )
    }

    var body: some View {
        if let weather = weatherManager.currentWeather {
            let defaultX = pillX == 0 ? -100.0 : pillX
            let defaultY = pillY == 0 ? -320.0 : pillY

            GeometryReader { geometry in
                pillContent(weather: weather)
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: appeared)
                    .onTapGesture {
                        guard !isDragging else { return }
                        Task { await weatherManager.manualRefresh() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .global)
                            .onChanged { value in
                                if !isDragging {
                                    dragStart = CGSize(width: defaultX, height: defaultY)
                                    isDragging = true
                                }
                                var liveX = dragStart.width  + Double(value.translation.width)
                                var liveY = dragStart.height + Double(value.translation.height)
                                liveX = max(-geometry.size.width  / 2 + 90, min(geometry.size.width  / 2 - 90, liveX))
                                liveY = max(-geometry.size.height / 2 + 5,  min(geometry.size.height / 2 - 80, liveY))
                                pillX = liveX
                                pillY = liveY
                            }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isDragging = false
                                }
                            }
                    )
                    .offset(x: CGFloat(defaultX), y: CGFloat(defaultY))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appeared = true
                }
            }
        }
    }

    private func pillContent(weather: WeatherData) -> some View {
        let condition = conditionName(for: weather.condition)
        let city = weather.cityName.isEmpty || weather.cityName == "Current Location"
                   ? "" : weather.cityName
        let subtitle = [condition, city].filter { !$0.isEmpty }.joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 2) {
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
                    .foregroundColor(Color(white: 0.85))
            }
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(Color(white: 0.70))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func displayEmoji(for condition: WeatherCondition) -> String {
        if condition == .sunny && timeOfDay == .night { return "🌙" }
        return condition.emoji
    }

    private func conditionName(for condition: WeatherCondition) -> String {
        switch condition {
        case .sunny:
            return timeOfDay == .night
                ? t("Clear", "Αίθριος", "Klar")
                : t("Sunny", "Ηλιοφάνεια", "Sonnig")
        case .partlyCloudy: return t("Partly cloudy", "Μερικώς συννεφιά", "Teilweise bewölkt")
        case .cloudy:       return t("Cloudy", "Συννεφιά", "Bewölkt")
        case .rainy:        return t("Rainy", "Βροχή", "Regnerisch")
        case .thunderstorm: return t("Storm", "Καταιγίδα", "Gewitter")
        case .snow:         return t("Snow", "Χιόνι", "Schnee")
        case .foggy:        return t("Foggy", "Ομίχλη", "Neblig")
        case .windy:        return t("Windy", "Αέρας", "Windig")
        case .hot:          return t("Hot", "Ζέστη", "Heiß")
        case .cold:         return t("Cold", "Κρύο", "Kalt")
        case .unknown:      return ""
        }
    }

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
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

