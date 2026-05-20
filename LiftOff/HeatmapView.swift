//
//  HeatmapView.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.03.26.

import SwiftUI

struct HeatmapView: View {
    @Environment(HourlyTracker.self) var tracker
    @Environment(CheckInManager.self) var checkInManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private let labeledHours = [0, 6, 12, 18]

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    private var hasData: Bool { tracker.maxHourlyCount > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if hasData {
                // Grid
                heatmapGrid

                // Daily Comparison
                dailyComparisonSection

                // Worst hours
                worstHoursSection
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))

            Text(t(
                "No hourly data yet.\nKeep using Picksy and your heatmap will appear here.",
                "Δεν υπάρχουν δεδομένα ακόμα.\nΣυνέχισε να χρησιμοποιείς το Picksy και το heatmap θα εμφανιστεί εδώ.",
                "Noch keine Daten.\nNutze Picksy weiter und deine Heatmap erscheint hier."
            ))
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    // MARK: - Heatmap Grid

    private var heatmapGrid: some View {
        VStack(spacing: 4) {
            // Hour labels με labels για 0, 6, 12, 18
            HStack(spacing: 0) {
                Text("").frame(width: 56)
                ForEach(0..<24, id: \.self) { hour in
                    if labeledHours.contains(hour) {
                        Text("\(hour)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    } else {
                        Spacer().frame(maxWidth: .infinity)
                    }
                }
                Text("").frame(width: 28)
            }
            .padding(.bottom, 4)

            // Rows
            ForEach(0..<7, id: \.self) { dayIndex in
                HStack(spacing: 3) {
                    // Day label
                    Text(tracker.dayLabel(daysAgo: dayIndex))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(width: 56, alignment: .trailing)

                    // 24 cells με μεγαλύτερο μέγεθος
                    ForEach(0..<24, id: \.self) { hour in
                        let count = tracker.hourlyData[dayIndex][hour]
                        let intensity = cellIntensity(count: count)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(cellColor(intensity: intensity))
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .overlay(
                                Group {
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                                            .foregroundColor(intensity > 0.5 ? .white : .secondary)
                                    }
                                }
                            )
                    }

                    // Mood emoji στα δεξιά
                    moodForDay(dayIndex: dayIndex)
                        .frame(width: 28)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    // MARK: - Mood for Day

    @ViewBuilder
    private func moodForDay(dayIndex: Int) -> some View {
        let moods = checkInManager.last7DaysMoods
        // dayIndex 0 = σήμερα, ενώ moods index 6 = σήμερα
        let moodIndex = 6 - dayIndex

        if moodIndex >= 0 && moodIndex < 7, let mood = moods[moodIndex] {
            Circle()
                .fill(mood.color)
                .frame(width: 14, height: 14)
        } else {
            Circle()
                .fill(Color(.systemGray4).opacity(0.3))
                .frame(width: 14, height: 14)
        }
    }

    // MARK: - Daily Comparison

    private var dailyComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Today vs weekly average", "Σήμερα vs μέσος εβδομάδας", "Heute vs. Wochendurchschnitt"))
                .font(.system(size: 16, weight: .medium, design: .rounded))

            VStack(spacing: 8) {
                // Today line
                comparisonRow(
                    label: t("Today", "Σήμερα", "Heute"),
                    value: tracker.totalForDay(daysAgo: 0),
                    maxValue: maxComparisonValue,
                    color: .blue
                )

                // Average line
                comparisonRow(
                    label: t("Avg", "Μέσος", "Ø"),
                    value: weeklyAverage,
                    maxValue: maxComparisonValue,
                    color: .orange
                )
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))

            // Insight text
            insightText
        }
    }

    private func comparisonRow(label: String, value: Int, maxValue: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 24)

                    let width = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) * geo.size.width : 0
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.7))
                        .frame(width: max(width, 4), height: 24)
                }
            }
            .frame(height: 24)

            Text("\(value)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var weeklyAverage: Int {
        var total = 0
        for day in 0..<7 {
            total += tracker.totalForDay(daysAgo: day)
        }
        return total / 7
    }

    private var maxComparisonValue: Int {
        max(tracker.totalForDay(daysAgo: 0), weeklyAverage, 1)
    }

    @ViewBuilder
    private var insightText: some View {
        let today = tracker.totalForDay(daysAgo: 0)
        let avg = weeklyAverage
        let diff = today - avg

        HStack(spacing: 6) {
            if diff < 0 {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.green)
                Text(t(
                    "\(abs(diff)) less than your average. Great job!",
                    "\(abs(diff)) λιγότερα από τον μέσο σου. Μπράβο!",
                    "\(abs(diff)) weniger als dein Durchschnitt. Super!"
                ))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            } else if diff > 0 {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                Text(t(
                    "\(diff) more than your average.",
                    "\(diff) περισσότερα από τον μέσο σου.",
                    "\(diff) mehr als dein Durchschnitt."
                ))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            } else {
                Image(systemName: "equal.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                Text(t("Right on your average.", "Ακριβώς στον μέσο σου.", "Genau auf deinem Durchschnitt."))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Worst Hours

    @ViewBuilder
    private var worstHoursSection: some View {
        if !tracker.worstHours.isEmpty && tracker.worstHours[0].avgPickups > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("Your worst hours", "Οι χειρότερες ώρες σου", "Deine schlechtesten Stunden"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))

                VStack(spacing: 10) {
                    ForEach(tracker.worstHours.indices, id: \.self) { index in
                        let worst = tracker.worstHours[index]
                        if worst.avgPickups > 0 {
                            HStack(spacing: 12) {
                                Text(formatHour(worst.hour))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .frame(width: 90, alignment: .leading)

                                GeometryReader { geo in
                                    let maxAvg = tracker.worstHours[0].avgPickups
                                    let width = maxAvg > 0
                                        ? CGFloat(worst.avgPickups / maxAvg) * geo.size.width
                                        : 0

                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(barColor(index: index))
                                        .frame(width: max(width, 4), height: 24)
                                }
                                .frame(height: 24)

                                Text(String(format: "%.1f", worst.avgPickups))
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, alignment: .trailing)

                                if tracker.hasImproved(hour: worst.hour) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))

                Text(t(
                    "Improve during these hours for 2 days to unlock a reward!",
                    "Βελτιώσου σε αυτές τις ώρες για 2 μέρες και ξεκλείδωσε reward!",
                    "Verbessere dich 2 Tage lang in diesen Stunden und schalte eine Belohnung frei!"
                ))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Helpers

    private func cellIntensity(count: Int) -> Double {
        guard tracker.maxHourlyCount > 0 else { return 0 }
        return Double(count) / Double(tracker.maxHourlyCount)
    }

    private func cellColor(intensity: Double) -> Color {
        if intensity == 0 { return Color(.systemGray5).opacity(0.5) }
        return Color.blue.opacity(0.2 + intensity * 0.7)
    }

    private func barColor(index: Int) -> Color {
        switch index {
        case 0: return .red.opacity(0.7)
        case 1: return .orange.opacity(0.7)
        default: return .yellow.opacity(0.7)
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let endHour = (hour + 1) % 24
        return String(format: "%02d:00–%02d:00", hour, endHour)
    }
}

#Preview {
    HeatmapView()
        .environment(HourlyTracker())
        .environment(CheckInManager())
}

