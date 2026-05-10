//
//  ZoneNotificationManager.swift
//  Picksy
//
//  Created by Fotios Pongas on 04.05.2026
//
//  Manages notifications for zone transitions during the day.
//
//  Notifications fire only when user crosses into Average, Heavy, or
//  Problematic zones for the FIRST time that day. This prevents spam.
//
//  Notifications are constructive: they show the user what they could
//  have done with the time spent on pickups, instead of just judging.
//
//  v1.6 update: Notifications carry userInfo with zone+pickup data so
//  the app can show a detailed insight sheet when the notification is tapped.
//

import Foundation
import UserNotifications

class ZoneNotificationManager {

    // MARK: - Singleton

    static let shared = ZoneNotificationManager()

    // MARK: - Notification UserInfo Keys

    /// Identifier for zone notifications (used to detect taps).
    static let notificationCategory = "PICKSY_ZONE_NOTIFICATION"

    /// UserInfo key for zone identifier in notification payload.
    static let userInfoZoneKey = "picksy.zone"

    /// UserInfo key for pickup count in notification payload.
    static let userInfoPickupsKey = "picksy.pickups"

    // MARK: - State Persistence

    /// Tracks which zones have already triggered a notification today.
    /// Resets at midnight.
    private static let triggeredZonesKey = "ZoneNotificationManager.triggeredZonesToday"
    private static let lastResetDateKey = "ZoneNotificationManager.lastResetDate"

    private init() {
        resetIfNewDay()
    }

    // MARK: - Public API

    /// Checks current pickup count and sends notification if a new zone
    /// transition has occurred. Should be called after each pickup.
    func checkAndNotify(currentPickups: Int) {
        resetIfNewDay()

        let zone = PickupZone.zone(for: currentPickups)

        // Only Average, Heavy, Problematic trigger notifications
        guard zone.triggersNotification else {
            return
        }

        // Don't notify twice for the same zone in the same day
        guard !hasTriggered(zone: zone) else {
            return
        }

        // Send notification and mark as triggered
        sendNotification(for: zone, pickups: currentPickups)
        markTriggered(zone: zone)
    }

    /// Resets the triggered zones (called at midnight automatically).
    func resetForNewDay() {
        UserDefaults.standard.set([], forKey: Self.triggeredZonesKey)
        UserDefaults.standard.set(todayDateString(), forKey: Self.lastResetDateKey)
        log("🔄 Reset triggered zones for new day")
    }

    // MARK: - Notification Sending

    private func sendNotification(for zone: PickupZone, pickups: Int) {
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        let activity = AlternativeActivityBank.pickActivity(forPickups: pickups)

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: zone, language: language)
        content.body = notificationBody(
            zone: zone,
            pickups: pickups,
            activity: activity,
            language: language
        )
        content.sound = .default

        // v1.6: Set category and userInfo για deep linking στο insight sheet
        content.categoryIdentifier = Self.notificationCategory
        content.userInfo = [
            Self.userInfoZoneKey: zone.rawValue,
            Self.userInfoPickupsKey: pickups
        ]

        let request = UNNotificationRequest(
            identifier: "picksy.zone.\(zone.rawValue)",
            content: content,
            trigger: nil  // Fire immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.log("❌ Failed to schedule notification: \(error.localizedDescription)")
            } else {
                self.log("✅ Sent zone notification: \(zone.rawValue) at \(pickups) pickups")
            }
        }
    }

    private func notificationTitle(for zone: PickupZone, language: String) -> String {
        switch (zone, language) {

        // Average zone - friendly heads-up
        case (.average, "Ελληνικά"):    return "Πώς πας; 🤔"
        case (.average, "Deutsch"):      return "Wie läuft's? 🤔"
        case (.average, _):              return "How's it going? 🤔"

        // Heavy zone - direct but caring
        case (.heavy, "Ελληνικά"):       return "Σκέψου το λίγο 💭"
        case (.heavy, "Deutsch"):        return "Denk mal nach 💭"
        case (.heavy, _):                return "Take a moment 💭"

        // Problematic zone - serious
        case (.problematic, "Ελληνικά"): return "Καιρός για αλλαγή ⚠️"
        case (.problematic, "Deutsch"):  return "Zeit für eine Änderung ⚠️"
        case (.problematic, _):          return "Time for a change ⚠️"

        default:                          return "Picksy"
        }
    }

    private func notificationBody(
        zone: PickupZone,
        pickups: Int,
        activity: AlternativeActivity,
        language: String
    ) -> String {
        let activityText = activity.description(language: language)

        switch (zone, language) {

        // Average zone - gentle suggestion
        case (.average, "Ελληνικά"):
            return "\(pickups) σηκώματα σήμερα. Στον χρόνο αυτό θα μπορούσες να \(activityText). 🌱"
        case (.average, "Deutsch"):
            return "\(pickups) Griffe heute. In dieser Zeit könntest du \(activityText). 🌱"
        case (.average, _):
            return "\(pickups) pickups today. In that time, you could \(activityText). 🌱"

        // Heavy zone - clearer message
        case (.heavy, "Ελληνικά"):
            return "\(pickups) σηκώματα. Στις φορές αυτές που σήκωσες το κινητό, θα μπορούσες να \(activityText). Άξιζε; 🤷"
        case (.heavy, "Deutsch"):
            return "\(pickups) Griffe. In dieser Zeit könntest du \(activityText). War es das wert? 🤷"
        case (.heavy, _):
            return "\(pickups) pickups. In all that time, you could \(activityText). Worth it? 🤷"

        // Problematic zone - serious but constructive
        case (.problematic, "Ελληνικά"):
            return "\(pickups) σηκώματα μόνο σήμερα. Σκέψου: στον χρόνο αυτό θα μπορούσες να \(activityText). Καιρός να βάλεις όρια. 🛑"
        case (.problematic, "Deutsch"):
            return "\(pickups) Griffe heute allein. In dieser Zeit könntest du \(activityText). Zeit für Grenzen. 🛑"
        case (.problematic, _):
            return "\(pickups) pickups today alone. You could have \(activityText) instead. Time to set limits. 🛑"

        default:
            return "Picksy update: \(pickups) pickups today."
        }
    }

    // MARK: - Daily Reset

    private func resetIfNewDay() {
        let lastReset = UserDefaults.standard.string(forKey: Self.lastResetDateKey) ?? ""
        let today = todayDateString()

        if lastReset != today {
            resetForNewDay()
        }
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Triggered Zone Tracking

    private func hasTriggered(zone: PickupZone) -> Bool {
        let triggered = UserDefaults.standard.stringArray(forKey: Self.triggeredZonesKey) ?? []
        return triggered.contains(zone.rawValue)
    }

    private func markTriggered(zone: PickupZone) {
        var triggered = UserDefaults.standard.stringArray(forKey: Self.triggeredZonesKey) ?? []
        triggered.append(zone.rawValue)
        UserDefaults.standard.set(triggered, forKey: Self.triggeredZonesKey)
    }

    // MARK: - Logging

    private func log(_ message: String) {
        print("[ZoneNotifications] \(message)")
    }
}

