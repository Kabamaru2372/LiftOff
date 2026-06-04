//
//  Picksy_WatchApp.swift
//  Picksy Watch Watch App
//
//  Created by Fotios Pongas on 03.06.26.
//

import SwiftUI

@main
struct Picksy_Watch_Watch_AppApp: App {

    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, phase in
            // ⚡️ Battery: only track motion while the app is in the foreground.
            // When the watch face drops / app backgrounds, stop the pedometer so
            // nothing runs in the background.
            switch phase {
            case .active:                 MotionRewardManager.shared.start()
            case .inactive, .background:  MotionRewardManager.shared.pause()
            @unknown default:             break
            }
        }
    }
}
