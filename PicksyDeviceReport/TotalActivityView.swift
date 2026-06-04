//
//  TotalActivityView.swift
//  PicksyDeviceReport
//
//  Redesigned: progress bars, percentages, context insights.

import FamilyControls
import ManagedSettings
import SwiftUI

struct TotalActivityView: View {
    let report: ActivityReport

    // MARK: - Helpers

    private var totalColor: Color {
        let hours = report.totalDuration / 3600
        if hours < 2  { return .green }
        if hours < 4  { return .blue }
        if hours < 6  { return .orange }
        return .red
    }

    private func barColor(rank: Int) -> Color {
        switch rank {
        case 0: return .red.opacity(0.75)
        case 1: return .orange.opacity(0.75)
        case 2: return Color(hue: 0.13, saturation: 0.8, brightness: 0.9).opacity(0.75) // amber
        default: return .blue.opacity(0.55)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "<1m" }
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Sticky header — stays put while list scrolls
            totalHeader

            // Scrollable app list only
            if report.apps.isEmpty {
                emptyState
            } else {
                ScrollView {
                    appList
                }
            }
        }
        .background(Color.clear)
    }

    // MARK: - Total Header

    private var totalHeader: some View {
        VStack(spacing: 10) {
            // Big total number
            VStack(spacing: 2) {
                Text("Total today")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                Text(formatDuration(report.totalDuration))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(totalColor)
            }

            // % of waking day context
            if report.totalDuration >= 60 {
                let wakingPercent = min(100, Int((report.totalDuration / 57600 * 100).rounded()))
                HStack(spacing: 5) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("~\(wakingPercent)% of your waking hours")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            // Top-2 insight chip
            if report.apps.count >= 2 && report.totalDuration > 0 {
                let top2 = Array(report.apps.prefix(2))
                let top2Time = top2.map(\.duration).reduce(0, +)
                let top2Pct = Int((top2Time / report.totalDuration * 100).rounded())
                let names = top2.map(\.displayName).joined(separator: " + ")

                HStack(spacing: 5) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("\(names) = \(top2Pct)% of total")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.orange.opacity(0.1)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    // MARK: - App List

    private var appList: some View {
        VStack(spacing: 0) {
            ForEach(Array(report.apps.enumerated()), id: \.element.id) { index, app in
                appRow(app, rank: index)
                if index < report.apps.count - 1 {
                    Divider()
                        .padding(.leading, 68)
                        .opacity(0.25)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.55))
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 32)
    }

    private func appRow(_ app: AppUsageData, rank: Int) -> some View {
        let pct = report.totalDuration > 0
            ? Int((app.duration / report.totalDuration * 100).rounded())
            : 0
        let fraction = report.totalDuration > 0
            ? CGFloat(app.duration / report.totalDuration)
            : 0

        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                // App icon
                if let token = app.token {
                    Label(token)
                        .labelStyle(AppRowLabelStyle())
                } else {
                    fallbackIcon(app)
                }

                Spacer()

                // Time + percentage
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatDuration(app.duration))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                    Text("\(pct)%")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar (aligned under the app name, skipping icon)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(rank: rank))
                        .frame(width: max(geo.size.width * fraction, 4), height: 3)
                }
            }
            .frame(height: 3)
            .padding(.leading, 52)  // skip icon column
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Fallback icon (no token)

    private func fallbackIcon(_ app: AppUsageData) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "app.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            }
            Text(app.displayName)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 32)
            Image(systemName: "hourglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No usage data yet")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            Text("Use your selected apps\nand check back soon")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

// MARK: - App Row Label Style

struct AppRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.system(size: 28))
                .frame(width: 40, height: 40)
            configuration.title
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}
