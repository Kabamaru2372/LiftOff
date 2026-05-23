// LiftOffApp.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026
//
// v1.6 UPDATE: Silent push via Supabase για background tracking
// v1.7 FIX: Αφαιρέθηκε BGTask (Supabase silent push το αντικαθιστά)

import SwiftUI
import UserNotifications

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[AppDelegate] ✅ App launched")
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.shared.handleRegistrationFailure(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("[AppDelegate] 📩 Remote notification received")

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

    /// Set to true when a notification tap is about to trigger tab navigation.
    /// The foreground observer checks this so it doesn't override the notification's destination.
    var didNavigateViaNotification = false

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Mark that we're navigating via notification — foreground observer will skip its tab reset
        didNavigateViaNotification = true
        let identifier = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo
        let categoryId = response.notification.request.content.categoryIdentifier

        if categoryId == ZoneNotificationManager.notificationCategory {
            handleZoneNotificationTap(userInfo: userInfo)
        } else if categoryId == "PICKSY_USAGE_THRESHOLD" {
            handleUsageNotificationTap(userInfo: userInfo)
        } else if identifier == "liftoff.midday"
               || identifier == "picksy.summary.afternoon"
               || identifier == "picksy.morning.wakeup"
               || identifier.hasPrefix("picksy.friend.overusing.") {
            DispatchQueue.main.async {
                self.tabSelection?.selectedTab = 0  // NudgeView
            }
        } else if identifier == "liftoff.evening"
               || identifier == "liftoff.weekly"
               || identifier == "picksy.summary.evening" {
            DispatchQueue.main.async {
                self.tabSelection?.selectedTab = 1  // Stats/Dashboard
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
    @State private var focusSessionManager = FocusSessionManager()
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
    @State private var pendingChallenge: ChallengePayload? = nil

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
                    .environment(focusSessionManager)
                    .environment(hourlyTracker)
                    .environment(rewardManager)
                    .environment(proManager)
                    .environment(checkInManager)
                    .environment(weeklyManager)
                    .environment(tabSelection)
                    .environment(weatherManager)
                    .environment(activityPrefs)
                    .environment(AchievementManager.shared)
                    .environment(CorrelationStore.shared)
                    .onOpenURL { url in
                        if let payload = ChallengeManager.parse(url: url) {
                            pendingChallenge = payload
                        }
                    }
                    .sheet(item: $pendingChallenge) { payload in
                        ChallengeReceivedView(payload: payload)
                            .environment(store)
                    }
                    .onAppear {
                        LiftOffApp.sharedStore = store
                        LiftOffApp.sharedLiveActivity = liveActivity
                        onAppLaunch()
                    }
                    // Όταν το focus session τελειώσει (αυτόματα ή manually),
                    // επαναφέρουμε το Live Activity σε normal pickup mode
                    .onChange(of: focusSessionManager.sessionState) { _, newState in
                        if case .completed(let pickupsDuring, _, _) = newState {
                            liveActivity.update(pickupCount: store.todayPickups)
                            if pickupsDuring == 0 {
                                AchievementManager.shared.onFocusPerfectSession()
                            }
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

    // MARK: - App Launch

    private func onAppLaunch() {
        let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
        let dailyGoal = goal > 0 ? goal : 50

        store.syncWithDeviceActivity()

        if liveActivity.isRunning {
            liveActivity.update(pickupCount: store.todayPickups)
        } else {
            liveActivity.start(pickupCount: store.todayPickups, dailyGoal: dailyGoal)
        }

        scheduleAllNotifications(pickupCount: store.todayPickups)
        startAutoTrialIfNeeded()
        NotificationDelegate.shared.tabSelection = tabSelection

        Task { await weatherManager.fetchWeather() }

        // Poll duel state on launch, sync pickup count, then refresh DI immediately
        Task {
            await DuelManager.shared.poll()
            await DuelManager.shared.updateMyPickups(store.todayPickups)
            // If we discovered an active duel, update the Live Activity now
            // (it was started above before poll completed, so it may be in normal mode)
            if let duel = DuelManager.shared.activeDuel, duel.status == .active,
               !focusSessionManager.isActive {
                liveActivity.updateForDuel(
                    pickupCount: store.todayPickups,
                    opponentName: duel.theirName,
                    myPickups: store.todayPickups,
                    theirPickups: duel.theirPickups
                )
            }
        }

        // Upload our public key so friends can send us encrypted messages
        Task { await MessagingManager.shared.uploadPublicKey() }

        Task {
            await FamilyControlsManager.shared.refreshAuthorizationStatusOnLaunch()
            await MainActor.run {
                if FamilyControlsManager.shared.isAuthorized {
                    UsageThresholdManager.shared.startMonitoring()
                    PickupScheduler.shared.startMonitoring()
                }
            }
        }

        ScreenUnlockDetector.shared.onPickupDetected = {
            // Request background execution time so that Activity.update() (which is async)
            // has time to reach the Dynamic Island before iOS suspends the app.
            // Without this, the DI only updates when the user next opens the app.
            var bgTaskID = UIBackgroundTaskIdentifier.invalid
            bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "picksy.pickup") {
                UIApplication.shared.endBackgroundTask(bgTaskID)
            }

            store.recordPickup()
            focusSessionManager.onPickup(currentPickups: store.todayPickups)

            // Upload updated status to Supabase on every pickup (rate-limited by hasPairs guard)
            Task {
                let g = UserDefaults.standard.integer(forKey: "dailyGoal")
                let goal = g > 0 ? g : 50
                await FriendSyncManager.shared.uploadStatus(
                    pickups: store.todayPickups,
                    dailyGoal: goal,
                    pickupsLast2h: pickupsLast2h(),
                    screenTimeLast2hSecs: store.screenTimeLastTwoHours
                )
                // Update duel pickup count on every pickup
                await DuelManager.shared.updateMyPickups(store.todayPickups)

                // Push Live Activity update via APNs — updates the Dynamic Island
                // directly from the server, so it works even if the app is suspended.
                // This is how live-score apps keep their DI current without the app open.
                let activeDuel = DuelManager.shared.activeDuel
                let isDuelActive = activeDuel?.status == .active
                await PushNotificationManager.shared.pushLiveActivityUpdate(
                    pickupCount: store.todayPickups,
                    duelOpponentName: isDuelActive ? activeDuel?.theirName : nil,
                    duelMyPickups:    isDuelActive ? (activeDuel?.myPickups ?? 0) : 0,
                    duelTheirPickups: isDuelActive ? (activeDuel?.theirPickups ?? 0) : 0
                )
            }
            let g2 = UserDefaults.standard.integer(forKey: "dailyGoal")
            let goal2 = g2 > 0 ? g2 : 50

            // If iOS killed the Live Activity overnight, restart it on the first pickup
            if !liveActivity.isRunning {
                liveActivity.start(pickupCount: store.todayPickups, dailyGoal: goal2)
            } else if focusSessionManager.isActive {
                // Focus takes priority over duel in the Dynamic Island
                liveActivity.updateForFocus(
                    pickupCount: store.todayPickups,
                    focusEndTime: focusSessionManager.endTime,
                    focusPickupCount: focusSessionManager.pickupsDuringSession
                )
            } else if let duel = DuelManager.shared.activeDuel, duel.status == .active {
                // Active duel — show score in Dynamic Island
                liveActivity.updateForDuel(
                    pickupCount: store.todayPickups,
                    opponentName: duel.theirName,
                    myPickups: duel.myPickups,
                    theirPickups: duel.theirPickups
                )
            } else {
                liveActivity.update(pickupCount: store.todayPickups)
            }

            // Release background time after 3 s — enough for Activity.update() to propagate
            // to the Dynamic Island. The expiry handler above covers the edge case where
            // iOS needs to reclaim resources earlier.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                UIApplication.shared.endBackgroundTask(bgTaskID)
            }
        }
        ScreenUnlockDetector.shared.onScreenSessionEnded = { seconds in
            store.addUsageTime(seconds: seconds)
            print("[ScreenTime] ⏱ Session ended: \(seconds)s, total today: \(store.todayTotalSeconds)s, last2h: \(store.screenTimeLastTwoHours)s")
        }
        ScreenUnlockDetector.shared.startMonitoring()
        detector.startMonitoring()

        AppsViewRefreshTrigger.shared.refresh()
        AppsViewRefreshTrigger.shared.refreshAfter(seconds: 0.5)
        AppsViewRefreshTrigger.shared.refreshAfter(seconds: 1.5)
        AppsViewRefreshTrigger.shared.refreshAfter(seconds: 3.0)

        PushNotificationManager.shared.registerForPushNotifications()

        // Friend sync — upload status on launch too
        Task {
            let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
            let last2hPickups = pickupsLast2h()
            await FriendSyncManager.shared.uploadStatus(
                pickups: store.todayPickups,
                dailyGoal: dailyGoal,
                pickupsLast2h: last2hPickups,
                screenTimeLast2hSecs: store.screenTimeLastTwoHours
            )
            // Friend accountability notifications — Pro only
            if proManager.isPro {
                let overusing = await FriendSyncManager.shared.checkOverusingPartners(
                    myPickups: store.todayPickups,
                    myGoal: dailyGoal,
                    myScreenTimeLast2hSecs: store.screenTimeLastTwoHours
                )
                if let partner = overusing.first {
                    await MainActor.run {
                        scheduleFriendOverusingNotification(partner: partner, language: lang)
                        FriendSyncManager.shared.markNotifiedToday(for: partner.deviceID)
                    }
                }
            }
        }

        // Στείλε Live Activity token στο Supabase αν υπάρχει
        Task {
            if let token = UserDefaults.standard.string(forKey: "liveActivityPushToken") {
                await PushNotificationManager.shared.registerLiveActivityToken(token)
            }
        }

        // Observe Live Activity push token changes
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if let token = liveActivity.pushToken {
                await PushNotificationManager.shared.registerLiveActivityToken(token)
            }
        }

        setupForegroundObserver()

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

            // Navigate on foreground — notification taps win, then duel if active, else home
            DispatchQueue.main.async {
                if NotificationDelegate.shared.didNavigateViaNotification {
                    NotificationDelegate.shared.didNavigateViaNotification = false
                } else if let duel = DuelManager.shared.activeDuel,
                          duel.status == .active || duel.status == .completed {
                    // Active duel → user may have tapped DI score
                    // Completed duel → user tapped "duel ended" notification → show result
                    tabSelection.selectedTab = 3
                } else {
                    tabSelection.selectedTab = 0
                }
            }

            store.syncWithDeviceActivity()
            let g = UserDefaults.standard.integer(forKey: "dailyGoal")
            let goal = g > 0 ? g : 50

            if liveActivity.isRunning {
                // Focus > Duel > Normal priority for Dynamic Island
                if focusSessionManager.isActive,
                   let endTime = focusSessionManager.endTime,
                   endTime > Date() {
                    liveActivity.updateForFocus(
                        pickupCount: store.todayPickups,
                        focusEndTime: endTime,
                        focusPickupCount: focusSessionManager.pickupsDuringSession
                    )
                } else if let duel = DuelManager.shared.activeDuel, duel.status == .active {
                    liveActivity.updateForDuel(
                        pickupCount: store.todayPickups,
                        opponentName: duel.theirName,
                        myPickups: duel.myPickups,
                        theirPickups: duel.theirPickups
                    )
                } else {
                    liveActivity.update(pickupCount: store.todayPickups)
                }
            } else {
                liveActivity.start(pickupCount: store.todayPickups, dailyGoal: goal)
            }

            ScreenUnlockDetector.shared.startMonitoring()

            // Refresh evening notification with latest pickup count
            // so the 21:00 message reflects actual day data
            scheduleAllNotifications(pickupCount: store.todayPickups)

            AppsViewRefreshTrigger.shared.refresh()
            AppsViewRefreshTrigger.shared.refreshAfter(seconds: 0.5)
            AppsViewRefreshTrigger.shared.refreshAfter(seconds: 1.5)
            AppsViewRefreshTrigger.shared.refreshAfter(seconds: 3.0)

            Task {
                if let token = liveActivity.pushToken {
                    await PushNotificationManager.shared.registerLiveActivityToken(token)
                }
                // Ensure our public key is always up-to-date in Supabase
                // so friends can send us encrypted messages
                await MessagingManager.shared.uploadPublicKey()
                // Poll duel state on foreground, then refresh Dynamic Island with latest scores
                await DuelManager.shared.poll()
                if let duel = DuelManager.shared.activeDuel, duel.status == .active,
                   !focusSessionManager.isActive {
                    liveActivity.updateForDuel(
                        pickupCount: store.todayPickups,
                        opponentName: duel.theirName,
                        myPickups: duel.myPickups,
                        theirPickups: duel.theirPickups
                    )
                }
            }

            // Friend sync — upload own status & check if any pair is also overusing
            Task {
                let g2 = UserDefaults.standard.integer(forKey: "dailyGoal")
                let goal2 = g2 > 0 ? g2 : 50
                let pickups = store.todayPickups
                let last2hPickups = pickupsLast2h()
                await FriendSyncManager.shared.uploadStatus(
                    pickups: pickups,
                    dailyGoal: goal2,
                    pickupsLast2h: last2hPickups,
                    screenTimeLast2hSecs: store.screenTimeLastTwoHours
                )

                let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"

                // Friend accountability notifications — Pro only
                if proManager.isPro {
                    let overusing = await FriendSyncManager.shared.checkOverusingPartners(
                        myPickups: pickups,
                        myGoal: goal2,
                        myScreenTimeLast2hSecs: store.screenTimeLastTwoHours
                    )
                    if let partner = overusing.first {
                        await MainActor.run {
                            scheduleFriendOverusingNotification(partner: partner, language: lang)
                            FriendSyncManager.shared.markNotifiedToday(for: partner.deviceID)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Friend Sync Helpers

    /// Pickups in the current + previous hour from HourlyTracker
    private func pickupsLast2h() -> Int {
        let hour = Calendar.current.component(.hour, from: Date())
        let prev = hour > 0 ? hour - 1 : 0
        return hourlyTracker.hourlyData[0][hour] + hourlyTracker.hourlyData[0][prev]
    }

    // MARK: - Friend Overusing Notification

    private func scheduleFriendOverusingNotification(partner: OverusingPartner, language: String) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = "PICKSY_FRIEND_OVERUSING"

        switch language {
        case "Ελληνικά":
            content.title = "Εσύ και \(partner.friendName) 📱"
            content.body  = "Και οι δυο σας φαίνεται να σηκώνετε πολύ το κινητό σήμερα. Τι λέτε για μια μικρή αποτοξίνωση μαζί;"
        case "Deutsch":
            content.title = "Du und \(partner.friendName) 📱"
            content.body  = "Ihr beide greift heute viel zum Handy. Wie wäre ein kleiner gemeinsamer Digital Detox?"
        default:
            content.title = "You and \(partner.friendName) 📱"
            content.body  = "You're both reaching for your phones a lot today. How about a little detox together?"
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "picksy.friend.overusing.\(partner.deviceID)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { err in
            if let err { print("[FriendSync] ❌ Notification error: \(err)") }
        }
        print("[FriendSync] 🔔 Friend overusing notification scheduled for \(partner.friendName)")
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
            "picksy.summary.afternoon", "picksy.summary.evening",
            "picksy.morning.wakeup"
        ])

        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        let g = UserDefaults.standard.integer(forKey: "dailyGoal")
        let dailyGoal = g > 0 ? g : 50

        scheduleMorningWakeupNotification(center: center, language: language)
        scheduleMiddayNotification(center: center, pickupCount: pickupCount, language: language)
        scheduleEveningNotification(center: center, pickupCount: pickupCount, dailyGoal: dailyGoal, language: language)
        scheduleWeeklyNotification(center: center, language: language)
        scheduleSummaryNotifications(center: center, language: language)
    }

    private func scheduleMorningWakeupNotification(center: UNUserNotificationCenter, language: String) {
        let content = UNMutableNotificationContent()

        switch language {
        case "Ελληνικά":
            content.title = "Καλημέρα! ☀️"
            content.body  = "Δες τις συμβουλές σου για σήμερα και ξεκίνα τη μέρα σου καλά."
        case "Deutsch":
            content.title = "Guten Morgen! ☀️"
            content.body  = "Schau dir deine Tipps für heute an und starte gut in den Tag."
        default:
            content.title = "Good morning! ☀️"
            content.body  = "Check your tips for today and start your day on the right foot."
        }

        content.sound = .default
        content.userInfo = ["action": "open_nudge"]

        var c = DateComponents()
        c.hour   = 6
        c.minute = 0

        center.add(UNNotificationRequest(
            identifier: "picksy.morning.wakeup",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true)
        ))
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

    private func scheduleEveningNotification(
        center: UNUserNotificationCenter,
        pickupCount: Int,
        dailyGoal: Int,
        language: String
    ) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = "PICKSY_EVENING_SUMMARY"

        let (title, body) = eveningMessage(pickupCount: pickupCount, dailyGoal: dailyGoal, language: language)
        content.title = title
        content.body  = body

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

    // MARK: - Evening Messages (personalized, data-driven)

    /// Returns (title, body) for the 21:00 personalized summary notification.
    /// Segments by pickups relative to dailyGoal so every user gets a relevant message.
    private func eveningMessage(pickupCount: Int, dailyGoal: Int, language: String) -> (String, String) {
        // Thresholds relative to goal
        let excellent  = Int(Double(dailyGoal) * 0.4)   // ≤ 40% of goal → excellent
        let good       = dailyGoal                       // ≤ 100% → good
        let slightOver = Int(Double(dailyGoal) * 1.5)   // ≤ 150% → slightly over

        switch language {
        case "Ελληνικά":
            if pickupCount <= excellent {
                return (
                    "Ήσουν παρών σήμερα 🌿",
                    "Μόνο \(pickupCount) σηκώματα — από τις καλύτερές σου μέρες! Απόλαυσε το βράδυ σου."
                )
            } else if pickupCount <= good {
                let under = dailyGoal - pickupCount
                return (
                    "Κάτω από τον στόχο 🎯",
                    "\(pickupCount) σηκώματα σήμερα — \(under) λιγότερα από τον στόχο σου (\(dailyGoal)). Συνέχισε έτσι!"
                )
            } else if pickupCount <= slightOver {
                let over = pickupCount - dailyGoal
                return (
                    "Κοντά στον στόχο 💪",
                    "\(pickupCount) σηκώματα σήμερα — \(over) πάνω από τον στόχο. Αύριο είναι μια νέα αρχή 🌅"
                )
            } else {
                return (
                    "Πολύ κινητό σήμερα 📱",
                    "\(pickupCount) σηκώματα — ήταν δύσκολη μέρα. Βάλε το κινητό κάτω και χαλάρωσε 🌙"
                )
            }

        case "Deutsch":
            if pickupCount <= excellent {
                return (
                    "Du warst heute präsent 🌿",
                    "Nur \(pickupCount) Griffe — einer deiner besten Tage! Genieße deinen Abend."
                )
            } else if pickupCount <= good {
                let under = dailyGoal - pickupCount
                return (
                    "Unter deinem Ziel 🎯",
                    "\(pickupCount) Griffe heute — \(under) weniger als dein Ziel (\(dailyGoal)). Weiter so!"
                )
            } else if pickupCount <= slightOver {
                let over = pickupCount - dailyGoal
                return (
                    "Knapp über dem Ziel 💪",
                    "\(pickupCount) Griffe — \(over) über deinem Ziel. Morgen ist ein frischer Start 🌅"
                )
            } else {
                return (
                    "Viel Handy heute 📱",
                    "\(pickupCount) Griffe — das war ein anstrengender Tag. Leg es weg und entspann dich 🌙"
                )
            }

        default: // English
            if pickupCount <= excellent {
                return (
                    "You were present today 🌿",
                    "Only \(pickupCount) pickups — one of your best days! Enjoy your evening phone-free."
                )
            } else if pickupCount <= good {
                let under = dailyGoal - pickupCount
                return (
                    "Under your goal! 🎯",
                    "\(pickupCount) pickups today — \(under) under your \(dailyGoal) goal. You're building a great habit."
                )
            } else if pickupCount <= slightOver {
                let over = pickupCount - dailyGoal
                return (
                    "Almost there 💪",
                    "\(pickupCount) pickups today — \(over) over your goal. Tomorrow is a fresh start 🌅"
                )
            } else {
                return (
                    "Busy phone day 📱",
                    "\(pickupCount) pickups — that was a tough one. Put it down and unwind for the evening 🌙"
                )
            }
        }
    }
}

