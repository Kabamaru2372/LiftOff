// CorrelationInsightView.swift
// Picksy
//
// Created by Fotios Pongas
//
// Card showing weather ↔ pickup correlations in DashboardView.
// "On sunny days you pick up 35% less 📱"

import SwiftUI

struct CorrelationInsightView: View {

    @Environment(CorrelationStore.self) var correlation
    @Environment(ProManager.self) var proManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    /// Callback fired when the locked card is tapped — caller presents the paywall.
    var onUnlockTap: (() -> Void)? = nil

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Section header (with Pro badge for non-Pro users)
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(t("Weather & Habits", "Καιρός & Συνήθειες", "Wetter & Gewohnheiten"))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !proManager.isPro {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 10))
                        Text("Pro")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.blue)
                }
            }

            if !proManager.isPro {
                lockedCard
            } else if !correlation.hasEnoughData {
                notEnoughDataCard
            } else {
                insightCard
            }
        }
    }

    // MARK: - Locked Pro Card

    private var lockedCard: some View {
        Button(action: { onUnlockTap?() }) {
            VStack(spacing: 12) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))

                Text(t(
                    "Discover how weather affects your phone pickups",
                    "Ανακάλυψε πώς ο καιρός επηρεάζει τα pickups σου",
                    "Entdecke, wie das Wetter dein Smartphone-Verhalten beeinflusst"
                ))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

                HStack(spacing: 6) {
                    Image(systemName: "lock.open.fill").font(.system(size: 11))
                    Text(t("Unlock with Pro", "Ξεκλείδωσε με Pro", "Mit Pro freischalten"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.blue))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Not enough data

    private var notEnoughDataCard: some View {
        HStack(spacing: 14) {
            Text("🌦️")
                .font(.system(size: 30))

            VStack(alignment: .leading, spacing: 4) {
                Text(t(
                    "Keep tracking \(correlation.daysUntilInsights) more day\(correlation.daysUntilInsights == 1 ? "" : "s")",
                    "\(correlation.daysUntilInsights) ακόμα \(correlation.daysUntilInsights == 1 ? "μέρα" : "μέρες")",
                    "Noch \(correlation.daysUntilInsights) \(correlation.daysUntilInsights == 1 ? "Tag" : "Tage") tracken"
                ))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary)

                Text(t(
                    "to see how weather affects your pickups",
                    "για να δεις πώς ο καιρός επηρεάζει τα σηκώματά σου",
                    "um zu sehen, wie das Wetter deine Griffe beeinflusst"
                ))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Top insight sentence (highlight)
            if let insight = correlation.insightText(language: appLanguage) {
                Text(insight)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.12))
                    )
            }

            // Condition comparison bars
            let summaries = correlation.conditionSummaries
            let maxAvg = summaries.map(\.avgPickups).max() ?? 1

            VStack(spacing: 10) {
                ForEach(Array(summaries.prefix(5).enumerated()), id: \.offset) { index, summary in
                    ConditionBarRow(
                        summary: summary,
                        maxAvg: maxAvg,
                        rank: index,
                        language: appLanguage
                    )
                }
            }

            // Days tracked note
            Text(t(
                "Based on \(correlation.snapshots.count) days of data",
                "Βάσει \(correlation.snapshots.count) ημερών δεδομένων",
                "Basierend auf \(correlation.snapshots.count) Tagen"
            ))
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

// MARK: - Condition Bar Row

private struct ConditionBarRow: View {

    let summary: ConditionSummary
    let maxAvg: Double
    let rank: Int       // 0 = best (lowest pickups)
    let language: String

    private var barColor: Color {
        switch rank {
        case 0: return .green
        case 1: return .blue.opacity(0.7)
        default: return .orange.opacity(Double(1) - Double(rank - 2) * 0.2)
        }
    }

    private var barFraction: CGFloat {
        guard maxAvg > 0 else { return 0 }
        return max(0.04, CGFloat(summary.avgPickups / maxAvg))
    }

    var body: some View {
        HStack(spacing: 10) {
            // Emoji
            Text(summary.condition.emoji)
                .font(.system(size: 16))
                .frame(width: 22)

            // Label
            Text(summary.condition.displayName(language: language))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * barFraction, height: 8)
                        .animation(.easeOut(duration: 0.5), value: barFraction)
                }
            }
            .frame(height: 8)

            // Avg label
            Text("\(Int(summary.avgPickups.rounded()))")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        CorrelationInsightView()
            .padding(24)
            .environment(CorrelationStore.shared)
            .environment(ProManager.shared)
    }
    .background(Color(.systemBackground))
}
