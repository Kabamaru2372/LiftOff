// PlantHealthView.swift
// Picksy
//
// Nudge screen companion to the Dynamic Island's plant: grows continuously
// while the phone stays down, wilts (never resets instantly) on each pickup
// session. TimelineView recomputes the live health every second so growth
// animates smoothly while this screen is open — no Timer/state polling needed,
// and it automatically stops ticking when the view disappears.

import SwiftUI

struct PlantHealthView: View {
    @Environment(DataStore.self) private var store
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @State private var breathe = false
    @State private var wiltShake: CGFloat = 0
    @State private var wiltFlash = false
    @State private var growPop: CGFloat = 1.0
    @State private var growGlow = false

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            let checkpoint = DataStore.plantHealthCheckpoint()
            let health = DataStore.extrapolatedPlantHealth(
                baseline: checkpoint.baseline,
                baselineTime: checkpoint.time,
                isWilting: checkpoint.isWilting
            )
            let stage = stageIndex(for: health)

            HStack(spacing: 10) {
                Text(emoji(for: health))
                    .font(.system(size: 26))
                    .scaleEffect(growthScale(for: health) * (breathe ? 1.05 : 0.97) * growPop)
                    .rotationEffect(.degrees(wiltShake != 0 ? wiltShake : swayDegrees(for: health)))
                    .shadow(color: growGlow ? Color.green.opacity(0.55) : .clear, radius: growGlow ? 8 : 0)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: breathe)
                    .animation(.easeInOut(duration: 1.0), value: health)

                VStack(alignment: .leading, spacing: 3) {
                    Text(stageLabel(for: health))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: stage)
                    ProgressView(value: health, total: 100)
                        .tint(plantColor(for: health))
                        .frame(width: 84)
                        .animation(.easeInOut(duration: 1.0), value: health)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(.ultraThinMaterial).opacity(wiltFlash ? 0.95 : 0.55)
            )
            .overlay(
                Capsule().strokeBorder(
                    wiltFlash ? Color.red.opacity(0.45) : (growGlow ? Color.green.opacity(0.4) : Color.clear),
                    lineWidth: 1.5
                )
            )
            .onChange(of: stage) { old, new in
                if new > old { fireGrowAnimation() }
            }
        }
        .onAppear { breathe = true }
        .onDisappear { breathe = false }
        .onChange(of: store.plantWiltTrigger) { _, _ in
            fireWiltAnimation()
        }
    }

    /// Continuous size growth WITHIN a stage, on top of the discrete emoji swap
    /// at stage breakpoints — so the plant visibly fills out as health rises
    /// instead of only changing at the four breakpoints.
    private func growthScale(for health: Double) -> CGFloat {
        0.86 + CGFloat(health / 100.0) * 0.32
    }

    /// A slow idle sway whose amplitude grows with health — a seedling sits
    /// almost still, a flourishing tree gently sways, reinforcing "alive and
    /// thriving" the longer the phone stays down.
    private func swayDegrees(for health: Double) -> Double {
        let amplitude = 1.5 + (health / 100.0) * 5.5
        return breathe ? amplitude : -amplitude
    }

    private func stageIndex(for health: Double) -> Int {
        switch health {
        case ..<20: return 0
        case ..<40: return 1
        case ..<60: return 2
        case ..<80: return 3
        default:    return 4
        }
    }

    /// Rewarding "level up" pop — a quick spring bounce + soft green glow +
    /// gentle haptic — distinct from both the idle breathe and the wilt shake,
    /// so crossing a growth stage actually feels like an earned moment.
    private func fireGrowAnimation() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) {
            growPop = 1.32
        }
        withAnimation(.easeIn(duration: 0.2)) {
            growGlow = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                growPop = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.4)) {
                growGlow = false
            }
        }
    }

    /// Warning haptic + a quick shake/red-flash — distinct from the gentle idle
    /// breathe, so a wilt actually feels like a small, immediate consequence
    /// instead of blending into the continuous growth animation.
    private func fireWiltAnimation() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.easeInOut(duration: 0.08).repeatCount(5, autoreverses: true)) {
            wiltShake = 8
        }
        withAnimation(.easeIn(duration: 0.15)) {
            wiltFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                wiltShake = 0
                wiltFlash = false
            }
        }
    }

    private func emoji(for health: Double) -> String {
        switch health {
        case ..<20: return "🌱"
        case ..<40: return "🌿"
        case ..<60: return "🪴"
        case ..<80: return "🌳"
        default:    return "🌲"
        }
    }

    private func stageLabel(for health: Double) -> String {
        switch health {
        case ..<20: return t("Seedling", "Σπόρος", "Sämling")
        case ..<40: return t("Sprouting", "Φυτρώνει", "Keimt")
        case ..<60: return t("Growing", "Μεγαλώνει", "Wächst")
        case ..<80: return t("Thriving", "Ανθίζει", "Gedeiht")
        default:    return t("Flourishing", "Ακμάζει", "Blüht auf")
        }
    }

    private func plantColor(for health: Double) -> Color {
        switch health {
        case ..<20: return .brown
        case ..<40: return .yellow
        case ..<60: return .mint
        case ..<80: return .green
        default:    return Color(red: 0.1, green: 0.5, blue: 0.2)
        }
    }
}
