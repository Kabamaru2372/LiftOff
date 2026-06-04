//
//  Picksy_WatchApp.swift
//  Picksy Watch Watch App
//
//  Created by Fotios Pongas on 03.06.26.
//

import SwiftUI

@main
struct Picksy_Watch_Watch_AppApp: App {

    init() {
        // Start listening for data pushed from the iPhone.
        WatchConnectivityManager.shared.activate()
        // Start motion monitoring — rewards walking instead of phone use.
        MotionRewardManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color.black.ignoresSafeArea())
        }
    }
}
