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

struct LiftOffLiveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiftOffActivityAttributes.self) { context in
            // LOCK SCREEN view
            // Αυτό φαίνεται στο Lock Screen σαν banner

            if let focusEnd = context.state.focusEndTime {
                // Focus mode lock screen
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
            } else {
                // Normal lock screen
                HStack(spacing: 16) {
                    // Left: pickup count
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(context.state.pickupCount)")
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .foregroundColor(.white)

                        Text("pickups today")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    // Right: quote
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

            DynamicIsland {
                // Expanded — if/else πρέπει να είναι ΜΕΣΑ σε κάθε Region
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

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.focusEndTime != nil {
                        Text("Stay present 🍃")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
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
                } else {
                    Text("\(context.state.pickupCount)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.blue)
                }

            } minimal: {
                if context.state.focusEndTime != nil {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                } else {
                    Text("\(context.state.pickupCount)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}
