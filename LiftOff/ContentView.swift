// ContentView.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026
//
// v1.6 UPDATE - Fix: refresh AppsView όταν user tap "See details"
//                από usage insight modal.

import SwiftUI

struct ContentView: View {
    @Environment(DataStore.self) var store
    @Environment(RewardManager.self) var rewardManager
    @Environment(ProManager.self) var proManager
    @Environment(CheckInManager.self) var checkInManager
    @Environment(WeeklySummaryManager.self) var weeklyManager
    @Environment(TabSelection.self) var tabSelection
    @Environment(AchievementManager.self) var achievementManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @State private var showPaywall: Bool = false
    @State private var showCheckIn: Bool = false
    @State private var weeklySummaryItem: WeeklySummaryItem? = nil

    @State private var zoneInsightData: ZoneInsightData? = nil
    @State private var usageInsightData: UsageInsightData? = nil

    // Time-limit passcode gate (parental): shown when the limit is reached today
    // and a passcode is required.
    @State private var showPasscodeUnlock: Bool = false

    // "What's new" upgrade screen — shown once to existing users after a version bump.
    @AppStorage("picksy_last_seen_version") private var lastSeenVersion: String = ""
    @State private var showWhatsNew: Bool = false
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }


    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    private var dayNames: [String] {
        switch appLanguage {
        case "Ελληνικά": return ["Δευ", "Τρι", "Τετ", "Πεμ", "Παρ", "Σαβ", "Κυρ"]
        case "Deutsch": return ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        default: return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }
    }

    /// Shows the "What's new" screen once after an upgrade. ContentView is only
    /// shown to users past onboarding, so a version mismatch = an existing user
    /// who just upgraded. New users had the version marked seen during onboarding.
    private func checkWhatsNew() {
        guard !appVersion.isEmpty, lastSeenVersion != appVersion, !showWhatsNew else { return }
        showWhatsNew = true
    }

    /// Shows the passcode unlock screen if today's time limit is reached AND a
    /// passcode is required (parental gate).
    private func checkTimeLimitPasscodeGate() {
        guard PasscodeManager.shared.isRequired, !showPasscodeUnlock else { return }
        let d = UserDefaults(suiteName: "group.fotiospongas.picksy")
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let activeToday = d?.string(forKey: "picksy_timelimit_active") == f.string(from: Date())
        if activeToday { showPasscodeUnlock = true }
    }

    var body: some View {
        @Bindable var tabBinding = tabSelection

        ZStack {
            // ── Native TabView — γνήσιο liquid glass + safe areas ──
            TabView(selection: $tabBinding.selectedTab) {
                NudgeView()
                    .tabItem { Label(t("Nudge", "Ώθηση", "Nudge"), systemImage: "hand.raised") }
                    .tag(0)

                DashboardView().timeGradientBackground()
                    .tabItem { Label(t("Stats", "Στατιστικά", "Statistik"), systemImage: "chart.bar") }
                    .tag(1)

                AppsView().timeGradientBackground()
                    .tabItem { Label(t("Apps", "Εφαρμογές", "Apps"), systemImage: "apps.iphone") }
                    .tag(2)

                FriendsView()
                    .tabItem { Label(t("Friends", "Φίλοι", "Freunde"), systemImage: "person.2.fill") }
                    .tag(3)

                SettingsView().timeGradientBackground()
                    .tabItem { Label(t("Settings", "Ρυθμίσεις", "Einstellungen"), systemImage: "gearshape") }
                    .tag(4)
            }

            // ── Floating taunt / nudge bubble ────────────────────
            VStack {
                TauntBubbleOverlay()
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // ── Reward popup ─────────────────────────────────────
            if proManager.isPro, let reward = rewardManager.pendingReward {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { rewardManager.dismissReward() }

                RewardPopup(
                    reward: reward,
                    language: appLanguage,
                    onClaim: { rewardManager.claimReward(reward) },
                    onDismiss: { rewardManager.dismissReward() }
                )
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)))
                .padding(24)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
        .animation(.easeInOut(duration: 0.3), value: rewardManager.pendingReward != nil)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView().environment(proManager)
        }
        .sheet(isPresented: $showCheckIn) {
            DailyCheckInView()
                .environment(checkInManager)
        }
        .fullScreenCover(item: $weeklySummaryItem) { item in
            WeeklySummaryView(
                summary: item.summary,
                onUnlockTap: { showPaywall = true }
            )
        }
        // v1.6: Zone insight sheet
        .sheet(item: $zoneInsightData) { data in
            ZoneInsightView(
                pickupCount: data.pickupCount,
                zone: data.zone,
                onDismiss: {
                    zoneInsightData = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        // v1.6: Usage insight sheet
        .sheet(item: $usageInsightData) { data in
            UsageInsightView(
                level: data.level,
                onSeeDetails: {
                    handleSeeDetails()
                },
                onDismiss: {
                    usageInsightData = nil
                }
            )
            .presentationDetents([.large])  // v1.6: Πιο πολύ ύψος για να φαίνεται όλο
            .presentationDragIndicator(.hidden)
        }
        // "What's new" upgrade screen (existing users, once per version)
        .fullScreenCover(isPresented: $showWhatsNew) {
            WhatsNewView(onDismiss: {
                lastSeenVersion = appVersion
                showWhatsNew = false
            })
        }
        // Time-limit passcode gate (parental use)
        .fullScreenCover(isPresented: $showPasscodeUnlock) {
            PasscodeView(
                mode: .unlock,
                onUnlock: {
                    ShieldManager.shared.unlockTimeLimitSession()
                    showPasscodeUnlock = false
                },
                onCancel: { showPasscodeUnlock = false }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkTimeLimitPasscodeGate()
        }
        .onAppear {
            checkWhatsNew()
            checkForDailyCheckIn()
            checkForWeeklySummary()
            checkTimeLimitPasscodeGate()

            if let pending = NotificationDelegate.shared.pendingZoneInsight {
                zoneInsightData = pending
                NotificationDelegate.shared.pendingZoneInsight = nil
            }

            if let pending = NotificationDelegate.shared.pendingUsageInsight {
                usageInsightData = pending
                NotificationDelegate.shared.pendingUsageInsight = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NotificationDelegate.zoneInsightRequestedNotification
        )) { notification in
            if let zoneRaw = notification.userInfo?["zone"] as? String,
               let zone = PickupZone(rawValue: zoneRaw),
               let pickups = notification.userInfo?["pickups"] as? Int {
                zoneInsightData = ZoneInsightData(zone: zone, pickupCount: pickups)
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NotificationDelegate.usageInsightRequestedNotification
        )) { notification in
            if let level = notification.userInfo?["level"] as? Int {
                usageInsightData = UsageInsightData(level: level)
            }
        }
    }


    /// v1.6 FIX: Handle "See details" from usage insight modal.
    /// Κάνει τα εξής με σωστό ordering:
    /// 1. Close το sheet
    /// 2. Switch tab μετά από delay (sheet animation)
    /// 3. Multiple refresh triggers για να σιγουρευτούμε ότι data φορτώνει
    private func handleSeeDetails() {
        // 1. Close sheet
        usageInsightData = nil

        // 2. Switch tab μετά το sheet animation (~0.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            tabSelection.selectedTab = 2

            // 3. Trigger refresh ώστε να φορτώσει data στο tab
            // Multiple refreshes για robust coverage
            AppsViewRefreshTrigger.shared.refresh()
            AppsViewRefreshTrigger.shared.refreshAfter(seconds: 0.5)
            AppsViewRefreshTrigger.shared.refreshAfter(seconds: 1.5)
        }
    }

    private func checkForDailyCheckIn() {
        if checkInManager.shouldShowCheckIn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showCheckIn = true
            }
        }
    }

    private func checkForWeeklySummary() {
        guard weeklyManager.shouldShowSummary else { return }

        let summary = weeklyManager.computeSummary(
            weeklyPickups: store.weeklyPickups,
            hourlyScreenTimeSecs: store.hourlyScreenTimeSecs,
            checkInManager: checkInManager,
            streak: store.currentStreak,
            dayNames: dayNames
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            weeklySummaryItem = WeeklySummaryItem(summary: summary)
            weeklyManager.markAsShown()
        }
    }
}

