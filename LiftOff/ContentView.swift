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

                AchievementsView(onUnlockTap: { showPaywall = true }).timeGradientBackground()
                    .tabItem { Label(t("Trophies", "Τρόπαια", "Trophäen"), systemImage: "trophy") }
                    .tag(3)

                SettingsView().timeGradientBackground()
                    .tabItem { Label(t("Settings", "Ρυθμίσεις", "Einstellungen"), systemImage: "gearshape") }
                    .tag(4)
            }

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
        .overlay { ChallengeFABView() }
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
        .onAppear {
            checkForDailyCheckIn()
            checkForWeeklySummary()

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

// MARK: - Challenge FAB (draggable)
//
// Approach: simultaneousGesture(DragGesture) directly on the ShareLink.
//
//   Tap  → DragGesture never fires (minimumDistance: 8 not met) → isDragging stays
//          false → ShareLink enabled → share sheet opens normally.
//
//   Drag → DragGesture fires → isDragging = true → ShareLink gets .disabled(true)
//          → finger lift does NOT trigger share sheet.
//          → 150ms after drag ends, isDragging resets to false.
//
//   Position: stored per-tab in AppStorage (5 tabs × 2 axes = 10 vars).
//   Origin: topTrailing anchor + .offset(x:y:) from that corner.
//   dragStart captures the saved offset at gesture begin, then we add
//   translation on each .onChanged — no drift, full 1:1 tracking.

private struct ChallengeFABView: View {

    @Environment(DataStore.self)    private var store
    @Environment(TabSelection.self) private var tabSelection
    @AppStorage("challengeDisplayName") private var displayName: String = ""
    @AppStorage("dailyGoal")            private var dailyGoal: Int = 50
    @AppStorage("appLanguage")          private var appLanguage: String = "English"

    // Ξεχωριστή θέση ανά tab — v2 keys reset any off-screen positions from old builds
    @AppStorage("challengeFABX_0_v2") private var x0: Double = 0
    @AppStorage("challengeFABY_0_v2") private var y0: Double = 0
    @AppStorage("challengeFABX_1_v2") private var x1: Double = 0
    @AppStorage("challengeFABY_1_v2") private var y1: Double = 0
    @AppStorage("challengeFABX_2_v2") private var x2: Double = 0
    @AppStorage("challengeFABY_2_v2") private var y2: Double = 0
    @AppStorage("challengeFABX_3_v2") private var x3: Double = 0
    @AppStorage("challengeFABY_3_v2") private var y3: Double = 0
    @AppStorage("challengeFABX_4_v2") private var x4: Double = 0
    @AppStorage("challengeFABY_4_v2") private var y4: Double = 0

    @State private var dragStart: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []

    // Διαβάζει offset του ενεργού tab
    private var currentX: Double {
        switch tabSelection.selectedTab {
        case 0: return x0; case 1: return x1; case 2: return x2
        case 3: return x3; default: return x4
        }
    }
    private var currentY: Double {
        switch tabSelection.selectedTab {
        case 0: return y0; case 1: return y1; case 2: return y2
        case 3: return y3; default: return y4
        }
    }

    // Γράφει offset στο ενεργό tab
    private func saveOffset(x: Double, y: Double) {
        switch tabSelection.selectedTab {
        case 0: x0 = x; y0 = y
        case 1: x1 = x; y1 = y
        case 2: x2 = x; y2 = y
        case 3: x3 = x; y3 = y
        default: x4 = x; y4 = y
        }
    }

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    var body: some View {
        let goal = dailyGoal > 0 ? dailyGoal : 50
        let url: URL = ChallengeManager.buildURL(
            displayName: displayName,
            weeklyPickups: store.weeklyPickups,
            streak: store.currentStreak,
            dailyGoal: goal
        ) ?? URL(string: "https://fotiospongas.dev/challenge")!

        let payload = ChallengePayload(
            name: displayName.isEmpty ? "A friend" : displayName,
            weekly: store.weeklyPickups,
            streak: store.currentStreak,
            goal: goal,
            sentAt: Date().timeIntervalSince1970,
            senderDeviceID: FriendSyncManager.shared.deviceID
        )
        let msg = ChallengeManager.shareMessage(payload: payload, language: appLanguage)

        // Αν το AppStorage είναι 0, ξεκινάει από μια default ορατή θέση
        let defaultX = currentX == 0 ? 120.0 : currentX
        let defaultY = currentY == 0 ? 250.0 : currentY

        GeometryReader { geometry in
            buttonLabel
                .contentShape(Capsule())
                .onTapGesture {
                    guard !isDragging else { return }
                    shareItems = [url, msg]
                    showShareSheet = true
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

                            // Clamp X: αριστερά/δεξιά όρια (κουμπί ~140pt πλάτος)
                            let minX = -geometry.size.width / 2 + 70
                            let maxX =  geometry.size.width / 2 - 70
                            liveX = max(minX, min(maxX, liveX))

                            // Clamp Y: πάνω/κάτω όρια (-60 για το TabBar)
                            let minY = -geometry.size.height / 2 + 20
                            let maxY =  geometry.size.height / 2 - 60
                            liveY = max(minY, min(maxY, liveY))

                            saveOffset(x: liveX, y: liveY)
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
        .sheet(isPresented: $showShareSheet) {
            FABShareSheet(items: shareItems)
        }
    }

    private var buttonLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(t("Challenge", "Πρόκληση", "Challenge"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.black)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(LinearGradient(
                    colors: [.yellow, .orange.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        )
    }
}

// MARK: - Share Sheet wrapper for FAB
// UIActivityViewController avoids the SwiftUI ShareLink gesture conflict.
private struct FABShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in dismiss() }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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

