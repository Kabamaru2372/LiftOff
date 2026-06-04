// CorrelationInsightView.swift
// Picksy
//
// Redesigned: Weather, Time-of-Day, and Weekday insights in one rich card.

import SwiftUI

// MARK: - Time Slot

private struct TimeSlot: Identifiable {
    let id: String
    let label: String
    let emoji: String
    let total: Int
}

// MARK: - Main View

struct CorrelationInsightView: View {

    @Environment(CorrelationStore.self) var correlation
    @Environment(ProManager.self)       var proManager
    @Environment(HourlyTracker.self)    var hourly
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    var onUnlockTap: (() -> Void)? = nil

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":   return de
        default:          return en
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(t("Weather & Habits", "Καιρός & Συνήθειες", "Wetter & Gewohnheiten"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
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
                insightContent
            }
        }
    }

    // MARK: - Insight Content

    private var insightContent: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Weather section ──────────────────────────────────────────────
            sectionHeader(
                icon: "cloud.sun.fill",
                title: t("Weather Patterns", "Καιρός", "Wetter"),
                insight: correlation.insightText(language: appLanguage)
            )

            let summaries = correlation.conditionSummaries
            let maxWeather = summaries.map(\.avgPickups).max() ?? 1
            VStack(spacing: 8) {
                ForEach(Array(summaries.prefix(5).enumerated()), id: \.offset) { idx, s in
                    StatBarRow(
                        emoji: s.condition.emoji,
                        label: s.condition.displayName(language: appLanguage),
                        value: s.avgPickups,
                        maxValue: maxWeather,
                        rank: idx,
                        detail: "\(Int(s.avgPickups.rounded())) avg · \(s.days)d"
                    )
                }
            }
            .padding(.bottom, 16)

            Divider().padding(.bottom, 16)

            // ── Time of Day section ──────────────────────────────────────────
            let slots = timeSlots()
            let maxSlot = Double(slots.map(\.total).max() ?? 1)
            let peakSlot = slots.max(by: { $0.total < $1.total })

            sectionHeader(
                icon: "clock.fill",
                title: t("Time of Day", "Ώρα Ημέρας", "Tageszeit"),
                insight: peakSlot.map { peak in
                    t(
                        "Most pickups during the \(peak.label.lowercased())",
                        "Περισσότερα σηκώματα το \(peak.label.lowercased())",
                        "Meiste Griffe \(peak.label.lowercased())"
                    )
                }
            )

            VStack(spacing: 8) {
                ForEach(Array(slots.enumerated()), id: \.element.id) { idx, slot in
                    StatBarRow(
                        emoji: slot.emoji,
                        label: slot.label,
                        value: Double(slot.total) / 7.0,
                        maxValue: maxSlot / 7.0,
                        rank: slot.id == peakSlot?.id ? 99 : idx,
                        detail: "\(Int((Double(slot.total) / 7.0).rounded())) avg/day"
                    )
                }
            }
            .padding(.bottom, 16)

            Divider().padding(.bottom, 16)

            // ── Weekday vs Weekend + Temperature ────────────────────────────
            VStack(alignment: .leading, spacing: 10) {

                if let weekIns = correlation.weekdayInsight(language: appLanguage) {
                    extraInsightChip(text: weekIns)
                }
                if let tempIns = correlation.temperatureInsight(language: appLanguage) {
                    extraInsightChip(text: tempIns)
                }

                // Weekday vs weekend mini bars
                let wdAvg = correlation.weekdayAvgPickups
                let weAvg = correlation.weekendAvgPickups
                if wdAvg > 0 && weAvg > 0 {
                    let maxDW = max(wdAvg, weAvg)
                    StatBarRow(
                        emoji: "💼",
                        label: t("Weekdays", "Εργάσιμες", "Werktage"),
                        value: wdAvg, maxValue: maxDW,
                        rank: wdAvg <= weAvg ? 0 : 1,
                        detail: "\(Int(wdAvg.rounded())) avg"
                    )
                    StatBarRow(
                        emoji: "🏖️",
                        label: t("Weekends", "Σ/Κ", "Wochenende"),
                        value: weAvg, maxValue: maxDW,
                        rank: weAvg <= wdAvg ? 0 : 1,
                        detail: "\(Int(weAvg.rounded())) avg"
                    )
                }
            }
            .padding(.bottom, 14)

            // Footer
            Text(t(
                "Based on \(correlation.snapshots.count) days of data",
                "Βάσει \(correlation.snapshots.count) ημερών δεδομένων",
                "Basierend auf \(correlation.snapshots.count) Tagen"
            ))
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(icon: String, title: String, insight: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 6)

        if let insight {
            Text(insight)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.orange.opacity(0.12))
                )
                .padding(.bottom, 10)
        }
    }

    // MARK: - Extra Insight Chip

    private func extraInsightChip(text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.blue.opacity(0.09)))
    }

    // MARK: - Time Slots

    private func timeSlots() -> [TimeSlot] {
        // Aggregate across all 7 days
        let night     = (0..<6).map    { h in (0..<7).map { d in hourly.hourlyData[d][h] }.reduce(0, +) }.reduce(0, +)
        let morning   = (6..<12).map   { h in (0..<7).map { d in hourly.hourlyData[d][h] }.reduce(0, +) }.reduce(0, +)
        let afternoon = (12..<18).map  { h in (0..<7).map { d in hourly.hourlyData[d][h] }.reduce(0, +) }.reduce(0, +)
        let evening   = (18..<24).map  { h in (0..<7).map { d in hourly.hourlyData[d][h] }.reduce(0, +) }.reduce(0, +)

        return [
            TimeSlot(id: "night",     label: t("Night",     "Νύχτα",    "Nacht"),     emoji: "🌙", total: night),
            TimeSlot(id: "morning",   label: t("Morning",   "Πρωί",     "Morgen"),    emoji: "🌅", total: morning),
            TimeSlot(id: "afternoon", label: t("Afternoon", "Μεσημέρι", "Nachmittag"),emoji: "☀️", total: afternoon),
            TimeSlot(id: "evening",   label: t("Evening",   "Βράδυ",    "Abend"),     emoji: "🌆", total: evening),
        ]
    }

    // MARK: - Locked / Not enough data cards (unchanged)

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
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                HStack(spacing: 6) {
                    Image(systemName: "lock.open.fill").font(.system(size: 11))
                    Text(t("Unlock with Pro", "Ξεκλείδωσε με Pro", "Mit Pro freischalten"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(Color.blue))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
        .buttonStyle(.plain)
    }

    private var notEnoughDataCard: some View {
        HStack(spacing: 14) {
            Text("🌦️").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 4) {
                Text(t(
                    "Keep tracking \(correlation.daysUntilInsights) more day\(correlation.daysUntilInsights == 1 ? "" : "s")",
                    "\(correlation.daysUntilInsights) ακόμα \(correlation.daysUntilInsights == 1 ? "μέρα" : "μέρες")",
                    "Noch \(correlation.daysUntilInsights) \(correlation.daysUntilInsights == 1 ? "Tag" : "Tage") tracken"
                ))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                Text(t(
                    "to see how weather affects your pickups",
                    "για να δεις πώς ο καιρός επηρεάζει τα σηκώματά σου",
                    "um zu sehen, wie das Wetter deine Griffe beeinflusst"
                ))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

// MARK: - Stat Bar Row

private struct StatBarRow: View {

    let emoji: String
    let label: String
    let value: Double
    let maxValue: Double
    let rank: Int
    let detail: String

    private var barFraction: CGFloat {
        guard maxValue > 0 else { return 0.04 }
        return max(0.04, CGFloat(value / maxValue))
    }

    private var barColor: Color {
        if rank == 0  { return .green }
        if rank == 99 { return .orange }           // peak marker
        if rank == 1  { return .blue.opacity(0.65) }
        return .orange.opacity(max(0.35, 1.0 - Double(rank - 2) * 0.2))
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 15))
                .frame(width: 22)

            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 82, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * barFraction)
                        .animation(.easeOut(duration: 0.5), value: barFraction)
                }
            }
            .frame(height: 8)

            Text(detail)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 72, alignment: .trailing)
                .lineLimit(1)
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
            .environment(HourlyTracker())
    }
    .background(Color(.systemBackground))
}
