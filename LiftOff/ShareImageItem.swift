//
//  ShareImageItem.swift
//  Picksy
//
//  Lightweight Identifiable wrapper for a share sheet image. Lives in its own
//  file (rather than DashboardView.swift) so it stays available to BOTH the
//  main app and the UnPluqLiveExtension target — WeeklySummaryView (shared with
//  the Live Activity extension) uses it, while DashboardView is main-app only.
//

import SwiftUI

struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}
