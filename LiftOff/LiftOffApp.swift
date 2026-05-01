// LiftOffApp.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026

import SwiftUI
import UserNotifications

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationDelegate()
    weak var tabSelection: TabSelection?

    // Όταν ο χρήστης πατάει σε notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier

        if identifier == "liftoff.evening" {
            DispatchQueue.main.async {
                self.tabSelection?.selectedTab = 1
            }
        }
        else if identifier == "liftoff.weekly" {
            DispatchQueue.main.async {
                self.tabSelection?.selectedTab = 1
            }
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct LiftOffApp: App {

    @State private var store = DataStore()
    @State private var detector = PickupDetector()
    @State private var liveActivity = LiveActivityManager()
    @State private var hourlyTracker = HourlyTracker()
    @State private var rewardManager = RewardManager()
    @State private var proManager = ProManager.shared
    @State private var checkInManager = CheckInManager()
    @State private var weeklyManager = WeeklySummaryManager()
    @State private var tabSelection = TabSelection()
    @State private var weatherManager = WeatherManager()
    @State private var activityPrefs = ActivityPreferences()

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    init() {
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // CRITICAL: Pre-warm τα Family Controls singletons.
        // Διαβάζοντας τα static .shared properties, αναγκάζουμε
        // το αρχικοποίηση να γίνει στο app launch, όχι όταν
        // ο user πατήσει το Apps tab. Αυτό αποτρέπει race conditions.
        _ = AppSelectionStore.shared
        _ = FamilyControlsManager.shared
        _ = PickupScheduler.shared
    }

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                ContentView()
                    .environment(store)
                    .environment(detector)
                    .environment(liveActivity)
                    .environment(hourlyTracker)
                    .environment(rewardManager)
                    .environment(proManager)
                    .environment(checkInManager)
                    .environment(weeklyManager)
                    .environment(tabSelection)
                    .environment(weatherManager)
                    .environment(activityPrefs)
                    .onAppear {
                        let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
                        liveActivity.start(pickupCount: store.todayPickups, dailyGoal: goal > 0 ? goal : 15)
                        scheduleNotifications(pickupCount: store.todayPickups)
                        startAutoTrialIfNeeded()
                        NotificationDelegate.shared.tabSelection = tabSelection
                        Task { await weatherManager.fetchWeather() }

                        // CRITICAL: Refresh Family Controls authorization μετά το cold start.
                        // Το AuthorizationCenter επιστρέφει stale data στα πρώτα ms,
                        // οπότε περιμένουμε λίγο και ξανα-ρωτάμε.
                        Task {
                            await FamilyControlsManager.shared.refreshAuthorizationStatusOnLaunch()
                        }
                    }
            } else {
                OnboardingView()
                    .environment(checkInManager)
                    .environment(weeklyManager)
                    .environment(weatherManager)
                    .environment(activityPrefs)
                    .onAppear {
                        startAutoTrialIfNeeded()
                    }
            }
        }
    }

    // MARK: - Auto Trial

    private func startAutoTrialIfNeeded() {
        guard !proManager.hasUsedTrial else { return }
        KeychainHelper.save("picksyProTrialStartDate",
                            date: Date().addingTimeInterval(-4 * 24 * 3600))
        proManager.checkTrial()
    }

    // MARK: - Notifications

    private func scheduleNotifications(pickupCount: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "liftoff.midday",
            "liftoff.evening",
            "liftoff.weekly",
            "liftoff.background.warning"
        ])

        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"

        // Midday 12:00
        let middayContent = UNMutableNotificationContent()
        middayContent.sound = .default
        switch language {
        case "Ελληνικά":
            middayContent.title = "Πώς πας μέχρι τώρα;"
            middayContent.body = middayMessageGR(pickupCount: pickupCount)
        case "Deutsch":
            middayContent.title = "Wie läuft es bisher?"
            middayContent.body = middayMessageDE(pickupCount: pickupCount)
        default:
            middayContent.title = "How's it going so far?"
            middayContent.body = middayMessageEN(pickupCount: pickupCount)
        }

        var middayComponents = DateComponents()
        middayComponents.hour = 12; middayComponents.minute = 0
        center.add(UNNotificationRequest(
            identifier: "liftoff.midday",
            content: middayContent,
            trigger: UNCalendarNotificationTrigger(dateMatching: middayComponents, repeats: true)
        ))

        // Evening 21:00 — Daily Check-in
        let eveningContent = UNMutableNotificationContent()
        eveningContent.sound = .default
        switch language {
        case "Ελληνικά":
            eveningContent.title = "Ημερήσιος απολογισμός 📝"
            eveningContent.body = "Πώς ήταν η σχέση σου με το κινητό σήμερα; Άνοιξε το Picksy για check-in."
        case "Deutsch":
            eveningContent.title = "Tages-Check-in 📝"
            eveningContent.body = "Wie war deine Beziehung zum Handy heute? Öffne Picksy für den Check-in."
        default:
            eveningContent.title = "Daily Check-in 📝"
            eveningContent.body = "How was your relationship with your phone today? Open Picksy to check in."
        }

        var eveningComponents = DateComponents()
        eveningComponents.hour = 21; eveningComponents.minute = 0
        center.add(UNNotificationRequest(
            identifier: "liftoff.evening",
            content: eveningContent,
            trigger: UNCalendarNotificationTrigger(dateMatching: eveningComponents, repeats: true)
        ))

        // Sunday 20:00 — Weekly Summary
        let weeklyContent = UNMutableNotificationContent()
        weeklyContent.sound = .default
        switch language {
        case "Ελληνικά":
            weeklyContent.title = "Η εβδομάδα σου είναι έτοιμη! 📊"
            weeklyContent.body = "Δες μια ματιά στις τελευταίες 7 μέρες σου. Άνοιξε το Picksy."
        case "Deutsch":
            weeklyContent.title = "Deine Woche ist da! 📊"
            weeklyContent.body = "Schau dir deine letzten 7 Tage an. Öffne Picksy."
        default:
            weeklyContent.title = "Your week is here! 📊"
            weeklyContent.body = "Take a look at your last 7 days. Open Picksy."
        }

        var weeklyComponents = DateComponents()
        weeklyComponents.weekday = 1
        weeklyComponents.hour = 20
        weeklyComponents.minute = 0
        center.add(UNNotificationRequest(
            identifier: "liftoff.weekly",
            content: weeklyContent,
            trigger: UNCalendarNotificationTrigger(dateMatching: weeklyComponents, repeats: true)
        ))
    }

    // MARK: - Midday EN
    private func middayMessageEN(pickupCount: Int) -> String {
        switch pickupCount {
        case 0...5: return "Excellent morning! You're barely touching your phone. Keep it up! 💪"
        case 6...10: return "Good start! You're doing well. Stay focused this afternoon."
        case 11...20: return "You've picked up your phone \(pickupCount) times. The afternoon is yours to improve."
        case 21...30: return "\(pickupCount) pickups already. Take a breath. You've got this afternoon to turn it around."
        default: return "\(pickupCount) pickups before noon. The afternoon is a fresh start. You can do better."
        }
    }

    // MARK: - Midday GR
    private func middayMessageGR(pickupCount: Int) -> String {
        switch pickupCount {
        case 0...5: return "Εξαιρετικό πρωινό! Μόλις αγγίζεις το κινητό. Συνέχισε έτσι! 💪"
        case 6...10: return "Καλή αρχή! Τα πας καλά. Μείνε συγκεντρωμένος το απόγευμα."
        case 11...20: return "Έχεις πιάσει το κινητό \(pickupCount) φορές. Το απόγευμα είναι δικό σου για βελτίωση."
        case 21...30: return "\(pickupCount) φορές ήδη. Πάρε μια ανάσα. Έχεις το απόγευμα να το αλλάξεις."
        default: return "\(pickupCount) φορές πριν το μεσημέρι. Το απόγευμα ξεκινάει από μηδέν. Μπορείς καλύτερα."
        }
    }

    // MARK: - Midday DE
    private func middayMessageDE(pickupCount: Int) -> String {
        switch pickupCount {
        case 0...5: return "Ausgezeichneter Morgen! Du greifst kaum zum Handy. Weiter so! 💪"
        case 6...10: return "Guter Start! Du machst das gut. Bleib heute Nachmittag fokussiert."
        case 11...20: return "Du hast dein Handy \(pickupCount) Mal aufgehoben. Der Nachmittag gehört dir zur Verbesserung."
        case 21...30: return "\(pickupCount) Griffe bereits. Tief durchatmen. Du kannst es am Nachmittag noch drehen."
        default: return "\(pickupCount) Griffe vor dem Mittag. Der Nachmittag ist ein Neustart. Du kannst es besser."
        }
    }
}
