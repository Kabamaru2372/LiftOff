//
//  TotalActivityReport.swift
//  PicksyDeviceReport
//
//  Created by Fotios Pongas on 26.04.26.
//
//  Συγκεντρώνει per-app usage data για να εμφανιστεί στις views.

import DeviceActivity
import ExtensionKit
import FamilyControls
import ManagedSettings
import SwiftUI

// MARK: - Contexts

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let top3Activity = Self("Top 3 Activity")
    /// Compact whole-device total, styled white for the Nudge pill.
    static let nudgeTotalTime = Self("Nudge Total Time")
    /// Compact whole-device total, styled large/accent for the Stats card.
    static let statsTotalTime = Self("Stats Total Time")
}

// MARK: - Data Model

/// Δεδομένα μιας εφαρμογής που εμφανίζονται στο report
struct AppUsageData: Identifiable {
    let id = UUID()
    let token: ApplicationToken?
    let bundleIdentifier: String?
    let displayName: String
    let duration: TimeInterval
}

/// Όλα τα δεδομένα του report
struct ActivityReport {
    let totalDuration: TimeInterval
    let apps: [AppUsageData]
}

// MARK: - Helper για data extraction

private func extractReport(from data: DeviceActivityResults<DeviceActivityData>, limit: Int? = nil) async -> ActivityReport {
    var totalDuration: TimeInterval = 0
    var apps: [AppUsageData] = []

    for await activityData in data {
        for await segment in activityData.activitySegments {
            totalDuration += segment.totalActivityDuration

            for await category in segment.categories {
                for await application in category.applications {
                    let duration = application.totalActivityDuration
                    guard duration > 0 else { continue }

                    let appName = application.application.localizedDisplayName ?? "Unknown"
                    let bundleID = application.application.bundleIdentifier
                    let token = application.application.token

                    apps.append(AppUsageData(
                        token: token,
                        bundleIdentifier: bundleID,
                        displayName: appName,
                        duration: duration
                    ))
                }
            }
        }
    }

    apps.sort { $0.duration > $1.duration }

    // NOTE: We do NOT write this total to the App Group. The DeviceActivityReport
    // extension is heavily sandboxed by Apple and cannot share data back to the
    // main app (UserDefaults/App Group writes are silently discarded on device).
    // The total can only be DISPLAYED via a hosted DeviceActivityReport view —
    // which is exactly how the Nudge and Stats screen-time figures now render.

    if let limit = limit {
        apps = Array(apps.prefix(limit))
    }

    return ActivityReport(totalDuration: totalDuration, apps: apps)
}

// MARK: - Total Activity Report (full list)

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ActivityReport) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReport {
        await extractReport(from: data)
    }
}

// MARK: - Top 3 Activity Report (compact για το NudgeView)

struct Top3ActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .top3Activity
    let content: (ActivityReport) -> Top3ActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReport {
        await extractReport(from: data, limit: 3)
    }
}

// MARK: - Compact total-time reports (whole-device screen time)
//
// These render ONLY the formatted total duration. Because the report extension
// can't pass the number back to the app, the Nudge pill and Stats card host
// these tiny reports to display the same total the Apps tab shows.

struct NudgeTotalTimeReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .nudgeTotalTime
    let content: (ActivityReport) -> TotalTimeLabelView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReport {
        await extractReport(from: data)
    }
}

struct StatsTotalTimeReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .statsTotalTime
    let content: (ActivityReport) -> StatsTotalTimeView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReport {
        await extractReport(from: data)
    }
}

