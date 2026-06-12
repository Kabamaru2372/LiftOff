// FocusSessionManager.swift
// Picksy
//
// Created by Fotios Pongas
//
// Manages the Focus Session timer state.
// Uses @Observable (Swift 6 / iOS 17+).

import Foundation

enum FocusSessionState: Equatable {
    case idle
    case active
    case completed(pickupsDuring: Int, durationMinutes: Int, success: Bool)
}

@Observable
class FocusSessionManager {

    var sessionState: FocusSessionState = .idle
    var timeRemaining: TimeInterval = 0
    var selectedDuration: TimeInterval = 1800  // default 30 min
    var pickupsAtStart: Int = 0
    var pickupsDuringSession: Int = 0
    private(set) var endTime: Date?
    private var timer: Timer?

    var isActive: Bool { sessionState == .active }

    var formattedTimeRemaining: String {
        let m = Int(timeRemaining) / 60
        let s = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var sessionProgress: Double {  // 0.0 → 1.0
        guard selectedDuration > 0 else { return 0 }
        return max(0, min(1, 1.0 - (timeRemaining / selectedDuration)))
    }

    func start(duration: TimeInterval, currentPickups: Int) {
        selectedDuration = duration
        pickupsAtStart = currentPickups
        pickupsDuringSession = 0
        endTime = Date().addingTimeInterval(duration)
        timeRemaining = duration
        sessionState = .active
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        endTime = nil
        sessionState = .idle
        timeRemaining = 0
        pickupsDuringSession = 0
    }

    func onPickup(currentPickups: Int) {
        guard isActive else { return }
        pickupsDuringSession = max(0, currentPickups - pickupsAtStart)
    }

    func dismissCompleted() {
        sessionState = .idle
        timeRemaining = 0
        pickupsDuringSession = 0
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let end = endTime else { return }
        let remaining = end.timeIntervalSinceNow
        if remaining <= 0 {
            complete()
        } else {
            timeRemaining = remaining
        }
    }

    private func complete() {
        timer?.invalidate()
        timer = nil
        endTime = nil
        let minutes = Int(selectedDuration / 60)
        let success = pickupsDuringSession == 0
        sessionState = .completed(pickupsDuring: pickupsDuringSession, durationMinutes: minutes, success: success)
        timeRemaining = 0
    }
}
