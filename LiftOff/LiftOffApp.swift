// LiftOffApp.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026
//
// v1.6 UPDATE: Silent push via Supabase για background tracking
// v1.7 FIX: Αφαιρέθηκε BGTask (Supabase silent push το αντικαθιστά)

import BackgroundTasks
import SwiftUI
import UserNotifications
import WidgetKit

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[AppDelegate] ✅ App launched")

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "fotiospongas.picksy.refresh",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            LiftOffApp.handleBackgroundRefresh(refreshTask)
        }

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

        // Widened net for the continuous-use false positive: ANY push that wakes us
        // is a chance to clear stale "you've been on your phone" alerts when the
        // screen is actually locked (the lock event can be missed while suspended,
        // e.g. music playing for hours). Runs for every push type, before routing.
        if !application.isProtectedDataAvailable {
            ScreenTimeMilestoneNotifier.shared.cancelContinuousSession()
            print("[AppDelegate] 🔒 Push wake while locked — cancelled pending continuous alerts")
        }

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

    static let zoneInsightRequestedNotification    = Notification.Name("picksy.zoneInsightRequested")
    static let usageInsightRequestedNotification   = Notification.Name("picksy.usageInsightRequested")
    static let milestoneDetailNotification         = Notification.Name("picksy.milestoneDetail")

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
        } else if categoryId == "PICKSY_MESSAGE" || categoryId == "PICKSY_DUEL" {
            // Show in-app floating bubble with the notification content
            let title = response.notification.request.content.title
            let body  = response.notification.request.content.body
            if !title.isEmpty || !body.isEmpty {
                TauntBubbleManager.shared.show(title: title, body: body)
            }
            DispatchQueue.main.async {
                self.tabSelection?.selectedTab = 3  // Friends tab
                // Tell FriendsView to re-poll and check for a new duel result.
                // Using async so it fires AFTER the foreground observer has already run
                // (willEnterForegroundNotification fires before didReceive, so the
                // foreground observer may have already reset the tab — this corrects it).
                NotificationCenter.default.post(name: .picksyDuelNotifTapped, object: nil)
            }
        } else if categoryId == "PICKSY_SCREEN_TIME_MILESTONE" {
            let minutes = userInfo["milestoneMinutes"] as? Int ?? 60
            let bodyEN  = userInfo["milestoneBodyEN"]  as? String ?? ""
            let bodyGR  = userInfo["milestoneBodyGR"]  as? String ?? bodyEN
            let bodyDE  = userInfo["milestoneBodyDE"]  as? String ?? bodyEN
            let link    = (userInfo["milestoneLink"] as? String).flatMap { URL(string: $0) }
            let data    = MilestoneNotificationData(
                minutes: minutes, bodyEN: bodyEN, bodyGR: bodyGR, bodyDE: bodyDE, link: link
            )
            DispatchQueue.main.async {
                self.tabSelection?.selectedTab = 0
                NotificationCenter.default.post(
                    name: Self.milestoneDetailNotification, object: data
                )
            }
        } else if categoryId == "PICKSY_FRIEND_OVERUSING"
               || identifier.hasPrefix("picksy.friend.overusing.") {
            // Friend accountability notification — show NudgeView (tab 0) which hosts
            // friend insights. Handles both local (identifier-based) and any future
            // remote push that carries the PICKSY_FRIEND_OVERUSING category.
            DispatchQueue.main.async {
                self.tabSelection?.selectedTab = 0
            }
        } else if identifier == "liftoff.midday"
               || identifier == "picksy.summary.afternoon"
               || identifier == "picksy.morning.wakeup" {
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
        let categoryId = notification.request.content.categoryIdentifier
        let identifier = notification.request.identifier

        if categoryId == "PICKSY_MESSAGE" || categoryId == "PICKSY_DUEL" {
            // Show in-app floating bubble instead of system banner
            let title = notification.request.content.title
            let body  = notification.request.content.body
            if !title.isEmpty || !body.isEmpty {
                TauntBubbleManager.shared.show(title: title, body: body)
            }
            // Still play sound, but suppress banner (we handle the UI ourselves)
            completionHandler([.sound])
        } else if categoryId == "PICKSY_SCREEN_TIME_MILESTONE"
               && identifier.hasPrefix("picksy.session.") {
            // Suppress continuous-session notifications when Picksy is in the
            // foreground and the session was already cancelled (lock happened but
            // BGAppRefresh hadn't run yet to remove the pending request).
            let sessionStart = UserDefaults(suiteName: ScreenTimeMilestoneNotifier.appGroupID)?
                .double(forKey: "picksy_continuous_session_start") ?? 0
            if sessionStart == 0 {
                print("[Session] ⛔ Suppressed stale continuous-session notification (session was cancelled)")
                completionHandler([])
            } else {
                completionHandler([.banner, .sound])
            }
        } else {
            completionHandler([.banner, .sound])
        }
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
            self.tabSelection?.selectedTab = 0  // NudgeView — consistent with other insight handlers
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

    // Fix #4: Initialize sharedStore/sharedLiveActivity at @State creation time,
    // before any silent push can arrive (which happens before .onAppear).
    @State private var store: DataStore = {
        let s = DataStore()
        LiftOffApp.sharedStore = s
        return s
    }()
    @State private var detector = PickupDetector()
    @State private var liveActivity: LiveActivityManager = {
        let la = LiveActivityManager()
        LiftOffApp.sharedLiveActivity = la
        return la
    }()
    @State private var focusSessionManager = FocusSessionManager()
    @State private var hourlyTracker = HourlyTracker()
    @State private var rewardManager = RewardManager()
    @State private var proManager = ProManager.shared
    @State private var checkInManager = CheckInManager()
    @State private var weeklyManager = WeeklySummaryManager()
    @State private var tabSelection = TabSelection()
    @State private var weatherManager = WeatherManager()
    @State private var activityPrefs = ActivityPreferences()
    @State private var forceUpdateManager = ForceUpdateManager.shared
    @State private var showSoftUpdateBanner = false

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var foregroundObserver: NSObjectProtocol? = nil
    @State private var pendingChallenge:  ChallengePayload?           = nil
    @State private var pendingMilestone:  MilestoneNotificationData?  = nil

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
                    // Soft update banner — slides in from top, user can dismiss
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if showSoftUpdateBanner && forceUpdateManager.isSoftUpdateAvailable {
                            SoftUpdateBanner(
                                onUpdate:  { forceUpdateManager.openAppStore() },
                                onDismiss: { withAnimation(.spring(response: 0.4)) { showSoftUpdateBanner = false } }
                            )
                            .padding(.top, 8)
                        }
                    }
                    // Force update overlay — blocks ALL interaction, cannot be dismissed
                    .fullScreenCover(isPresented: .constant(forceUpdateManager.isForceUpdateRequired)) {
                        ForceUpdateView(onUpdate: { forceUpdateManager.openAppStore() })
                    }
                    // Run the version check on launch and every foreground
                    .task {
                        await forceUpdateManager.check()
                        if forceUpdateManager.isSoftUpdateAvailable {
                            withAnimation(.spring(response: 0.5).delay(1.5)) {
                                showSoftUpdateBanner = true
                            }
                        }
                    }
                    .onOpenURL { url in
                        if let payload = ChallengeManager.parse(url: url) {
                            pendingChallenge = payload
                        }
                    }
                    .sheet(item: $pendingChallenge) { payload in
                        ChallengeReceivedView(payload: payload)
                            .environment(store)
                    }
                    .sheet(item: $pendingMilestone) { data in
                        MilestoneDetailView(
                            data: data,
                            language: UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
                        )
                    }
                    .onAppear {
                        // sharedStore/sharedLiveActivity already set at @State init time (fix #4)
                        onAppLaunch()
                    }
                    // Fix #5: Mirror active duel state to App Group so the
                    // DeviceActivity extension can include it in APNs pushes.
                    // Also refresh the Dynamic Island whenever the duel set changes
                    // (e.g. one duel cancelled while another is still running — the DI
                    // must switch to show the remaining duel, not freeze or go blank).
                    .onChange(of: DuelManager.shared.activeDuels) { _, duels in
                        LiftOffApp.syncDuelStateToAppGroup(duels: duels)
                        guard !focusSessionManager.isActive else { return }
                        if let duel = duels.first(where: { $0.status == .active }) {
                            liveActivity.updateForDuel(
                                pickupCount: store.todayPickups,
                                opponentName: duel.theirName,
                                mySecs: store.bestScreenTimeSecs,
                                theirSecs: duel.theirScreenTime
                            )
                        } else {
                            liveActivity.update(pickupCount: store.todayPickups)
                        }
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

    // MARK: - Background Refresh

    /// Handles a BGAppRefreshTask fired by iOS (typically 2–4× per hour based on usage patterns).
    /// Reads the current pickup count from shared UserDefaults, refreshes widgets,
    /// and sends an APNs push to update the Live Activity without the user opening the app.
    static func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        task.expirationHandler = { task.setTaskCompleted(success: false) }

        Task {
            // Fix #10: Don't fall back to UserDefaults.standard — it has no pickups data.
            guard let sharedDefaults = UserDefaults(suiteName: "group.fotiospongas.picksy") else {
                task.setTaskCompleted(success: false)
                scheduleBackgroundRefresh()
                return
            }

            let pickups = sharedDefaults.integer(forKey: "todayPickups")

            let deviceLocked = await MainActor.run { !UIApplication.shared.isProtectedDataAvailable }

            if deviceLocked {
                // Accurate Mode: re-apply shields ONLY while the device is locked,
                // so we NEVER re-shield an app the user is actively using (which
                // would pop the shield over their session). When unlocked, the
                // foreground + any-shield-interaction paths handle re-shielding.
                // After "Open" lifts a shield, the next lock's refresh re-shields it.
                await MainActor.run { ShieldManager.shared.refresh() }

                // SAFEGUARD (c): cancel any pending continuous-use alerts the
                // since-suspended app couldn't cancel at lock time (false positives).
                ScreenTimeMilestoneNotifier.shared.cancelContinuousSession()
                print("[BGRefresh] 🔒 Device locked — re-shielded + cancelled pending continuous alerts")
            } else {
                // SAFEGUARD (d): device still unlocked, but cancel stale continuous
                // alerts if the user hasn't picked up the phone in 10+ minutes.
                // Covers "music playing / phone face-down on desk": the screen may
                // stay on (or auto-lock was slow), Picksy got suspended before
                // receiving the lock event, and safeguard (c) never ran.
                // Lowered from 30 → 10 minutes to catch audio-lock false positives
                // faster (the willResignActive handler cancels when Picksy was
                // foreground, but if Picksy was already backgrounded when the
                // screen locked during audio, only this safeguard catches it).
                let lastPickupTS = sharedDefaults.double(forKey: "picksy_last_pickup_timestamp")
                let idleMinutes = lastPickupTS > 0
                    ? (Date().timeIntervalSince1970 - lastPickupTS) / 60
                    : Double.infinity
                if idleMinutes > 10 {
                    ScreenTimeMilestoneNotifier.shared.cancelContinuousSession()
                    print("[BGRefresh] 📴 Unlocked but idle \(Int(idleMinutes))min — cancelled stale continuous alerts")
                }
            }

            // Widgets
            WidgetCenter.shared.reloadAllTimelines()

            // Fix #2/#9: Reschedule time-sensitive notifications with fresh count
            // so midday/evening messages reflect real pickup data even if app wasn't opened.
            rescheduleTimeBasedNotifications(pickupCount: pickups)

            // Live Activity via APNs push — include duel state if active (fix #5 partial)
            // Duel metric = screen time: send seconds, not pickups.
            let isDuelActive = sharedDefaults.bool(forKey: "picksy_duel_active")
            let opponentName = sharedDefaults.string(forKey: "picksy_duel_opponent")
            let theirSecs    = sharedDefaults.integer(forKey: "picksy_duel_their_secs")
            let mySecs       = DuelManager.suiteBestScreenTimeSecs()

            await PushNotificationManager.shared.pushLiveActivityUpdate(
                pickupCount: pickups,
                screenTimeSecs: mySecs,
                duelOpponentName: isDuelActive ? opponentName : nil,
                duelMySecs:    isDuelActive ? mySecs : 0,
                duelTheirSecs: isDuelActive ? theirSecs : 0
            )

            task.setTaskCompleted(success: true)
            print("[BGRefresh] ✅ Completed — pickups: \(pickups), duel: \(isDuelActive)")

            // Schedule next
            scheduleBackgroundRefresh()
        }
    }

    /// Fix #2/#3/#9: Reschedules midday + evening notifications with fresh pickup count.
    /// Called from BGAppRefreshTask and from foreground/launch paths (via scheduleAllNotifications).
    /// Static so it's callable without a LiftOffApp instance.
    static func rescheduleTimeBasedNotifications(pickupCount: Int) {
        let center = UNUserNotificationCenter.current()
        let hour   = Calendar.current.component(.hour, from: Date())
        let lang   = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"

        // Retired: midday (12:00) "keep Picksy open" nudge, the 14:00
        // "Picksy check-in" nudge (see scheduleAllNotifications' static-cleanup
        // list), and the 20:00 "Evening summary" — that last one duplicated the
        // 21:00 evening notification below almost word-for-word, firing twice
        // an hour apart. Users flagged the app as too naggy; unconditional
        // removal here cleans up anyone who already has these scheduled from a
        // previous version, not just new installs.
        center.removePendingNotificationRequests(withIdentifiers: ["liftoff.midday", "picksy.summary.evening"])

        // Evening (21:00) — reschedule whenever not yet fired today.
        //
        // Deliberately carries NO pickup count anymore. It used to show the
        // live in-process counter, which can badly undercount whenever iOS
        // has suspended/killed the app for a stretch of the day — confirmed
        // in testing: the notification said "36" while the real, Apple-
        // tracked total (shown on opening the app) was 60. That accurate
        // number only ever exists INSIDE the sandboxed DeviceActivityReport
        // view — this scheduling code structurally cannot read it (same wall
        // that shaped the Dynamic Island's design). Rather than risk showing
        // a wrong number again, this stays honestly numberless; the real
        // count is only ever shown where it can be accurate — inside the app.
        if hour < 21 {
            center.removePendingNotificationRequests(withIdentifiers: ["liftoff.evening"])
            let (title, body) = eveningMessageStatic(language: lang)
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = title
            content.body  = body
            var dc = DateComponents(); dc.hour = 21; dc.minute = 0
            center.add(UNNotificationRequest(
                identifier: "liftoff.evening", content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            ))
        }
    }

    // MARK: - Static message helpers (used by rescheduleTimeBasedNotifications)
    private static func eveningMessageStatic(language: String) -> (String, String) {
        switch language {
        case "Ελληνικά":
            return ("Βραδινό check-in 🌙", "Δες πώς πήγε η μέρα σου — άνοιξε το Picksy.")
        case "Deutsch":
            return ("Abend-Check-in 🌙", "Sieh, wie dein Tag war — öffne Picksy.")
        default:
            return ("Evening check-in 🌙", "See how your day went — open Picksy.")
        }
    }

    /// Fix #5: Writes active duel state to App Group so the DeviceActivity extension
    /// can include it in APNs pushes (extension runs in separate process, no DuelManager access).
    static func syncDuelStateToAppGroup(duels: [DuelRecord]) {
        guard let shared = UserDefaults(suiteName: "group.fotiospongas.picksy") else { return }
        let active = duels.filter { $0.status == .active }
        if let first = active.first {
            shared.set(true,                   forKey: "picksy_duel_active")
            shared.set(first.theirName,        forKey: "picksy_duel_opponent")
            shared.set(first.theirPickups,     forKey: "picksy_duel_their_pickups")
            shared.set(first.theirScreenTime,  forKey: "picksy_duel_their_secs")
        } else {
            shared.set(false, forKey: "picksy_duel_active")
            shared.removeObject(forKey: "picksy_duel_opponent")
            shared.removeObject(forKey: "picksy_duel_their_pickups")
            shared.removeObject(forKey: "picksy_duel_their_secs")
        }

        // Also store duel IDs + role so the DeviceActivity extension can PATCH
        // pickup counts directly to Supabase even when the app is closed.
        let meta: [[String: String]] = active.map { duel in
            ["id": duel.id, "challenger": duel.amChallenger ? "1" : "0"]
        }
        if let json = try? JSONSerialization.data(withJSONObject: meta) {
            shared.set(json, forKey: "picksy_active_duel_meta")
        } else {
            shared.removeObject(forKey: "picksy_active_duel_meta")
        }

        // Stamp the cache with today's date so the DeviceActivity extension
        // can detect day rollover and discard stale meta from yesterday's duel.
        let todayStr: String = {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
        }()
        shared.set(todayStr, forKey: "picksy_duel_meta_cache_date")
    }

    static func scheduleBackgroundRefresh(earliestMinutes: Int = 15) {
        let request = BGAppRefreshTaskRequest(identifier: "fotiospongas.picksy.refresh")
        // earliestBeginDate = earliest iOS can fire this; actual timing is iOS's decision
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(earliestMinutes) * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[BGRefresh] 📅 Next refresh scheduled (≥\(earliestMinutes) min)")
        } catch {
            print("[BGRefresh] ❌ Schedule failed: \(error)")
        }
    }

    // MARK: - App Launch

    private func onAppLaunch() {
        let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
        let dailyGoal = goal > 0 ? goal : 50

        // Mirror device ID to shared App Group so the DeviceActivityMonitor extension
        // can include it in APNs push calls (extension can't access UserDefaults.standard).
        if let shared = UserDefaults(suiteName: "group.fotiospongas.picksy") {
            shared.set(FriendSyncManager.shared.deviceID, forKey: "picksy_device_id")
        }

        store.syncWithDeviceActivity()

        // Apple Watch: start the connectivity session and push the first snapshot.
        PhoneWatchSync.shared.activate()
        syncWatch()

        if liveActivity.isRunning {
            liveActivity.update(pickupCount: store.todayPickups)
        } else {
            liveActivity.start(pickupCount: store.todayPickups, dailyGoal: dailyGoal)
        }

        scheduleAllNotifications(pickupCount: store.todayPickups)
        startAutoTrialIfNeeded()
        NotificationDelegate.shared.tabSelection = tabSelection

        Task {
            await weatherManager.fetchWeather()
            // Pre-write weather/time-aware milestone messages to the App Group so
            // the DeviceActivityMonitor extension can read them when threshold events
            // fire (the extension can't call weatherManager directly).
            let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
            ScreenTimeMilestoneNotifier.shared.syncMilestonesToAppGroup(
                weather: weatherManager.activeCondition,
                language: lang
            )
        }

        // Show MilestoneDetailView when user taps a milestone notification
        NotificationCenter.default.addObserver(
            forName: NotificationDelegate.milestoneDetailNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let data = notification.object as? MilestoneNotificationData {
                pendingMilestone = data
            }
        }

        // Poll duel state on launch, sync pickup count, then refresh DI immediately
        Task {
            await DuelManager.shared.poll()
            await DuelManager.shared.updateMyPickups(store.todayPickups, screenTimeSeconds: store.bestScreenTimeSecs)
            await TournamentManager.shared.poll()
            await TournamentManager.shared.syncScreenTime(store.bestScreenTimeSecs)
            guard !focusSessionManager.isActive else { return }
            if let duel = DuelManager.shared.activeDuel, duel.status == .active {
                // Active duel found after poll — update DI with correct scores
                // (it was started before poll completed, so it may show 0:0)
                liveActivity.updateForDuel(
                    pickupCount: store.todayPickups,
                    opponentName: duel.theirName,
                    mySecs: store.bestScreenTimeSecs,
                    theirSecs: duel.theirScreenTime
                )
            } else {
                // No active duel — clear any stale duel state the DI may be showing
                // from a previous session (e.g. yesterday's completed duel still showing ⚔️)
                liveActivity.update(pickupCount: store.todayPickups)
            }
        }

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
            // Request background execution time BEFORE any async work.
            // The expiry handler is the safety net if iOS reclaims resources early.
            var bgTaskID = UIBackgroundTaskIdentifier.invalid
            bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "picksy.pickup") {
                UIApplication.shared.endBackgroundTask(bgTaskID)
            }

            // Synchronous bookkeeping (instant, no I/O)
            store.recordPickup()
            hourlyTracker.recordPickup()
            focusSessionManager.onPickup(currentPickups: store.todayPickups)

            // Keep the personalized evening notification's baked-in pickup
            // count as fresh as possible. Local notification content is fixed
            // at scheduling time, NOT recomputed at delivery — it previously
            // only got refreshed via BGAppRefresh (2-4x/hour) or app
            // foreground, so a pickup shortly before 21:00 could easily land
            // after the last refresh and fire with a stale, too-low count
            // (observed: notification said "11 pickups" when the real count
            // was already 12+). This runs on every real pickup, inside the
            // same background task reserved above, closing that gap.
            LiftOffApp.rescheduleTimeBasedNotifications(pickupCount: store.todayPickups)

            // Apple Watch: push the new pickup count immediately.
            syncWatch()

            // Continuous-use milestone notifications are scheduled from the
            // onScreenSessionStarted hook (fires on every unlock), not here.

            let pickups = store.todayPickups
            let g2 = UserDefaults.standard.integer(forKey: "dailyGoal")
            let goal2 = g2 > 0 ? g2 : 50

            // Restart Live Activity if iOS killed it overnight (sync path, no await needed)
            if !liveActivity.isRunning {
                liveActivity.start(pickupCount: pickups, dailyGoal: goal2)
                UIApplication.shared.endBackgroundTask(bgTaskID)
                return
            }

            Task {
                // ── 1. Local Activity.update() — fast attempt, awaited properly ───────
                // iOS may still ignore a local update from a suspended background process,
                // but we try it first because it's instant and free.
                if focusSessionManager.isActive {
                    await liveActivity.updateForFocusAsync(
                        pickupCount: pickups,
                        focusEndTime: focusSessionManager.endTime,
                        focusPickupCount: focusSessionManager.pickupsDuringSession
                    )
                } else {
                    // updateAsync handles the duel-vs-normal priority internally
                    await liveActivity.updateAsync(pickupCount: pickups)
                }

                // ── 2. ALL network calls run concurrently INSIDE the background task ──
                // pushLiveActivityUpdate sends an APNs push to the Live Activity token —
                // this is the RELIABLE path Apple recommends (server push, not local call).
                // It MUST complete before endBackgroundTask or iOS suspends us mid-request.
                //
                // Capture values on the current actor before entering @Sendable closures.
                let activeDuel       = DuelManager.shared.activeDuel
                let isDuelActive     = activeDuel?.status == .active
                let last2hPickups    = pickupsLast2h()
                let last2hScreenTime = store.screenTimeLastTwoHours

                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await FriendSyncManager.shared.uploadStatus(
                            pickups: pickups,
                            dailyGoal: goal2,
                            pickupsLast2h: last2hPickups,
                            screenTimeLast2hSecs: last2hScreenTime
                        )
                    }
                    group.addTask {
                        await DuelManager.shared.updateMyPickups(pickups, screenTimeSeconds: store.bestScreenTimeSecs)
                    }
                    group.addTask {
                        // APNs push → Supabase edge fn → Live Activity token update.
                        // More reliable than local Activity.update() from background.
                        await PushNotificationManager.shared.pushLiveActivityUpdate(
                            pickupCount: pickups,
                            screenTimeSecs: store.bestScreenTimeSecs,
                            duelOpponentName: isDuelActive ? activeDuel?.theirName : nil,
                            duelMySecs:    isDuelActive ? store.bestScreenTimeSecs : 0,
                            duelTheirSecs: isDuelActive ? (activeDuel?.theirScreenTime ?? 0) : 0
                        )
                    }
                }

                // ── 3. End background task ONLY after APNs push has been sent ─────────
                UIApplication.shared.endBackgroundTask(bgTaskID)
            }
        }
        // Continuous-use session START (fires on every real unlock while the app is
        // alive). We schedule one local notification per threshold (+1h/+2h/+3h of
        // CONTINUOUS use, counting from this unlock). This is a true continuous-
        // session model — NOT the cumulative daily total the DeviceActivityMonitor
        // used to fire (that path is now notification-free, recording confirmed time
        // only). scheduleContinuousSession() first cancels any stale alerts from a
        // previous session, so a broken session never fires.
        //
        // SAFEGUARDS against the suspended-at-lock false positive:
        //   (a) cancel on lock          — onScreenSessionEnded below
        //   (b) cancel + reschedule     — here, on the next unlock
        //   (c) cancel on BG-refresh    — handleBackgroundRefresh, when device locked
        //   (d) cancel on BG-refresh    — handleBackgroundRefresh, when unlocked but idle 10+ min
        //   (e) cancel on resign-active — ScreenUnlockDetector.handleResignActive
        //   (f) resume on become-active — onScreenSessionResumed below (only if < 10 min)
        ScreenUnlockDetector.shared.onScreenSessionStarted = {
            // The plant should start wilting the INSTANT the phone is picked
            // up, not just take a delayed lump-sum hit once it's put back down.
            store.beginPlantSession()
            let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
            ScreenTimeMilestoneNotifier.shared.scheduleContinuousSession(
                weather: weatherManager.activeCondition,
                language: lang
            )
            // Request an early BGAppRefresh so safeguard (c)/(d) runs soon after
            // session start, catching the common case where the phone is put down
            // within a few minutes and auto-locks while Picksy is suspended.
            LiftOffApp.scheduleBackgroundRefresh(earliestMinutes: 2)
        }

        // AUDIO LOCK FIX (resume path): When the user returns to Picksy after
        // a brief absence (< 10 min, e.g. Control Center or quick app switch),
        // resume the continuous session with the REMAINING time from the original
        // unlock — NOT from zero. This avoids resetting the clock on every app
        // switch, which the old code did (scheduling a full fresh session via
        // onScreenSessionStarted on each didBecomeActive).
        //
        // For long absences (≥ 10 min), the detector skips the resume entirely
        // (likely audio-lock or the user was genuinely away). The next real
        // unlock starts a fresh session via onScreenSessionStarted.
        ScreenUnlockDetector.shared.onScreenSessionResumed = {
            let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
            ScreenTimeMilestoneNotifier.shared.resumeContinuousSession(
                weather: weatherManager.activeCondition,
                language: lang
            )
        }

        ScreenUnlockDetector.shared.onScreenSessionEnded = { seconds in
            store.addUsageTime(seconds: seconds)
            // The session is over — freeze the (already continuously wilted)
            // plant health as the new baseline and resume growing from now.
            store.endPlantSession()
            // SAFEGUARD (a): the continuous session ended (screen locked) → cancel any
            // pending continuous-use alerts so they don't fire after the user stopped.
            ScreenTimeMilestoneNotifier.shared.cancelContinuousSession()
            // Re-apply Accurate Mode shields the moment the screen locks (while
            // we're still alive in the background): any app/category lifted via
            // the shield's "Open" snaps back to shielded for the next unlock.
            ShieldManager.shared.refresh()
            // Apple Watch: screen time changed → refresh the score on the wrist.
            syncWatch()
            // Live Activity views only re-render when we push a fresh ContentState
            // (unlike Text(date, style: .timer), which iOS ticks on its own) — so
            // without this, the plant's growth (just resumed by endPlantSession()
            // above) would sit invisible until some UNRELATED trigger (next pickup,
            // next BGAppRefresh) happened to push an update. Session-end is exactly
            // when the phone locks, i.e. exactly when the app is about to background —
            // this runs in the same background-survival window as the shield refresh
            // above, so there's time for the push to go out.
            liveActivity.update(pickupCount: store.todayPickups)
            print("[ScreenTime] ⏱ Session ended: \(seconds)s, total today: \(store.todayTotalSeconds)s, last2h: \(store.screenTimeLastTwoHours)s")
        }
        ScreenUnlockDetector.shared.startMonitoring()
        detector.startMonitoring()

        // Accurate Mode (opt-in): (re)apply shields on the current selection so
        // newly added apps are covered and the state survives relaunch.
        ShieldManager.shared.refresh()

        // Ensure a BGAppRefreshTask is always scheduled so iOS can wake us periodically
        // to sync pickup counts and update the Live Activity when the app is suspended.
        LiftOffApp.scheduleBackgroundRefresh()

        // Single immediate load. The 20 s safety net only fires if the extension
        // failed to render on first attempt; by then the process is warm so the
        // re-render completes in < 1 s without a visible blank.
        // NudgeView and AppsView no longer add their own immediate refresh calls,
        // so this is the only trigger on cold start.
        AppsViewRefreshTrigger.shared.refresh()
        AppsViewRefreshTrigger.shared.refreshAfter(seconds: 20.0)

        PushNotificationManager.shared.registerForPushNotifications()

        // Friend sync — upload status on launch too
        Task {
            // Sync first so any pending friend acceptances appear immediately
            await FriendSyncManager.shared.syncFriendsFromSupabase()

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

        // When a duel is finalized (expired or finished), clear the stale ⚔️ from the DI.
        // DuelManager posts this notification because it can't access LiveActivityManager directly.
        NotificationCenter.default.addObserver(
            forName: .picksyDuelFinalized,
            object: nil,
            queue: .main
        ) { [liveActivity, store] _ in
            liveActivity.update(pickupCount: store.todayPickups)
            print("[LiftOffApp] 🏁 Duel finalized — cleared DI duel state")
        }

        // ── Background survival window ──────────────────────────────────────────
        // When the app goes to background, request ~30s of execution time from iOS.
        // As long as we hold this background task, ScreenUnlockDetector's
        // protectedDataDidBecomeAvailable observer can still fire when the user
        // unlocks the phone — letting us count the pickup and push the Live Activity
        // update BEFORE the user opens the app.
        //
        // Covers the most common pattern: user puts phone down, picks it up again
        // within ~30 seconds (quick peek, checking notification, etc.).
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            var bgTaskID = UIBackgroundTaskIdentifier.invalid
            bgTaskID = UIApplication.shared.beginBackgroundTask(
                withName: "picksy.bgMonitor"
            ) {
                // Expiry handler — iOS is ending our background window (~30s).
                // If the device locked while we were in the background, we may
                // have missed protectedDataWillBecomeUnavailableNotification
                // (fired right at the lock/expiry boundary). Cancel any pending
                // continuous-session alerts now before the process is suspended.
                if !UIApplication.shared.isProtectedDataAvailable {
                    ScreenTimeMilestoneNotifier.shared.cancelContinuousSession()
                    print("[BGMonitor] 🔒 Expiry: device locked — cancelled stale continuous-session alerts")
                }
                UIApplication.shared.endBackgroundTask(bgTaskID)
            }
            // No explicit early end — let iOS run us for the full ~30s window
            // so we're still alive when a 30-second auto-lock fires and can
            // handle protectedDataWillBecomeUnavailableNotification normally.
            print("[LiftOffApp] 🔲 Background monitor started (full iOS window)")

            // Schedule BGAppRefreshTask — iOS will fire this periodically
            // (typically 2–4× per hour) to sync the pickup count & update the DI
            // even when the app has been suspended beyond the 28s window.
            LiftOffApp.scheduleBackgroundRefresh()

            // Stamp the suspension start for the blank-report recovery check.
            AppsViewRefreshTrigger.shared.noteBackgrounded()
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("[LiftOffApp] 🔆 App came to foreground")

            // Re-apply Accurate Mode shields: the ShieldAction extension lifts an
            // app's shield so it can open, so we must re-shield on every foreground
            // to keep counting subsequent opens.
            ShieldManager.shared.refresh()

            // Blank-report fix: after a long suspension the report extension is
            // usually dead and the Apps/Nudge cards come back empty — rebuild
            // once, automatically (what the manual refresh button did).
            AppsViewRefreshTrigger.shared.foregroundRecovery()

            // Navigate on foreground — notification taps win, else always home
            DispatchQueue.main.async {
                if NotificationDelegate.shared.didNavigateViaNotification {
                    NotificationDelegate.shared.didNavigateViaNotification = false
                } else {
                    tabSelection.selectedTab = 0
                }
            }

            store.syncWithDeviceActivity()
            let g = UserDefaults.standard.integer(forKey: "dailyGoal")
            let goal = g > 0 ? g : 50

            // ensureFreshActivity restarts the DI if the current activity is from
            // a previous day (staleDate fired at midnight, iOS hid the DI but left
            // activityState == .active — the normal isRunning check wouldn't restart it).
            liveActivity.ensureFreshActivity(pickupCount: store.todayPickups, dailyGoal: goal)

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
                        mySecs: store.bestScreenTimeSecs,
                        theirSecs: duel.theirScreenTime
                    )
                } else {
                    liveActivity.update(pickupCount: store.todayPickups)
                }
            }

            ScreenUnlockDetector.shared.startMonitoring()

            // Refresh evening notification with latest pickup count
            // so the 21:00 message reflects actual day data
            scheduleAllNotifications(pickupCount: store.todayPickups)

            // Single retry after 3s — avoids killing an in-progress extension render
            AppsViewRefreshTrigger.shared.refreshAfter(seconds: 3.0)

            Task {
                // Re-check version on every foreground — catches newly published force updates
                // even if the user keeps the app backgrounded for days.
                await forceUpdateManager.check()
                if forceUpdateManager.isSoftUpdateAvailable {
                    withAnimation(.spring(response: 0.5).delay(1.0)) { showSoftUpdateBanner = true }
                }

                if let token = liveActivity.pushToken {
                    await PushNotificationManager.shared.registerLiveActivityToken(token)
                }
                // Poll duel state on foreground, sync our pickup count, then refresh DI.
                // updateMyPickups() ensures that whoever brings the app to foreground
                // immediately uploads their real count — important right after a duel starts.
                await DuelManager.shared.poll()
                await DuelManager.shared.updateMyPickups(store.todayPickups, screenTimeSeconds: store.bestScreenTimeSecs)
                await TournamentManager.shared.poll()
                await TournamentManager.shared.syncScreenTime(store.bestScreenTimeSecs)
                if let duel = DuelManager.shared.activeDuel, duel.status == .active,
                   !focusSessionManager.isActive {
                    liveActivity.updateForDuel(
                        pickupCount: store.todayPickups,
                        opponentName: duel.theirName,
                        mySecs: store.bestScreenTimeSecs,
                        theirSecs: duel.theirScreenTime
                    )
                }
                // Refresh weather on foreground so the background stays current.
                // fetchWeather() has a 10-min cache guard — no extra network calls.
                await weatherManager.fetchWeather()

                // Refresh pre-computed milestone messages in the App Group so the
                // DeviceActivityMonitor extension fires accurate, weather-aware
                // notifications when Apple's usage thresholds are reached.
                let milLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
                ScreenTimeMilestoneNotifier.shared.syncMilestonesToAppGroup(
                    weather: weatherManager.activeCondition,
                    language: milLang
                )
            }

            // Friend sync — upload own status & check if any pair is also overusing
            Task {
                // Sync friends first — discovers anyone who accepted our invite
                await FriendSyncManager.shared.syncFriendsFromSupabase()

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

    /// Pickups in the current + previous hour from HourlyTracker.
    /// Wraps to hour 23 at midnight to avoid double-counting hour 0.
    private func pickupsLast2h() -> Int {
        let hour = Calendar.current.component(.hour, from: Date())
        let prev = hour > 0 ? hour - 1 : 23
        return hourlyTracker.hourlyData[0][hour] + hourlyTracker.hourlyData[0][prev]
    }

    // MARK: - Apple Watch Sync

    /// Pushes the current pickup / screen-time snapshot to the paired Watch.
    private func syncWatch() {
        let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        PhoneWatchSync.shared.send(
            pickups:      store.todayPickups,
            totalSeconds: store.bestScreenTimeSecs,
            goal:         goal > 0 ? goal : 50,
            streak:       store.currentStreak,
            language:     lang
        )
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
        KeychainHelper.save("picksyProTrialStartDate", date: Date())
        proManager.checkTrial()
    }

    // MARK: - Notifications

    // Last time static (non-personalized) notifications were scheduled.
    // Prevents redundant churn on every foreground event.
    // @State so we can mutate it from scheduleAllNotifications (App is a struct).
    @State private var lastStaticNotificationSchedule: Date = .distantPast

    private func scheduleAllNotifications(pickupCount: Int) {
        // Always reschedule personalized time-based notifications (midday + 21:00 evening)
        // so they reflect the current pickup count.
        LiftOffApp.rescheduleTimeBasedNotifications(pickupCount: pickupCount)

        // Throttle static notifications (content never changes) to at most once per 6 hours.
        // Without this, every foreground event removed and re-added all pending notifications.
        let now = Date()
        guard now.timeIntervalSince(lastStaticNotificationSchedule) > 6 * 3600 else { return }
        lastStaticNotificationSchedule = now

        let center   = UNUserNotificationCenter.current()
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        center.removePendingNotificationRequests(withIdentifiers: [
            "liftoff.weekly", "picksy.summary.afternoon", "picksy.morning.wakeup"
        ])
        scheduleMorningWakeupNotification(center: center, language: language)
        scheduleWeeklyNotification(center: center, language: language)
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

}

