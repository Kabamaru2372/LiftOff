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
//    AppsViewRefreshTrigger.shared.refresh()  // From anywhere
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

    /// Trigger refresh του AppsView.
    /// Καλείται από:
    /// - LiftOffApp στο launch
    /// - LiftOffApp στο foreground
    /// - Tab change σε Apps tab
    /// - Manual refresh button
    /// - Picker change
    func refresh() {
        refreshID = UUID()
        refreshCount += 1
        print("[AppsViewRefresh] 🔄 Refresh triggered (#\(refreshCount))")
    }

    /// Delayed refresh για cases που χρειάζονται warmup time
    func refreshAfter(seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            self.refresh()
        }
    }
}
