// LiftOffApp.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026
//
// v1.6 UPDATE:
// - Silent push via Supabase για background tracking
// - AppDelegate handles device token + silent push
// - Background fetch ως fallback

import SwiftUI
import UserNotifications
import BackgroundTasks

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // BGTask registration - ΠΡΕΠΕΙ να γίνει εδώ
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: LiftOffApp.backgroundFetchTaskID,
            using: nil
        ) { task in
            print("[BGTask] 🔄 Background fetch task received!")
            LiftOffApp.handleBackgroundFetch(task: task as! BGAppRefreshTask)
        }

        print("[AppDelegate] ✅ BGTask registered")
        return true
    }

    // MARK: - Remote Notification Registration

    /// Καλείται όταν iOS δίνει device token για push notifications
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.handleDeviceToken(deviceToken)
    }

    /// Καλείται αν αποτύχει η registration
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.shared.handleRegistrationFailure(error)
    }

    // MARK: - Silent Push Handler

    /// Καλείται όταν έρχεται silent push (content-available: 1)
    /// Αυτό είναι το κλειδί για background wake-up!
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("[AppDelegate] 📩 Remote notification received")

        // Ελέγχουμε αν είναι silent push από Picksy
        guard let type = userInfo["type"] as? String,
              type == "silent-refresh" else {
            completionHandler(.noData)
            return
        }

        PushNotificationManager.shared.handleSilentPush(
            userInfo: userInfo,
            store: LiftOffApp.sharedStore,
            liveActivity: LiftOffApp.sharedLiveActivity,
            completionHandler: completionHandler
        )
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationDelegate()
    weak var tabSelection: TabSelection?

    var pendingZoneInsight: ZoneInsightData?
    var pendingUsageInsight: UsageInsightData?

    static let zoneInsightRequestedNotification = Notification.Name("picksy.zoneInsightRequested")
    static let usageInsightRequestedNotification = Notification.Name("picksy.usageInsightRequested")

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo
        let categoryId = response.notification.request.content.categoryIdentifier

        if categoryId == ZoneNotificationManager.notificationCategory {
            handleZoneNotificationTap(userInfo: userInfo)
        }
        else if categoryId == "PICKSY_USAGE_THRESHOLD" {
            handleUsageNotificationTap(userInfo: userInfo)
        }
        else if identifier == "liftoff.evening" || identifier == "liftoff.weekly" {
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

    private func handleZoneNotificationTap(userInfo: [AnyHashable: Any]) {
        guard
            let zoneRaw = userInfo[ZoneNotificationManager.userInfoZoneKey] as? String,
            let zone = PickupZone(rawValue: zoneRaw),
            let pickups = userInfo[ZoneNotificationManager.userInfoPickupsKey] as? Int
        else { return }

        let data = ZoneInsightData(zone: zone, pickupCount: pickups)
        DispatchQueue.main.async {
            self.tabSelection?.selectedTab = 0
            self.pendingZoneInsight = data
            NotificationCenter.default.post(
                name: Self.zoneInsightRequestedNotification,
                object: nil,
                userInfo: ["zone": zone.rawValue, "pickups": pickups]
            )
        }
    }

    private func handleUsageNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let level = userInfo["level"] as? Int else { return }
        let data = UsageInsightData(level: level)
        DispatchQueue.main.async {
            self.pendingUsageInsight = data
            NotificationCenter.default.post(
                name: Self.usageInsightRequestedNotification,
                object: nil,
                userInfo: ["level": level]
            )
        }
    }
}

// MARK: - Zone Insight Data

struct ZoneInsightData: Identifiable, Equatable {
    let id = UUID()
    let zone: PickupZone
    let pickupCount: Int
}

// MARK: - App

