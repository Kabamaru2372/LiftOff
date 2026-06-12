// LiftOffLiveLiveActivity.swift
// LiftOffLive
//
// Created by Fotios Pongas 24.03.2026
// Αυτό ζωγραφίζει το Live Activity στο Lock Screen
// και στο Dynamic Island.

//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Duel time formatting
//
// Duel metric = screen time (seconds). Three sizes for the three DI densities:
//   full    "2h 05m" / "13m"   — lock screen & expanded regions
//   compact "2h05"   / "13m"   — compact leading/trailing pills
//   minimal "2h" / "13"        — the tiny circle

private func duelTimeFull(_ secs: Int) -> String {
    let m = secs / 60
    return m < 60 ? "\(m)m" : String(format: "%dh %02dm", m / 60, m % 60)
}

private func duelTimeCompact(_ secs: Int) -> String {
    let m = secs / 60
    return m < 60 ? "\(m)m" : String(format: "%dh%02d", m / 60, m % 60)
}

private func duelTimeMinimal(_ secs: Int) -> String {
    let m = secs / 60
    return m < 60 ? "\(m)" : "\(m / 60)h"
}

/// Winner-coloring: less screen time = winning (green), more = losing (red).
private func duelColor(mine: Int, theirs: Int, winning: Color, losing: Color, neutral: Color) -> Color {
    mine < theirs ? winning : (mine > theirs ? losing : neutral)
}

struct LiftOffLiveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiftOffActivityAttributes.self) { context in
            // LOCK SCREEN view
            // Priority: Focus > Duel > Normal

            if let focusEnd = context.state.focusEndTime {
                // — Focus mode lock screen —
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            Text("Focus")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Text(timerInterval: Date()...focusEnd, countsDown: true)
                            .font(.system(size: 28, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(context.state.focusPickupCount)")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        Text("pickups")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(16)
                .activityBackgroundTint(Color(red: 0.12, green: 0.12, blue: 0.14))

            } else if let opponent = context.state.duelOpponentName {
                // — Duel mode lock screen (screen time, lower wins) —
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        Text(duelTimeFull(context.state.duelMySecs))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundColor(duelColor(
                                mine: context.state.duelMySecs,
                                theirs: context.state.duelTheirSecs,
                                winning: Color(red: 0.4, green: 1.0, blue: 0.6),
                                losing: Color(red: 1.0, green: 0.35, blue: 0.35),
                                neutral: .white
                            ))
                    }
                    Spacer()
                    Text("⚔️")
                        .font(.system(size: 22))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(opponent)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                        Text(duelTimeFull(context.state.duelTheirSecs))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundColor(duelColor(
                                mine: context.state.duelTheirSecs,
                                theirs: context.state.duelMySecs,
                                winning: Color(red: 0.4, green: 1.0, blue: 0.6),
                                losing: Color(red: 1.0, green: 0.35, blue: 0.35),
                                neutral: .white
                            ))
                    }
                }
                .padding(16)
                .activityBackgroundTint(Color(red: 0.18, green: 0.14, blue: 0.30))

            } else {
                // — Normal lock screen —
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(context.state.pickupCount)")
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        Text("pickups today")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Text(context.state.currentQuote)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                        .frame(maxWidth: 180)
                }
                .padding(16)
                .activityBackgroundTint(Color(red: 0.22, green: 0.54, blue: 0.87))
            }

        } dynamicIsland: { context in
            // DYNAMIC ISLAND views
            // Priority: Focus > Duel > Normal

            DynamicIsland {
                // — Expanded leading —
                DynamicIslandExpandedRegion(.leading) {
                    if let focusEnd = context.state.focusEndTime {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Focus")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.orange)
                            Text(timerInterval: Date()...focusEnd, countsDown: true)
                                .font(.system(size: 22, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(.orange)
                        }
                        .padding(.leading, 4)
                    } else if context.state.duelOpponentName != nil {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text(duelTimeFull(context.state.duelMySecs))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .foregroundStyle(duelColor(
                                    mine: context.state.duelMySecs,
                                    theirs: context.state.duelTheirSecs,
                                    winning: .green, losing: .red, neutral: .primary
                                ))
                        }
                        .padding(.leading, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(context.state.pickupCount)")
                                .font(.system(size: 28, weight: .medium, design: .rounded))
                            Text("pickups")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 4)
                    }
                }

                // — Expanded trailing —
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.focusEndTime != nil {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(context.state.focusPickupCount)")
                                .font(.system(size: 28, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Text("during focus")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 4)
                    } else if let opponent = context.state.duelOpponentName {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(opponent)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(duelTimeFull(context.state.duelTheirSecs))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .foregroundStyle(duelColor(
                                    mine: context.state.duelTheirSecs,
                                    theirs: context.state.duelMySecs,
                                    winning: .green, losing: .red, neutral: .primary
                                ))
                        }
                        .padding(.trailing, 4)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(context.attributes.dailyGoal)")
                                .font(.system(size: 28, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("goal")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 4)
                    }
                }

                // — Expanded bottom —
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.focusEndTime != nil {
                        Text("Stay present 🍃")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.top, 4)
                    } else if context.state.duelOpponentName != nil {
                        Text("⚔️ Screen-time duel · less by midnight wins")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.top, 4)
                    } else {
                        Text(context.state.currentQuote)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.top, 4)
                    }
                }

            } compactLeading: {
                if context.state.focusEndTime != nil {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                } else if context.state.duelOpponentName != nil {
                    Text(duelTimeCompact(context.state.duelMySecs))
                        .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(duelColor(
                            mine: context.state.duelMySecs,
                            theirs: context.state.duelTheirSecs,
                            winning: .green, losing: .red, neutral: .primary
                        ))
                        .padding(.leading, 2)
                } else {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }

            } compactTrailing: {
                if let focusEnd = context.state.focusEndTime {
                    Text(timerInterval: Date()...focusEnd, countsDown: true)
                        .font(.system(size: 14, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.orange)
                        .frame(maxWidth: 60)
                } else if context.state.duelOpponentName != nil {
                    Text(duelTimeCompact(context.state.duelTheirSecs))
                        .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(duelColor(
                            mine: context.state.duelTheirSecs,
                            theirs: context.state.duelMySecs,
                            winning: .green, losing: .red, neutral: .primary
                        ))
                        .padding(.trailing, 2)
                } else {
                    Text("\(context.state.pickupCount)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.blue)
                }

            } minimal: {
                // Minimal = tiny circle shown when Picksy is secondary (e.g. WiiM Now Playing
                // is primary). Show the most useful number that fits in the small space.
                if context.state.focusEndTime != nil {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                } else if context.state.duelOpponentName != nil {
                    // Show user's own screen time — fits in the circle, more useful than ⚔️
                    Text(duelTimeMinimal(context.state.duelMySecs))
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(duelColor(
                            mine: context.state.duelMySecs,
                            theirs: context.state.duelTheirSecs,
                            winning: .green, losing: .red, neutral: .white
                        ))
                } else {
                    Text("\(context.state.pickupCount)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}
