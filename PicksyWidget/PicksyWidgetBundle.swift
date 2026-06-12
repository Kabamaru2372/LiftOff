//
//  PicksyWidgetBundle.swift
//  PicksyWidget
//
//  Created by Fotios Pongas on 09.04.26.
//

import WidgetKit
import SwiftUI

@main
struct PicksyWidgetBundle: WidgetBundle {
    var body: some Widget {
        PicksyWidget()           // Home screen: small + medium
#if os(iOS)
        PicksyLockScreenWidget() // Lock screen: circular + rectangular + inline (iOS 16+)
#endif
    }
}

