// TauntBubbleManager.swift
// Picksy
//
// Singleton that drives the floating in-app bubble shown when a taunt
// or nudge push notification arrives while the app is in the foreground.

import Foundation
import SwiftUI

// H7 fix: @MainActor ensures @Observable mutations happen on the main actor,
// which is required for SwiftUI's observation system. DispatchQueue.main.async
// bypassed Swift's actor isolation checks and could cause torn reads.
@MainActor
@Observable
final class TauntBubbleManager {

    static let shared = TauntBubbleManager()

    struct Message: Identifiable {
        let id   = UUID()
        let title: String
        let body:  String
    }

    var pending: Message? = nil

    private init() {}

    func show(title: String, body: String) {
        pending = Message(title: title, body: body)
    }

    func dismiss() {
        pending = nil
    }
}