@main
struct LiftOffApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
    @State private var foregroundObserver: NSObjectProtocol? = nil

    static let backgroundFetchTaskID = "dev.fotiospongas.picksy.refresh"
    static var sharedStore: DataStore?
    static var sharedLiveActivity: LiveActivityManager?

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        _ = AppSelectionStore.shared
        _ = FamilyControlsManager.shared
        _ = PickupScheduler.shared
        _ = ScreenUnlockDetector.shared
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
                        LiftOffApp.sharedStore = store
                        LiftOffApp.sharedLiveActivity = liveActivity
                        onAppLaunch()
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

    // MARK: - App Launch

    private func onAppLaunch() {
        let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
        let dailyGoal = goal > 0 ? goal : 50

        store.syncWithDeviceActivity()
        let g = dailyGoal > 0 ? dailyGoal : 50
        if liveActivity.isRunning {
            liveActivity.update(pickupCount: store.todayPickups)
        } else {
            liveActivity.start(pickupCount: store.todayPickups, dailyGoal: g)
        }
        scheduleAllNotifications(pickupCount: store.todayPickups)
        startAutoTrialIfNeeded()
        NotificationDelegate.shared.tabSelection = tabSelection

        Task { await weatherManager.fetchWeather() }

        Task {
            await FamilyControlsManager.shared.refreshAuthorizationStatusOnLaunch()
            await MainActor.run {
                if FamilyControlsManager.shared.isAuthorized {
                    UsageThresholdManager.shared.startMonitoring()
                    PickupScheduler.shared.startMonitoring()
                }
            }
        }

        // ScreenUnlockDetector για foreground pickup detection
        ScreenUnlockDetector.shared.onPickupDetected = {
            store.recordPickup()
            liveActivity.update(pickupCount: store.todayPickups)
        }
        ScreenUnlockDetector.shared.startMonitoring()

        detector.startMonitoring()

        // AppsView refresh
        AppsViewRefreshTrigger.shared.refresh()
        AppsViewRefreshTrigger.shared.refreshAfter(seconds: 0.5)
        AppsViewRefreshTrigger.shared.refreshAfter(seconds: 1.5)
        AppsViewRefreshTrigger.shared.refreshAfter(seconds: 3.0)

        // v1.6: Register για silent push notifications
        PushNotificationManager.shared.registerForPushNotifications()

        setupForegroundObserver()
        scheduleBackgroundFetch()

        print("[LiftOffApp] 🚀 App launched. Pickups today: \(store.todayPickups)")
    }

    // MARK: - Foreground Observer

    private func setupForegroundObserver() {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("[LiftOffApp] 🔆 App came to foreground")

            store.syncWithDeviceActivity()
            let g = UserDefaults.standard.integer(forKey: "dailyGoal")
            let goal = g > 0 ? g : 50
            if liveActivity.isRunning {
                liveActivity.update(pickupCount: store.todayPickups)
            } else {
                liveActivity.start(pickupCount: store.todayPickups, dailyGoal: goal)
            }
            ScreenUnlockDetector.shared.startMonitoring()

            AppsViewRefreshTrigger.shared.refresh()
            AppsViewRefreshTrigger.shared.refreshAfter(seconds: 0.5)
            AppsViewRefreshTrigger.shared.refreshAfter(seconds: 1.5)
            AppsViewRefreshTrigger.shared.refreshAfter(seconds: 3.0)

            scheduleBackgroundFetch()
        }
    }

    // MARK: - Background Fetch (fallback)

    static func scheduleBackgroundFetch() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundFetchTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[LiftOffApp] ⚠️ Background fetch schedule failed: \(error)")
        }
    }

    private func scheduleBackgroundFetch() {
        LiftOffApp.scheduleBackgroundFetch()
    }

    static func handleBackgroundFetch(task: BGAppRefreshTask) {
        print("[LiftOffApp] 🔄 Background fetch executing...")
        scheduleBackgroundFetch()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        sharedStore?.syncWithDeviceActivity()
        sharedLiveActivity?.update(pickupCount: sharedStore?.todayPickups ?? 0)
        ScreenUnlockDetector.shared.startMonitoring()

        print("[LiftOffApp] ✅ Background fetch complete")
        task.setTaskCompleted(success: true)
    }

    // MARK: - Auto Trial

    private func startAutoTrialIfNeeded() {
        guard !proManager.hasUsedTrial else { return }
        KeychainHelper.save("picksyProTrialStartDate",
                            date: Date().addingTimeInterval(-4 * 24 * 3600))
        proManager.checkTrial()
    }

    // MARK: - Notifications

    private func scheduleAllNotifications(pickupCount: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "liftoff.midday", "liftoff.evening", "liftoff.weekly",
            "liftoff.background.warning",
            "picksy.summary.afternoon", "picksy.summary.evening"
        ])

        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        scheduleMiddayNotification(center: center, pickupCount: pickupCount, language: language)
        scheduleEveningNotification(center: center, language: language)
        scheduleWeeklyNotification(center: center, language: language)
        scheduleSummaryNotifications(center: center, language: language)
    }

    private func scheduleMiddayNotification(center: UNUserNotificationCenter, pickupCount: Int, language: String) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch language {
        case "Ελληνικά":
            content.title = "Πώς πας μέχρι τώρα;"
            content.body = middayMessageGR(pickupCount: pickupCount)
        case "Deutsch":
            content.title = "Wie läuft es bisher?"
            content.body = middayMessageDE(pickupCount: pickupCount)
        default:
            content.title = "How's it going so far?"
            content.body = middayMessageEN(pickupCount: pickupCount)
        }
        var c = DateComponents(); c.hour = 12; c.minute = 0
        center.add(UNNotificationRequest(identifier: "liftoff.midday", content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true)))
    }

    private func scheduleEveningNotification(center: UNUserNotificationCenter, language: String) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch language {
        case "Ελληνικά":
            content.title = "Ημερήσιος απολογισμός 📝"
            content.body = "Πώς ήταν η σχέση σου με το κινητό σήμερα; Άνοιξε το Picksy για check-in."
        case "Deutsch":
            content.title = "Tages-Check-in 📝"
            content.body = "Wie war deine Beziehung zum Handy heute? Öffne Picksy für den Check-in."
        default:
            content.title = "Daily Check-in 📝"
            content.body = "How was your relationship with your phone today? Open Picksy to check in."
        }
        var c = DateComponents(); c.hour = 21; c.minute = 0
        center.add(UNNotificationRequest(identifier: "liftoff.evening", content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true)))
    }

    private func scheduleWeeklyNotification(center: UNUserNotificationCenter, language: String) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch language {
        case "Ελληνικά":
            content.title = "Η εβδομάδα σου είναι έτοιμη! 📊"
            content.body = "Δες μια ματιά στις τελευταίες 7 μέρες σου. Άνοιξε το Picksy."
        case "Deutsch":
            content.title = "Deine Woche ist da! 📊"
            content.body = "Schau dir deine letzten 7 Tage an. Öffne Picksy."
        default:
            content.title = "Your week is here! 📊"
            content.body = "Take a look at your last 7 days. Open Picksy."
        }
        var c = DateComponents(); c.weekday = 1; c.hour = 20; c.minute = 0
        center.add(UNNotificationRequest(identifier: "liftoff.weekly", content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true)))
    }

    private func scheduleSummaryNotifications(center: UNUserNotificationCenter, language: String) {
        let afternoonContent = UNMutableNotificationContent()
        afternoonContent.sound = .default
        switch language {
        case "Ελληνικά":
            afternoonContent.title = "Picksy check-in ⚡"
            afternoonContent.body = "Πώς πας σήμερα; Άνοιξε το Picksy για να δεις τα σηκώματά σου."
        case "Deutsch":
            afternoonContent.title = "Picksy Check-in ⚡"
            afternoonContent.body = "Wie läuft dein Tag? Öffne Picksy, um deine Griffe zu sehen."
        default:
            afternoonContent.title = "Picksy check-in ⚡"
            afternoonContent.body = "How's your day going? Open Picksy to see your pickups."
        }
        var ac = DateComponents(); ac.hour = 14; ac.minute = 0
        center.add(UNNotificationRequest(identifier: "picksy.summary.afternoon",
            content: afternoonContent,
            trigger: UNCalendarNotificationTrigger(dateMatching: ac, repeats: true)))

        let eveningContent = UNMutableNotificationContent()
        eveningContent.sound = .default
        switch language {
        case "Ελληνικά":
            eveningContent.title = "Βραδινό σύνολο 🌙"
            eveningContent.body = "Δες πόσες φορές σήκωσες το κινητό σήμερα. Άνοιξε το Picksy."
        case "Deutsch":
            eveningContent.title = "Abend-Zusammenfassung 🌙"
            eveningContent.body = "Sieh, wie oft du heute zum Handy gegriffen hast. Öffne Picksy."
        default:
            eveningContent.title = "Evening summary 🌙"
            eveningContent.body = "See how many times you picked up your phone today. Open Picksy."
        }
        var ec = DateComponents(); ec.hour = 20; ec.minute = 0
        center.add(UNNotificationRequest(identifier: "picksy.summary.evening",
            content: eveningContent,
            trigger: UNCalendarNotificationTrigger(dateMatching: ec, repeats: true)))
    }

    // MARK: - Midday Messages

    private func middayMessageEN(pickupCount: Int) -> String {
        switch pickupCount {
        case 0...5: return "Excellent morning! You're barely touching your phone. Keep it up! 💪"
        case 6...10: return "Good start! You're doing well. Stay focused this afternoon."
        case 11...20: return "You've picked up your phone \(pickupCount) times. The afternoon is yours to improve."
        case 21...30: return "\(pickupCount) pickups already. Take a breath. You've got this afternoon to turn it around."
        default: return "\(pickupCount) pickups before noon. The afternoon is a fresh start. You can do better."
        }
    }

    private func middayMessageGR(pickupCount: Int) -> String {
        switch pickupCount {
        case 0...5: return "Εξαιρετικό πρωινό! Μόλις αγγίζεις το κινητό. Συνέχισε έτσι! 💪"
        case 6...10: return "Καλή αρχή! Τα πας καλά. Μείνε συγκεντρωμένος το απόγευμα."
        case 11...20: return "Έχεις πιάσει το κινητό \(pickupCount) φορές. Το απόγευμα είναι δικό σου για βελτίωση."
        case 21...30: return "\(pickupCount) φορές ήδη. Πάρε μια ανάσα. Έχεις το απόγευμα να το αλλάξεις."
        default: return "\(pickupCount) φορές πριν το μεσημέρι. Το απόγευμα ξεκινάει από μηδέν. Μπορείς καλύτερα."
        }
    }

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

