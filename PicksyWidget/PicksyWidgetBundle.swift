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
        PicksyWidget()
        // PicksyWidgetControl() — αφαιρέθηκε, δεν χρειάζεται
        // PicksyWidgetLiveActivity() — αφαιρέθηκε, έχουμε ήδη UnPluqLiveExtension
    }
}