// MARK: - Blur background για Custom Tab Bar

private struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: effect) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = effect }
}

// MARK: - Tab Fade-In Wrapper
// Κρατά το native TabView 100% αναλλοίωτο.
// Προσθέτει μόνο fade-in animation στο περιεχόμενο κάθε tab όταν επιλέγεται.

private struct TabFadeIn<Content: View>: View {
    let index: Int
    @Environment(TabSelection.self) private var tabSelection
    @State private var opacity: Double = 1
    let content: Content

    init(index: Int, @ViewBuilder _ content: () -> Content) {
        self.index = index
        self.content = content()
    }

    var body: some View {
        content
            .opacity(opacity)
            .onChange(of: tabSelection.selectedTab) { _, newTab in
                guard newTab == index else { return }
                opacity = 0
                withAnimation(.easeInOut(duration: 0.22)) {
                    opacity = 1
                }
            }
    }
}

// MARK: - Pro Locked View

struct ProLockedView: View {
    let feature: String
    let description: String
    let icon: String
    let onUnlock: () -> Void

    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text(feature)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            Text(description)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
                .lineSpacing(4)

            Button(action: onUnlock) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill").font(.system(size: 14))
                    Text(t("Unlock with Picksy Pro", "Ξεκλείδωσε με Picksy Pro", "Mit Picksy Pro freischalten"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color.blue))
            }
            .padding(.top, 8)

            Text("€4.99 — " + t("one time", "μία φορά", "einmalig"))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

#Preview {
    ContentView()
        .environment(DataStore())
        .environment(PickupDetector())
        .environment(LiveActivityManager())
        .environment(HourlyTracker())
        .environment(RewardManager())
        .environment(ProManager.shared)
        .environment(CheckInManager())
        .environment(WeeklySummaryManager())
        .environment(TabSelection())
        .environment(AchievementManager.shared)
        .environment(WeatherManager())
        .environment(CorrelationStore.shared)
}

