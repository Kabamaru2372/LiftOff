//
//  ContentView.swift
//  Picksy Watch
//
//  Main Watch screen. Two pages:
//   • Page 1 — Pickup ring (zone-colored) with count + score
//   • Page 2 — Details (screen time, score breakdown, streak)
//

import SwiftUI

struct ContentView: View {
    @State private var model = WatchDataModel.shared
    @State private var motion = MotionRewardManager.shared
    @State private var appeared = false

    var body: some View {
        TabView {
            ringPage
            detailsPage
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .overlay {
            if motion.showReward {
                rewardOverlay
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: motion.showReward)
    }

    // MARK: - Reward overlay

    private var rewardOverlay: some View {
        VStack(spacing: 8) {
            Text("👟")
                .font(.system(size: 46))
            Text(model.t("Keep it up!", "Συνέχισε έτσι!", "Weiter so!"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(model.t("Moving, not scrolling", "Κινείσαι, δεν σκρολάρεις", "In Bewegung, nicht am Handy"))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.25))
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Page 1: Ring

    private var ringPage: some View {
        ZStack {
            // Ambient zone glow
            Circle()
                .fill(model.zone.color.opacity(0.18))
                .blur(radius: 24)
                .frame(width: 150, height: 150)

            // Track
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 9)

            // Progress arc
            Circle()
                .trim(from: 0, to: appeared ? model.goalProgress : 0)
                .stroke(model.zone.color,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: model.zone.color.opacity(0.6), radius: 6)
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: appeared)
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: model.goalProgress)

            // Center content
            VStack(spacing: 1) {
                Text("\(model.todayPickups)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())

                Text("/ \(model.dailyGoal)")
                    .font(.system(size: 13, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                Text(model.zone.displayName(language: model.appLanguage))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(model.zone.color.opacity(0.85)))
                    .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
        .overlay(alignment: .top) {
            if motion.isMoving {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 10, weight: .semibold))
                    Text(model.t("Moving", "Κίνηση", "Aktiv"))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.85)))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: motion.isMoving)
    }

    // MARK: - Page 2: Details

    private var detailsPage: some View {
        VStack(spacing: 10) {
            Text("Picksy")
                .font(.system(size: 17, weight: .light, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            // Score
            statRow(
                icon: "star.fill",
                tint: model.zone.color,
                label: "Score",
                value: "\(model.picksyScore)"
            )

            // Screen time
            statRow(
                icon: "hourglass",
                tint: .cyan,
                label: model.t("Screen", "Οθόνη", "Bildschirm"),
                value: model.screenTimeLabel
            )

            // Streak
            statRow(
                icon: "flame.fill",
                tint: .orange,
                label: model.t("Streak", "Σερί", "Serie"),
                value: "\(model.currentStreak)"
            )

            // Active movement today (from MotionRewardManager)
            statRow(
                icon: "figure.walk",
                tint: Color(red: 0.20, green: 0.78, blue: 0.35),
                label: model.t("Active", "Κίνηση", "Aktiv"),
                value: "\(motion.activeMinutesToday)m"
            )

            Text(model.t("lower = better", "χαμηλότερο = καλύτερο", "niedriger = besser"))
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }

    private func statRow(icon: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(tint)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
        )
    }
}

#Preview {
    ContentView()
}
