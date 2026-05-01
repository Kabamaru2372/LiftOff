//
//  TotalActivityView.swift
//  PicksyDeviceReport
//
//  Created by Fotios Pongas on 26.04.26.
//
//  Εμφανίζει per-app usage time σε λίστα με τα πραγματικά app icons.

import FamilyControls
import ManagedSettings
import SwiftUI

struct TotalActivityView: View {
    let report: ActivityReport

    var body: some View {
        VStack(spacing: 0) {
            // Total time header — διαφανές background
            VStack(spacing: 4) {
                Text("Total")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                Text(formatDuration(report.totalDuration))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            if report.apps.isEmpty {
                emptyState
            } else {
                appList
            }
        }
        .background(Color.clear)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "hourglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No usage data yet")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            Text("Use your selected apps and check back later")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - App List

    private var appList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(report.apps) { app in
                    appRow(app)
                    if app.id != report.apps.last?.id {
                        Divider()
                            .padding(.leading, 56)
                            .opacity(0.3)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground).opacity(0.6))
            )
            .padding(.horizontal, 8)
        }
    }

    private func appRow(_ app: AppUsageData) -> some View {
        HStack(spacing: 12) {
            if let token = app.token {
                Label(token)
                    .labelStyle(AppRowLabelStyle())
            } else {
                fallbackRow(app)
            }

            Spacer()

            Text(formatDuration(app.duration))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Fallback όταν δεν υπάρχει token
    private func fallbackRow(_ app: AppUsageData) -> some View {
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

    // MARK: - Formatting

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

// MARK: - Custom Label Style για app rows

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

