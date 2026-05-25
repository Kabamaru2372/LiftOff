//
//  AppsViewRefreshTrigger.swift
//  Picksy
//
//  Created by Fotios Pongas on 05.05.2026
//
//  Centralized trigger για refresh του DeviceActivityReport στο AppsView.
//
//  Το DeviceActivityReport extension χρειάζεται explicit refresh signal
//  σε ορισμένες περιπτώσεις (cold start, foreground after suspend κλπ).
//
//  Αυτή η class επιτρέπει σε διαφορετικά parts του app να τριγκάρουν
//  refresh χωρίς coupling.
//
//  Usage:
//    AppsViewRefreshTrigger.shared.refresh()       // Rate-limited (8 s cooldown)
//    AppsViewRefreshTrigger.shared.forceRefresh()  // Bypass cooldown for explicit user actions
//

import Foundation
import SwiftUI

@Observable
class AppsViewRefreshTrigger {

    /// Singleton instance
    static let shared = AppsViewRefreshTrigger()

    /// Changes whenever refresh is requested.
    /// AppsView observes this and re-renders the DeviceActivityReport.
    var refreshID: UUID = UUID()

    /// Counter για debugging - πόσες φορές έχει γίνει refresh
    private(set) var refreshCount: Int = 0

    private init() {}

    private var lastRefreshTime: Date = .distantPast
    private let minimumRefreshInterval: TimeInterval = 8.0

    /// Trigger refresh του AppsView with cooldown protection.
    /// Skips the refresh if called within `minimumRefreshInterval` seconds
    /// of the last refresh — use `forceRefresh()` for explicit user actions
    /// (manual refresh button, filter change, midnight rollover) where stale
    /// content is unacceptable regardless of when the last refresh happened.
    /// Καλείται από:
    /// - LiftOffApp στο launch
    /// - LiftOffApp στο foreground
    /// - Tab change σε Apps tab
    func refresh() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefreshTime)
        guard elapsed >= minimumRefreshInterval else {
            print("[AppsViewRefresh] ⏭️ Skipped — cooldown (\(String(format: "%.1f", elapsed))s < \(minimumRefreshInterval)s)")
            return
        }
        lastRefreshTime = now
        refreshID = UUID()
        refreshCount += 1
        print("[AppsViewRefresh] 🔄 Refresh #\(refreshCount)")
    }

    /// Force a refresh, bypassing the cooldown. Use for explicit user actions
    /// (manual refresh button, filter change, midnight rollover) where stale
    /// content is unacceptable regardless of when the last refresh happened.
    func forceRefresh() {
        lastRefreshTime = .distantPast
        refresh()
    }

    /// Pending work items — kept so callers can cancel before they fire.
    private var pendingWork: [DispatchWorkItem] = []

    /// Delayed refresh για cases που χρειάζονται warmup time.
    func refreshAfter(seconds: Double) {
        let work = DispatchWorkItem { [weak self] in
            self?.refresh()
        }
        pendingWork.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    /// Cancel all pending delayed refreshes.
    /// Call from onDisappear so stale timers don't fire after the view is gone
    /// and accidentally restart a load the extension is already completing.
    func cancelPendingRefreshes() {
        pendingWork.forEach { $0.cancel() }
        pendingWork.removeAll()
        print("[AppsViewRefresh] 🚫 Cancelled pending refreshes")
    }
}
