// ContentView.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026

import SwiftUI

struct ContentView: View {
    @Environment(DataStore.self) var store
    @Environment(RewardManager.self) var rewardManager
    @Environment(ProManager.self) var proManager
    @Environment(CheckInManager.self) var checkInManager
    @Environment(WeeklySummaryManager.self) var weeklyManager
    @Environment(TabSelection.self) var tabSelection
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @State private var showPaywall: Bool = false
    @State private var showCheckIn: Bool = false
    @State private var weeklySummaryItem: WeeklySummaryItem? = nil

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
            TabView(selection: $tabBinding.selectedTab) {
                NudgeView()
                    .tabItem {
                        Image(systemName: "hand.raised")
                        Text(t("Nudge", "Ώθηση", "Nudge"))
                    }
                    .tag(0)

                DashboardView()
                    .timeGradientBackground()
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text(t("Stats", "Στατιστικά", "Statistik"))
                    }
                    .tag(1)

                // NEW: Apps tab (αντικαθιστά το Heatmap)
                AppsView()
                    .timeGradientBackground()
                    .tabItem {
                        Image(systemName: "apps.iphone")
                        Text(t("Apps", "Εφαρμογές", "Apps"))
                    }
                    .tag(2)

                Group {
                    if proManager.isPro {
                        RewardsView()
                    } else {
                        ProLockedView(
                            feature: t("Rewards", "Επιβραβεύσεις", "Belohnungen"),
                            description: t(
                                "Unlock quote packs, badges, and gift codes as you improve.",
                                "Ξεκλείδωσε quote packs, badges και gift codes καθώς βελτιώνεσαι.",
                                "Schalte Zitatpakete, Abzeichen und Geschenkcodes frei."
                            ),
                            icon: "gift",
                            onUnlock: { showPaywall = true }
                        )
                    }
                }
                .timeGradientBackground()
                .tabItem {
                    Image(systemName: "gift")
                    Text(t("Rewards", "Δώρα", "Belohnungen"))
                }
                .tag(3)

                SettingsView()
                    .timeGradientBackground()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text(t("Settings", "Ρυθμίσεις", "Einstellungen"))
                    }
                    .tag(4)
            }
            .tint(.primary)

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
        .animation(.easeInOut(duration: 0.3), value: rewardManager.pendingReward != nil)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView().environment(proManager)
        }
        .sheet(isPresented: $showCheckIn) {
            DailyCheckInView()
                .environment(checkInManager)
        }
        .fullScreenCover(item: $weeklySummaryItem) { item in
            WeeklySummaryView(summary: item.summary)
        }
        .onAppear {
            checkForDailyCheckIn()
            checkForWeeklySummary()
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
}

