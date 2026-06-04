//
//  AppsViewRefreshTrigger.swift
//  Picksy
//
//  Created by Fotios Pongas on 05.05.2026
//
//  Controls the SwiftUI identity of the DeviceActivityReport shown in AppsView
//  and NudgeView.
//
//  ⚠️ Why this is identity-based, not timer-based (the weeks-long blank-card bug):
//  DeviceActivityReport renders in a SEPARATE process and takes 2–5 s to warm up.
//  The old design changed `.id()` to a fresh UUID on every refresh (launch, tab
//  change, foreground, 20 s timers, …). Changing `.id()` DESTROYS and recreates
//  the report view — so every timer tore the extension down mid-render, and when
//  two fired close together the second teardown cancelled the first load,
//  leaving a permanently blank card.
//
//  Fix: the report's identity (`reportIdentity`) changes ONLY when the underlying
//  data scope genuinely changes — a new day or a new app selection — or when the
//  user explicitly asks for a hard refresh. Timers/foreground no longer churn it,
//  so the extension renders once and stays. DeviceActivityReport re-queries its
//  data on its own when the view re-appears, so numbers still stay fresh.
//
//  Usage:
//    AppsViewRefreshTrigger.shared.syncScope()     // appear/foreground — rebuild only if day/selection changed
//    AppsViewRefreshTrigger.shared.forceRefresh()  // explicit user action — one deliberate rebuild
//

import Foundation
import SwiftUI

@Observable
class AppsViewRefreshTrigger {

    /// Singleton instance
    static let shared = AppsViewRefreshTrigger()

    /// Stable SwiftUI identity for the DeviceActivityReport.
    /// Bound to `.id(...)` in AppsView / NudgeView. Changes ONLY on a real scope
    /// change (day or selection) or an explicit `forceRefresh()` — never on timers.
    private(set) var reportIdentity: String = ""

    /// Bumped only by explicit user-requested refreshes.
    private var generation: Int = 0

    /// Debug counter — how many deliberate rebuilds happened.
    private(set) var refreshCount: Int = 0

    private init() {
        reportIdentity = Self.computeScope(generation: 0)
    }

    // MARK: - Scope

    /// Identity = today's date + the manual generation counter.
    ///
    /// We intentionally do NOT fold the app selection into the identity here:
    /// • A selection change already triggers `forceRefresh()` from the picker's
    ///   `onChange` in AppsView, which bumps `generation`.
    /// • DeviceActivityReport re-renders on its own whenever its `filter` changes
    ///   (the filter reads the live selection), so the content stays correct even
    ///   without an identity change.
    /// This keeps the file dependency-free so it compiles in every target it
    /// belongs to (main app + Live Activity extension).
    private static func computeScope(generation: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let day = f.string(from: Date())
        return "\(day)|g\(generation)"
    }

    // MARK: - Public API

    /// Recompute the scope. Rebuilds the report ONLY if the day or the app
    /// selection actually changed since last time — otherwise it's a no-op, so
    /// there is no teardown and no blank flash. Call freely on appear/foreground.
    func syncScope() {
        let newID = Self.computeScope(generation: generation)
        guard newID != reportIdentity else { return }
        reportIdentity = newID
        print("[AppsViewRefresh] 🔁 Scope changed → \(newID)")
    }

    /// Explicit user-requested hard refresh (manual button, filter change,
    /// midnight rollover). Causes exactly one deliberate rebuild.
    func forceRefresh() {
        generation += 1
        refreshCount += 1
        reportIdentity = Self.computeScope(generation: generation)
        print("[AppsViewRefresh] 🔄 Force refresh #\(refreshCount) → \(reportIdentity)")
    }

    // MARK: - Back-compat shims
    //
    // Existing call sites (LiftOffApp, ContentView, AppsView) call these. They no
    // longer churn the report identity — that was the bug. They now just sync the
    // scope, which rebuilds only when the day/selection genuinely changed.

    /// Previously a rate-limited UUID churn. Now a safe scope sync (no teardown
    /// unless the scope changed).
    func refresh() {
        syncScope()
    }

    /// Pending work items — kept so callers can cancel before they fire.
    private var pendingWork: [DispatchWorkItem] = []

    /// Previously forced a delayed UUID churn (which cancelled in-flight loads).
    /// Now schedules a harmless delayed scope sync — catches a day rollover that
    /// happened while we were waiting, without ever tearing down a live render.
    func refreshAfter(seconds: Double) {
        let work = DispatchWorkItem { [weak self] in
            self?.syncScope()
        }
        pendingWork.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    /// Cancel all pending delayed scope syncs.
    func cancelPendingRefreshes() {
        pendingWork.forEach { $0.cancel() }
        pendingWork.removeAll()
    }
}
