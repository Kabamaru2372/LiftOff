// ContentView.swift
// LiftOff
//
// Created by Fotios Pongas 24.03.2026
// Το κεντρικό view — κρατάει τα tabs κάτω-κάτω.

import SwiftUI

struct ContentView: View {
    @Environment(RewardManager.self) var rewardManager
    @Environment(ProManager.self) var proManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    // ← false τώρα — ανοίγει μόνο αν ο χρήστης δεν είναι Pro
    @State private var showPaywall: Bool = false

    private var isGreek: Bool { appLanguage == "Ελληνικά" }

    var body: some View {
        ZStack {
            TabView {
                NudgeView()
                    .tabItem {
                        Image(systemName: "hand.raised")
                        Text("Nudge")
                    }

                DashboardView()
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Stats")
                    }

                // Heatmap — Pro ή preview
                Group {
                    if proManager.isPro {
                        HeatmapView()
                    } else {
                        ProLockedView(
                            feature: isGreek ? "Χάρτης θερμότητας" : "Heatmap",
                            description: isGreek
                                ? "Δες ποιες ώρες πιάνεις πιο πολύ το κινητό και βελτιώσου."
                                : "See which hours you pick up your phone the most and improve.",
                            icon: "square.grid.3x3.fill",
                            onUnlock: { showPaywall = true }
                        )
                    }
                }
                .tabItem {
                    Image(systemName: "square.grid.3x3.fill")
                    Text("Heatmap")
                }

                // Rewards — Pro ή preview
                Group {
                    if proManager.isPro {
                        RewardsView()
                    } else {
                        ProLockedView(
                            feature: isGreek ? "Επιβραβεύσεις" : "Rewards",
                            description: isGreek
                                ? "Ξεκλείδωσε quote packs, badges και gift codes καθώς βελτιώνεσαι."
                                : "Unlock quote packs, badges, and gift codes as you improve.",
                            icon: "gift",
                            onUnlock: { showPaywall = true }
                        )
                    }
                }
                .tabItem {
                    Image(systemName: "gift")
                    Text(isGreek ? "Δώρα" : "Rewards")
                }

                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text(isGreek ? "Ρυθμίσεις" : "Settings")
                    }
            }
            .tint(.primary)

            // Reward popup overlay (μόνο για Pro)
            if proManager.isPro, let reward = rewardManager.pendingReward {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        rewardManager.dismissReward()
                    }

                RewardPopup(
                    reward: reward,
                    language: appLanguage,
                    onClaim: {
                        rewardManager.claimReward(reward)
                    },
                    onDismiss: {
                        rewardManager.dismissReward()
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                )
                .padding(24)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: rewardManager.pendingReward != nil)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        // Μόλις τελειώσει ο έλεγχος entitlements, αν δεν είναι Pro
        // και είναι η πρώτη φορά → δείξε paywall
        .onAppear {
            Task {
                // Δίνουμε χρόνο στο ProManager να φορτώσει
                try? await Task.sleep(for: .seconds(0.5))
                if !proManager.isPro && !proManager.isCheckingEntitlements {
                    showPaywall = true
                }
            }
        }
        .onChange(of: proManager.isCheckingEntitlements) { _, stillChecking in
            // Όταν τελειώσει ο έλεγχος και δεν είναι Pro → paywall
            if !stillChecking && !proManager.isPro {
                showPaywall = true
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
    private var isGreek: Bool { appLanguage == "Ελληνικά" }

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
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 14))
                    Text(isGreek ? "Ξεκλείδωσε με LiftOff Pro" : "Unlock with LiftOff Pro")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.blue)
                )
            }
            .padding(.top, 8)

            Text("€4.99 — " + (isGreek ? "μία φορά" : "one time"))
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
}

