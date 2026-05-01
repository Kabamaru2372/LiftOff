//
//  PicksyDeviceReport.swift
//  PicksyDeviceReport
//
//  Created by Fotios Pongas on 26.04.26.
//

import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct PicksyDeviceReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Full report για το Apps tab
        TotalActivityReport { activityReport in
            TotalActivityView(report: activityReport)
        }

        // Compact report για το NudgeView (top 3 apps)
        Top3ActivityReport { activityReport in
            Top3ActivityView(report: activityReport)
        }
    }
}

