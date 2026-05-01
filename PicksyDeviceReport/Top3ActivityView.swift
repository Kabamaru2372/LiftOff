//
//  Top3ActivityView.swift
//  PicksyDeviceReport
//
//  Created by Fotios Pongas on 27.04.2026
//
//  Compact view για τα top 3 apps — εμφανίζεται στο NudgeView.

import FamilyControls
import ManagedSettings
import SwiftUI

struct Top3ActivityView: View {
    let report: ActivityReport

    var body: some View {
        if report.apps.isEmpty {
            emptyView
        } else {
            VStack(spacing: 8) {
                ForEach(report.apps.prefix(3)) { app in
                    appRow(app)
                }
            }
        }
    }

    private var emptyView: some View {
        HStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            Text("No usage yet today")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func appRow(_ app: AppUsageData) -> some View {
        HStack(spacing: 10) {
            // App icon (μικρότερο)
            if let token = app.token {
                Label(token)
                    .labelStyle(CompactAppLabelStyle())
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 24, height: 24)
                    Image(systemName: "app.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                Text(app.displayName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatDuration(app.duration))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll

        if seconds < 60 {
            return "<1m"
        }
        return formatter.string(from: seconds) ?? "0m"
    }
}

// MARK: - Custom Label Style για compact rows

struct CompactAppLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .font(.system(size: 18))
                .frame(width: 24, height: 24)

            configuration.title
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}
