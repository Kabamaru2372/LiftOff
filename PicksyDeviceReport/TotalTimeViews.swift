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

// MARK: - Picksy Score (computed here, where we have the real total)

/// Picksy Score from Apple's REAL whole-device data. Score = (pickups +
/// minutes×5) ÷ 20 — identical to PicksyScore in the main app. Both inputs are
/// Apple-accurate (rendered here in the extension): screen-time minutes from
/// totalDuration, pickups from numberOfPickups. This is why the displayed score
/// matches Settings, unlike the app-side estimate.
private func picksyScore(_ report: ActivityReport) -> Int {
    let minutes = Int(report.totalDuration) / 60
    let raw = report.totalPickups + minutes * 5
    return (raw + 10) / 20
}

/// Score color — mirrors the Stats card's scoreAccentColor on the ÷20 scale.
private func scoreAccentColor(_ score: Int) -> Color {
    if score == 0  { return .blue }
    if score < 5   { return .green }
    if score < 15  { return .blue }
    if score < 30  { return .orange }
    return .red
}

/// Nudge pill score (white, small) — replaces the old in-app Text.
struct NudgeScoreView: View {
    let report: ActivityReport

    var body: some View {
        Text("\(picksyScore(report))")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// Stats card score (large, accent-colored by score).
struct StatsScoreView: View {
    let report: ActivityReport

    var body: some View {
        let score = picksyScore(report)
        Text("\(score)")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(scoreAccentColor(score))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Pickups (Apple's REAL count — matches Settings → Screen Time)

/// Stats card pickups (large, green) — Apple's exact pickup count.
struct StatsPickupsView: View {
    let report: ActivityReport

    var body: some View {
        Text("\(report.totalPickups)")
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundColor(Color(red: 0.20, green: 0.78, blue: 0.35))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Nudge ring center pickups (big white number) — Apple's exact pickup count.
struct NudgePickupsView: View {
    let report: ActivityReport

    var body: some View {
        Text("\(report.totalPickups)")
            .font(.system(size: 58, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
