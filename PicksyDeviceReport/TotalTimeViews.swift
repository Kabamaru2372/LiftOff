//
//  TotalTimeViews.swift
//  PicksyDeviceReport
//
//  Compact, single-number views that render the whole-device screen-time total.
//  Hosted by the Nudge pill and the Stats card so those screens show the exact
//  same figure as the Apps tab — the report extension can't pass the number
//  back to the app, so it must be rendered here.
//

import SwiftUI

// MARK: - Shared formatting

private func formatTotal(_ seconds: TimeInterval) -> String {
    let secs = Int(seconds)
    if secs < 60 { return "0m" }
    let h = secs / 3600
    let m = (secs % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}

/// Accent color by total duration — mirrors the Stats card thresholds.
/// NB: named `durationAccentColor` (not `accentColor`) to avoid colliding with
/// SwiftUI's deprecated `View.accentColor(_:)` modifier, which would otherwise
/// win name resolution inside a View body and return `some View`.
private func durationAccentColor(_ seconds: TimeInterval) -> Color {
    let mins = Int(seconds) / 60
    if mins == 0   { return .secondary }
    if mins < 60   { return .green }
    if mins < 120  { return .blue }
    if mins < 240  { return .orange }
    return .red
}

// MARK: - Nudge pill label (white, small)

struct TotalTimeLabelView: View {
    let report: ActivityReport

    var body: some View {
        Text(formatTotal(report.totalDuration))
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Stats card number (large, accent-colored)

struct StatsTotalTimeView: View {
    let report: ActivityReport

    var body: some View {
        Text(formatTotal(report.totalDuration))
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundColor(durationAccentColor(report.totalDuration))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
