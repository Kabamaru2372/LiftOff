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

        } dynamicIsland: { context in
            // DYNAMIC ISLAND views

            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(context.state.pickupCount)")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                        Text("pickups")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
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

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.currentQuote)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 4)
                }

            } compactLeading: {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)

            } compactTrailing: {
                Text("\(context.state.pickupCount)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.blue)

            } minimal: {
                Text("\(context.state.pickupCount)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.blue)
            }
        }
    }
}
