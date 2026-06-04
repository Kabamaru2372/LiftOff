//
//  WatchDataModel.swift
//  Picksy Watch
//
//  Single source of truth for the Watch UI. Mirrors the iPhone's DataStore.
//  Right now it holds mock values; WatchConnectivityManager will populate it
//  from the phone in the next step.
//

import SwiftUI
import Observation

@Observable
final class WatchDataModel {

    /// Shared singleton so the connectivity manager can push updates into it.
    static let shared = WatchDataModel()

    // ── Synced from iPhone (zeros until the first sync arrives) ────────────
    var todayPickups: Int = 0
    var todayTotalSeconds: Int = 0
    var dailyGoal: Int = 50
    var currentStreak: Int = 0
    var appLanguage: String = "Ελληνικά"
    /// Unix timestamp of the last received update from the phone (0 = never).
    var lastSyncedAt: Double = 0

    private init() {}

    // ── Derived ───────────────────────────────────────────────────────────

    /// Picksy Score: pickups + (screen_time_minutes × 5). Lower = better.
    var picksyScore: Int {
        todayPickups + (todayTotalSeconds / 60) * 5
    }

    var zone: WatchPickupZone {
        WatchPickupZone.zone(for: todayPickups)
    }

    var goalProgress: Double {
        let goal = dailyGoal > 0 ? dailyGoal : 30
        return min(Double(todayPickups) / Double(goal), 1.0)
    }

    /// Human-readable screen time, e.g. "2h 15m" or "26m".
    var screenTimeLabel: String {
        let mins = todayTotalSeconds / 60
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    // ── Mutation (called by connectivity manager) ─────────────────────────

    func apply(pickups: Int, totalSeconds: Int, goal: Int, streak: Int, language: String) {
        todayPickups      = pickups
        todayTotalSeconds = totalSeconds
        dailyGoal         = goal
        currentStreak     = streak
        appLanguage       = language
        lastSyncedAt      = Date().timeIntervalSince1970
    }
}
