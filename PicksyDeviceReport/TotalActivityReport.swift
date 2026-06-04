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

    // Persist the TRUE total to the App Group so the main app (Stats tab, Nudge
    // screen, Watch, Friends/Duel scores) can display the exact same number the
    // Apps tab shows. Without this, those surfaces only had a threshold-based
    // lower bound (e.g. "1h" while the Apps tab showed "6h").
    //
    // Note: totalDuration is the full selected-apps total regardless of the
    // `limit` (which only trims the per-app list), so both the Total and Top-3
    // report contexts write a correct value.
    persistTotalToAppGroup(totalDuration)

    if let limit = limit {
        apps = Array(apps.prefix(limit))
    }

    return ActivityReport(totalDuration: totalDuration, apps: apps)
}

/// Writes today's authoritative screen-time total (seconds) to the shared App
/// Group, stamped with today's date. The main app reads it back as the
/// highest-priority source for `bestScreenTimeSecs`.
private func persistTotalToAppGroup(_ totalDuration: TimeInterval) {
    guard let defaults = UserDefaults(suiteName: "group.fotiospongas.picksy") else { return }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let today = formatter.string(from: Date())

    let totalSecs = Int(totalDuration)
    let storedDate = defaults.string(forKey: "picksy_report_screen_time_date")

    // On a new day the stored value belongs to yesterday — start fresh.
    let baseline = (storedDate == today)
        ? defaults.integer(forKey: "picksy_report_screen_time_secs")
        : 0

    // Screen time only grows during a day; never let a transient smaller read
    // (e.g. a partial extension load) shrink the displayed total.
    let changed = (totalSecs > baseline) || (storedDate != today)
    if totalSecs >= baseline {
        defaults.set(totalSecs, forKey: "picksy_report_screen_time_secs")
    }
    defaults.set(today, forKey: "picksy_report_screen_time_date")

    // Notify the main app (a separate process) that a fresh total is available.
    // Cross-process UserDefaults writes don't trigger SwiftUI updates on their
    // own — DataStore observes this Darwin notification and re-reads the value,
    // so the Stats tab, Nudge screen, Watch and Friends/Duel scores all refresh
    // to the exact same number the Apps tab shows.
    if changed {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("dev.fotiospongas.picksy.screenTimeUpdated" as CFString),
            nil, nil, true
        )
    }
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

