// SettingsView.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026
//
// v1.7 UPDATE:
// - Νέο threshold preset picker (Light/Moderate/Strict)
// - Weather section updated για WeatherKit (auto location)
//

import SwiftUI
import UserNotifications
import StoreKit
import FamilyControls
import WidgetKit

struct SettingsView: View {
    @AppStorage("dailyGoal") private var dailyGoal: Int = 50
    @AppStorage("nudgeDisplayMode") private var nudgeDisplayMode: String = "apple"
    @AppStorage("quietStart") private var quietStart: Int = 22
    @AppStorage("quietEnd") private var quietEnd: Int = 7
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled: Bool = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("challengeDisplayName") private var challengeDisplayName: String = ""

    @Environment(ProManager.self) var proManager
    @Environment(LiveActivityManager.self) var liveActivity
    @Environment(DataStore.self) var store
    @Environment(WeatherManager.self) var weatherManager
    @Environment(ActivityPreferences.self) var activityPrefs
    @Environment(HourlyTracker.self) var hourlyTracker
    @Environment(CheckInManager.self) var checkInManager

    @State private var showAboutScience: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var showResetTodayConfirm: Bool = false
    @State private var showAppInfo: Bool = false
    @State private var showActivityPrefs: Bool = false
    @State private var showAppPicker: Bool = false
    @State private var showSharedAppsPicker: Bool = false
    @State private var pickerSelection: FamilyActivitySelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var isAuthorized: Bool = false
    @State private var showAchievements: Bool = false
    #if DEBUG
    @State private var showDebugDuelResult: Bool = false

    // Supabase dev panel
    // ── PAT: supabase.com/dashboard/account/tokens → Generate new token ──
    private static let supabasePAT = DebugSecrets.supabasePAT
    private static let supabaseProjectRef = "igbtosqmtdrxzmoblvpp"

    struct SupabaseSnapshot {
        var pickupsToday:        Int    = 0
        var screenTime2h:        Int    = 0
        var updatedAt:           String = "—"
        var pingMs:              Int?   = nil
        var edgeCallsToday:      Int    = 0
        var edgeInvocations:     Int?   = nil  // billing-cycle total from Management API
        var edgeLimit:           Int    = 500_000
        var error:               String? = nil
    }
    @State private var supabaseSnap:    SupabaseSnapshot = SupabaseSnapshot()
    @State private var supabaseLoading: Bool = false
    #endif

    // v1.7: Threshold preset
    @State private var selectedPreset: ThresholdPreset = ThresholdPreset.current

    // Accurate Mode (shield-based exact pickup counting)
    @State private var accurateMode: Bool = ShieldManager.shared.isAccurateModeOn

    // Daily time limit per tracked app (minutes; 0 = off)
    @AppStorage("picksy_timelimit_minutes") private var timeLimitMinutes: Int = 0

    // Optional passcode that gates the time limit (parental use)
    @State private var passcodeRequired: Bool = PasscodeManager.shared.isRequired
    @State private var showPasscodeSetup: Bool = false

    // App Lock: always-on passcode requirement for all shielded apps
    @State private var appLockEnabled: Bool = UserDefaults(suiteName: "group.fotiospongas.picksy")?.bool(forKey: "picksy_app_lock_enabled") ?? false
    @State private var appLockDurationMinutes: Int = {
        let v = UserDefaults(suiteName: "group.fotiospongas.picksy")?.integer(forKey: "picksy_app_lock_duration_minutes") ?? 0
        return v > 0 ? v : 30
    }()
    @State private var showAppLockPasscodeSetup: Bool = false
    @State private var showAppLockDisableConfirm: Bool = false
    // Settings lock: when a passcode is set, time-limit/passcode controls require
    // the code to change (so a child can't just turn the limit off). Resets each
    // time Settings is opened.
    @State private var settingsUnlocked: Bool = !PasscodeManager.shared.isRequired
    @State private var showSettingsUnlock: Bool = false

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    static var devBuild: String {
        guard let path = Bundle.main.executablePath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mod   = attrs[.modificationDate] as? Date
        else { return "?" }
        let f = DateFormatter(); f.dateFormat = "MMdd·HH:mm"
        return f.string(from: mod)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var quietStartDate: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: quietStart)) ?? Date() },
            set: { quietStart = Calendar.current.component(.hour, from: $0) }
        )
    }

    private var quietEndDate: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: quietEnd)) ?? Date() },
            set: { quietEnd = Calendar.current.component(.hour, from: $0) }
        )
    }

    private var activityPrefsSubtitle: String {
        let count = activityPrefs.selected.count
        let total = ActivityCategory.allCases.count
        if count == 0 || count == total {
            return t("All categories active", "Όλες οι κατηγορίες ενεργές", "Alle Kategorien aktiv")
        }
        return t("\(count) of \(total) categories", "\(count) από \(total) κατηγορίες", "\(count) von \(total) Kategorien")
    }

    private var trackedAppsSubtitle: String {
        let appsCount = pickerSelection.applicationTokens.count
        let categoriesCount = pickerSelection.categoryTokens.count
        if appsCount == 0 && categoriesCount == 0 {
            return t("Tap to choose apps", "Πάτα για να επιλέξεις εφαρμογές", "Tippe, um Apps auszuwählen")
        }
        var parts: [String] = []
        if appsCount > 0 { parts.append(t("\(appsCount) apps", "\(appsCount) εφαρμογές", "\(appsCount) Apps")) }
        if categoriesCount > 0 { parts.append(t("\(categoriesCount) categories", "\(categoriesCount) κατηγορίες", "\(categoriesCount) Kategorien")) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text(t("Settings", "Ρυθμίσεις", "Einstellungen"))
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                // Pro status
                if proManager.isPro {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                        Text("Picksy Pro").font(.system(size: 15, weight: .medium, design: .rounded))
                        Spacer()
                        Text(t("Active", "Ενεργό", "Aktiv"))
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.08)))
                    .padding(.bottom, 20)
                } else {
                    Button(action: { showPaywall = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.circle.fill").foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("Upgrade to Picksy Pro", "Αναβάθμιση σε Picksy Pro", "Auf Picksy Pro upgraden"))
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("Heatmap, rewards, quote packs")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("€4.99").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.blue)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                    }
                    .padding(.bottom, 20)
                }

                // Display name for challenges
                SettingRow(
                    title: t("Your name", "Το όνομά σου", "Dein Name"),
                    subtitle: t("Shown when you send a challenge", "Εμφανίζεται όταν στέλνεις πρόκληση", "Wird bei Herausforderungen angezeigt")
                ) {
                    TextField(t("Optional", "Προαιρετικό", "Optional"), text: $challengeDisplayName)
                        .font(.system(size: 15, design: .rounded))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }

                Divider()

                // MARK: - Trophies (formerly its own tab)
                achievementsRow

                Divider()

                // Language
                SettingRow(
                    title: t("Language", "Γλώσσα", "Sprache"),
                    subtitle: t("Nudge message language", "Γλώσσα nudge μηνυμάτων", "Sprache der Erinnerungen")
                ) {
                    Picker("", selection: $appLanguage) {
                        ForEach(QuoteBank.Language.allCases, id: \.rawValue) { lang in
                            Text(lang.rawValue).tag(lang.rawValue)
                        }
                    }.pickerStyle(.menu)
                }

                Divider()

                // Daily goal
                SettingRow(
                    title: t("Daily goal", "Ημερήσιος στόχος", "Tagesziel"),
                    subtitle: t("Max pickups per day", "Μέγιστα σηκώματα ανά μέρα", "Maximale Griffe pro Tag")
                ) {
                    Stepper("\(dailyGoal)", value: $dailyGoal, in: 20...250, step: 10)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }

                Divider()

                // Nudge ring display mode
                VStack(alignment: .leading, spacing: 6) {
                    SettingRow(
                        title: t("Pickup number", "Αριθμός σηκωμάτων", "Griff-Anzahl"),
                        subtitle: t("Shown on Nudge and Stats", "Εμφανίζεται στο Nudge και τα Στατιστικά", "Auf Nudge und Statistik angezeigt")
                    ) {
                        Picker("", selection: $nudgeDisplayMode) {
                            Text(t("Live", "Ζωντανό", "Live")).tag("live")
                            Text(t("Apple", "Apple", "Apple")).tag("apple")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    Text(nudgeDisplayMode == "apple"
                         ? t("Apple's own tracked count of pickups that actually opened an app — the most meaningful usage number, not just screen glances. Naturally lower than the raw total in Settings → Screen Time, which also counts quick glances where nothing was opened. Updates when you open the app, not live.",
                             "Ο αριθμός που παρακολουθεί η ίδια η Apple για σηκώματα που πραγματικά άνοιξαν μια εφαρμογή — η πιο ουσιαστική μέτρηση χρήσης, όχι απλές ματιές στην οθόνη. Φυσιολογικά χαμηλότερο από το ακατέργαστο σύνολο στο Ρυθμίσεις → Screen Time, το οποίο μετράει και γρήγορες ματιές χωρίς άνοιγμα εφαρμογής. Ενημερώνεται στο άνοιγμα της εφαρμογής, όχι ζωντανά.",
                             "Apples eigene erfasste Zahl der Griffe, die tatsächlich eine App geöffnet haben — die aussagekräftigste Nutzungszahl, nicht nur ein Blick aufs Display. Natürlich niedriger als die Rohzahl in Einstellungen → Bildschirmzeit, die auch kurze Blicke ohne App-Start mitzählt. Aktualisiert beim App-Öffnen, nicht live.")
                         : t("Shows Picksy's own live-updating count. Most accurate if you keep opening the app during the day.",
                             "Δείχνει τον δικό μας ζωντανό μετρητή. Πιο ακριβής όσο πιο συχνά ανοίγεις την εφαρμογή μέσα στην ημέρα.",
                             "Zeigt Picksys eigenen live aktualisierten Zähler. Am genauesten, wenn du die App tagsüber oft öffnest."))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Divider()

                // Live Activity
                SettingRow(
                    title: "Live Activity",
                    subtitle: t("Show pickups on Lock Screen", "Δείξε σηκώματα στο Lock Screen", "Griffe auf dem Sperrbildschirm anzeigen")
                ) {
                    Toggle("", isOn: Binding(
                        get: { liveActivityEnabled },
                        set: { newValue in
                            liveActivityEnabled = newValue
                            if newValue {
                                let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
                                liveActivity.start(pickupCount: store.todayPickups, dailyGoal: goal > 0 ? goal : 50)
                            } else {
                                liveActivity.stopAll()
                            }
                        }
                    )).labelsHidden()
                }

                Divider()

                // Notifications
                SettingRow(
                    title: t("Notifications", "Ειδοποιήσεις", "Benachrichtigungen"),
                    subtitle: t("Zone alerts and check-ins", "Ειδοποιήσεις ζωνών και ενημερώσεις", "Zonenwarnungen und Check-ins")
                ) {
                    Toggle("", isOn: Binding(
                        get: { notificationsEnabled },
                        set: { newValue in
                            notificationsEnabled = newValue
                            if newValue { requestAndScheduleNotifications() }
                            else {
                                UNUserNotificationCenter.current()
                                    .removePendingNotificationRequests(withIdentifiers: ["liftoff.midday", "liftoff.evening"])
                            }
                        }
                    )).labelsHidden()
                }

                Divider()

                // Quiet hours
                SettingRow(
                    title: t("Quiet hours — From", "Ώρες ησυχίας — Από", "Ruhezeit — Von"),
                    subtitle: t("No nudges from", "Χωρίς nudges από", "Keine Erinnerungen ab")
                ) {
                    DatePicker("", selection: quietStartDate, displayedComponents: .hourAndMinute).labelsHidden()
                }

                Divider()

                SettingRow(
                    title: t("Quiet hours — Until", "Ώρες ησυχίας — Μέχρι", "Ruhezeit — Bis"),
                    subtitle: t("No nudges until", "Χωρίς nudges μέχρι", "Keine Erinnerungen bis")
                ) {
                    DatePicker("", selection: quietEndDate, displayedComponents: .hourAndMinute).labelsHidden()
                }

                Divider()

                // MARK: - v1.7 Threshold Preset
                thresholdSection

                Divider()

                // MARK: - Weather (v1.7: WeatherKit auto location)
                weatherSection

                Divider()

                // Activity Preferences
                Button(action: { showActivityPrefs = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(t("Activity preferences", "Προτιμήσεις δραστηριοτήτων", "Aktivitätspräferenzen"))
                                    .font(.system(size: 15, weight: .regular, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("✨").font(.system(size: 13))
                            }
                            Text(activityPrefsSubtitle)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                }

                Divider()

                // Accurate tracking header
                Text(t("Accurate tracking", "Ακριβής μέτρηση", "Genaue Verfolgung"))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 24)
                    .padding(.bottom, 4)

                familyControlsRow
                Divider()
                trackedAppsRow
                Divider()
                sharedAppsRow
                Divider()
                accurateModeRow
                Divider()
                if PasscodeManager.shared.isRequired && !settingsUnlocked {
                    lockedSettingsRow
                } else {
                    timeLimitRow
                    if timeLimitMinutes > 0 {
                        Divider()
                        passcodeRow
                        if passcodeRequired {
                            parentalLockTip
                        }
                    }
                }
                Divider()
                appLockRow
                Divider()
                resetSection

                #if DEBUG
                debugSection
                #endif

                aboutSection

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView().environment(proManager)
        }
        .sheet(isPresented: $showActivityPrefs) {
            ActivityPreferencesSheet().environment(activityPrefs)
        }
        .sheet(isPresented: $showAboutScience) {
            AboutScienceView()
        }
        .sheet(isPresented: $showAchievements) {
            AchievementsView(onUnlockTap: { showPaywall = true })
                .environment(proManager)
        }
        #if DEBUG
        .sheet(isPresented: $showDebugDuelResult) {
            let myID = FriendSyncManager.shared.deviceID
            let mockDuel = DuelRecord(
                id: "debug-duel",
                challengerId: myID,
                opponentId: "opponent-debug-id",
                challengerName: "You",
                opponentName: "Test Friend",
                status: .completed,
                startedAt: Date(),
                endsAt: Date(),
                challengerPickups: 22,
                opponentPickups: 45,
                challengerScreenTime: 3600,
                opponentScreenTime: 7200,
                winnerId: myID,
                createdAt: Date()
            )
            DuelResultView(duel: mockDuel, hourlyData: Array(repeating: 0, count: 24))
        }
        #endif
        .familyActivityPicker(isPresented: $showAppPicker, selection: $pickerSelection)
        .onAppear {
            isAuthorized = FamilyControlsManager.shared.isAuthorized
            pickerSelection = AppSelectionStore.shared.selection
            selectedPreset = ThresholdPreset.current
        }
        .onChange(of: pickerSelection) { _, newValue in
            AppSelectionStore.shared.selection = newValue
            UsageThresholdManager.shared.restartMonitoring()
            // Accurate Mode: shield the updated selection right away so a newly
            // added app is locked immediately (no need to relaunch / re-lock).
            ShieldManager.shared.refresh()
        }
        // Mirror dailyGoal to App Group suite immediately so the widget reflects
        // the new goal without waiting for the next pickup (which triggers saveData).
        .onChange(of: dailyGoal) { _, newValue in
            UserDefaults(suiteName: "group.fotiospongas.picksy")?.set(newValue, forKey: "dailyGoal")
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: timeLimitMinutes) { _, newValue in
            // Mirror to App Group so the monitor extension reads the new limit,
            // then restart monitoring to (re)register the time-limit event.
            UserDefaults(suiteName: "group.fotiospongas.picksy")?.set(newValue, forKey: "picksy_timelimit_minutes")
            UsageThresholdManager.shared.restartMonitoring()
            // Turned off → remove any active time-limit shield immediately.
            if newValue == 0 { ShieldManager.shared.clearTimeLimitShield() }
        }
    }

    // MARK: - Achievements Row

    private var achievementsRow: some View {
        Button(action: { showAchievements = true }) {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.yellow)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Trophies & Achievements", "Τρόπαια & Επιτεύγματα", "Trophäen & Erfolge"))
                        .font(.system(size: 15, design: .rounded))
                    Text(t("See your milestones", "Δες τα ορόσημά σου", "Sieh deine Meilensteine"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    // MARK: - Accurate Mode (shield-based exact pickup counting)

    private var accurateModeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(t("Distraction Shield", "Ασπίδα Περισπασμών", "Ablenkungsschutz"))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                        Text("🛡️").font(.system(size: 13))
                    }
                    Text(t(
                        "Mute and gently block the apps you choose — fewer distractions for you, less mindless scrolling for your kid. Their notifications stay silent while it's on. (Also makes pickup counts exact.)",
                        "Σίγασε και φρέναρε απαλά τις εφαρμογές που διάλεξες — λιγότεροι περισπασμοί για σένα, λιγότερη άσκοπη περιήγηση για το παιδί σου. Όσο είναι ενεργό, οι ειδοποιήσεις τους μένουν σιωπηλές. (Κάνει και τη μέτρηση σηκωμάτων ακριβή.)",
                        "Schalte deine ausgewählten Apps stumm und bremse sie sanft — weniger Ablenkung für dich, weniger gedankenloses Scrollen für dein Kind. Solange aktiv, bleiben ihre Benachrichtigungen stumm. (Zählt Griffe außerdem exakt.)"
                    ))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    // Category ticks now expand to the category's CURRENT apps
                    // (includeEntireCategory), so locking is strictly per-app.
                    // Only remaining caveat: apps installed later into a ticked
                    // category aren't auto-added until the picker is reopened.
                    if AppSelectionStore.shared.selectedCategoriesCount > 0 {
                        Text(t(
                            "Category picks include the apps installed right now — new apps you install later aren't added automatically. Reopen the app picker to include them.",
                            "Η επιλογή κατηγορίας περιλαμβάνει τις εφαρμογές που έχεις τώρα — νέες εφαρμογές που εγκαθιστάς αργότερα δεν προστίθενται αυτόματα. Ξανάνοιξε την επιλογή εφαρμογών για να μπουν.",
                            "Eine Kategorie-Auswahl umfasst die jetzt installierten Apps — später installierte Apps werden nicht automatisch ergänzt. Öffne die App-Auswahl erneut, um sie aufzunehmen."
                        ))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { accurateMode },
                    set: { newValue in
                        accurateMode = newValue
                        ShieldManager.shared.setAccurateMode(newValue)
                    }
                ))
                .labelsHidden()
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Daily time limit per app

    private func timeLimitLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0:   return t("Off", "Ανενεργό", "Aus")
        case 60:  return t("1 hour", "1 ώρα", "1 Std.")
        case 90:  return t("1.5 hours", "1.5 ώρες", "1,5 Std.")
        case 120: return t("2 hours", "2 ώρες", "2 Std.")
        default:  return t("\(minutes) min", "\(minutes) λεπτά", "\(minutes) Min.")
        }
    }

    private var timeLimitRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(t("Daily time limit", "Ημερήσιο όριο χρόνου", "Tägliches Zeitlimit"))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                    Text("⏳").font(.system(size: 13))
                }
                Text(t(
                    "After this much time in your tracked apps today, a reminder screen appears when you open them.",
                    "Μόλις περάσεις τόση ώρα στις tracked apps σήμερα, εμφανίζεται οθόνη υπενθύμισης όταν τις ανοίγεις.",
                    "Nach so viel Zeit in deinen verfolgten Apps erscheint heute ein Hinweis beim Öffnen."
                ))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Menu {
                ForEach([0, 15, 30, 60, 90, 120], id: \.self) { mins in
                    Button(timeLimitLabel(mins)) { timeLimitMinutes = mins }
                }
            } label: {
                Text(timeLimitLabel(timeLimitMinutes))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.indigo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.indigo.opacity(0.12)))
            }
        }
        .padding(.vertical, 16)
    }

    private var passcodeRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(t("Passcode to continue", "Κωδικός για συνέχεια", "Code zum Fortfahren"))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                    Text("🔒").font(.system(size: 13))
                }
                Text(t(
                    "After the limit, apps lock and only your passcode grants another session — great for giving a child the phone for a set time.",
                    "Μετά το όριο, οι apps κλειδώνουν και μόνο ο κωδικός σου δίνει νέα session — ιδανικό για να δώσεις στο παιδί το κινητό για συγκεκριμένο χρόνο.",
                    "Nach dem Limit sperren Apps und nur dein Code gewährt eine neue Sitzung — ideal, um dem Kind das Handy für eine bestimmte Zeit zu geben."
                ))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { passcodeRequired },
                set: { newValue in
                    if newValue {
                        showPasscodeSetup = true   // confirm by setting a code
                    } else {
                        PasscodeManager.shared.disable()
                        passcodeRequired = false
                        // App lock shares the same passcode — disable it too.
                        if appLockEnabled {
                            appLockEnabled = false
                            UserDefaults(suiteName: "group.fotiospongas.picksy")?.set(false, forKey: "picksy_app_lock_enabled")
                            PasscodeManager.shared.clearAppLockUnlockWindow()
                        }
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 16)
        .sheet(isPresented: $showPasscodeSetup, onDismiss: {
            // If the user dismissed without finishing setup, keep it off.
            passcodeRequired = PasscodeManager.shared.isRequired
        }) {
            PasscodeView(
                mode: .setup,
                onSet: { code in
                    PasscodeManager.shared.setPasscode(code)
                    passcodeRequired = true
                    showPasscodeSetup = false
                },
                onCancel: { showPasscodeSetup = false }
            )
        }
    }

    private var parentalLockTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(.indigo)
            Text(t(
                "Full parental lock: in iOS Settings → Screen Time → Content & Privacy Restrictions → App Deletion → Don't Allow, so Picksy can't be deleted.",
                "Πλήρες γονικό κλείδωμα: στις Ρυθμίσεις iOS → Χρόνος επί οθόνης → Περιεχόμενο & Απόρρητο → Διαγραφή εφαρμογών → Να μην επιτρέπεται, ώστε να μη διαγράφεται το Picksy.",
                "Vollständige Kindersicherung: in iOS Einstellungen → Bildschirmzeit → Inhalt & Datenschutz → App löschen → Nicht erlauben, damit Picksy nicht gelöscht werden kann."
            ))
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo.opacity(0.06)))
        .padding(.vertical, 8)
    }

    private var appLockRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(t("App Lock", "Κλείδωμα εφαρμογών", "App-Sperre"))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                        Text("🔐").font(.system(size: 13))
                    }
                    Text(t(
                        "Require passcode before opening any shielded app, regardless of time limits.",
                        "Απαιτεί κωδικό πριν ανοίξει οποιαδήποτε εποπτευόμενη εφαρμογή, ανεξάρτητα από χρονικά όρια.",
                        "Passcode vor dem Öffnen einer überwachten App erforderlich, unabhängig von Zeitlimits."
                    ))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appLockEnabled },
                    set: { newValue in
                        if newValue {
                            if PasscodeManager.shared.isSet {
                                appLockEnabled = true
                                UserDefaults(suiteName: "group.fotiospongas.picksy")?.set(true, forKey: "picksy_app_lock_enabled")
                            } else {
                                showAppLockPasscodeSetup = true
                            }
                        } else {
                            // Require passcode verification before disabling — prevents
                            // bypassing App Lock by simply turning the toggle off.
                            showAppLockDisableConfirm = true
                            // Don't change appLockEnabled yet; the binding reverts the
                            // toggle to ON until the passcode is confirmed.
                        }
                    }
                ))
                .labelsHidden()
            }

            if appLockEnabled {
                HStack(spacing: 12) {
                    Text(t("Unlock for", "Ξεκλείδωσε για", "Freischalten für"))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                    Picker("", selection: Binding(
                        get: { appLockDurationMinutes },
                        set: { v in
                            appLockDurationMinutes = v
                            UserDefaults(suiteName: "group.fotiospongas.picksy")?.set(v, forKey: "picksy_app_lock_duration_minutes")
                        }
                    )) {
                        Text(t("15 min", "15 λεπτά", "15 Min")).tag(15)
                        Text(t("30 min", "30 λεπτά", "30 Min")).tag(30)
                        Text(t("1 hour", "1 ώρα", "1 Std")).tag(60)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 16)
        .sheet(isPresented: $showAppLockPasscodeSetup, onDismiss: {
            appLockEnabled = PasscodeManager.shared.isSet
            if appLockEnabled {
                UserDefaults(suiteName: "group.fotiospongas.picksy")?.set(true, forKey: "picksy_app_lock_enabled")
            }
        }) {
            PasscodeView(
                mode: .setup,
                onSet: { code in
                    PasscodeManager.shared.setPasscode(code)
                    passcodeRequired = true
                    appLockEnabled = true
                    UserDefaults(suiteName: "group.fotiospongas.picksy")?.set(true, forKey: "picksy_app_lock_enabled")
                    showAppLockPasscodeSetup = false
                },
                onCancel: { showAppLockPasscodeSetup = false }
            )
        }
        .sheet(isPresented: $showAppLockDisableConfirm) {
            PasscodeView(
                mode: .unlock,
                onUnlock: {
                    appLockEnabled = false
                    UserDefaults(suiteName: "group.fotiospongas.picksy")?.set(false, forKey: "picksy_app_lock_enabled")
                    PasscodeManager.shared.clearAppLockUnlockWindow()
                    showAppLockDisableConfirm = false
                },
                onCancel: { showAppLockDisableConfirm = false }
            )
        }
    }

    private var lockedSettingsRow: some View {
        Button(action: { showSettingsUnlock = true }) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Time limit & passcode", "Όριο χρόνου & κωδικός", "Zeitlimit & Code"))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                    Text(t("Locked — tap to enter passcode", "Κλειδωμένο — πάτα για κωδικό", "Gesperrt — zum Eingeben tippen"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
        }
        .sheet(isPresented: $showSettingsUnlock) {
            PasscodeView(
                mode: .unlock,
                onUnlock: { settingsUnlocked = true; showSettingsUnlock = false },
                onCancel: { showSettingsUnlock = false }
            )
        }
    }

    // MARK: - Threshold Section (v1.7)

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Usage alerts", "Ειδοποιήσεις χρήσης", "Nutzungswarnungen"))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                    Text(t(
                        "Alert me when I spend",
                        "Ειδοποίησέ με όταν ξοδέψω",
                        "Benachrichtige mich bei"
                    ))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 16)

            // 3 preset cards
            VStack(spacing: 8) {
                ForEach(ThresholdPreset.allCases, id: \.rawValue) { preset in
                    presetCard(preset)
                }
            }
            .padding(.bottom, 8)
        }
    }

    private func presetCard(_ preset: ThresholdPreset) -> some View {
        Button(action: {
            selectedPreset = preset
            ThresholdPreset.save(preset)
            UsageThresholdManager.shared.restartMonitoring()
        }) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(selectedPreset == preset ? Color.blue : Color.secondary.opacity(0.4), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if selectedPreset == preset {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(preset.displayName(language: appLanguage))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)

                        if preset == .light {
                            Text(t("Recommended", "Προτεινόμενο", "Empfohlen"))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green))
                        }
                    }
                    Text(preset.subtitle(language: appLanguage))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedPreset == preset
                          ? Color.blue.opacity(0.08)
                          : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedPreset == preset
                                    ? Color.blue.opacity(0.3)
                                    : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weather Section (v1.7: WeatherKit)

    private var weatherSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(t("Weather", "Καιρός", "Wetter"))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)

                    if let weather = weatherManager.currentWeather {
                        Text(weather.condition.emoji).font(.system(size: 14))
                        Text("\(Int(weather.temperature))°C")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                if let weather = weatherManager.currentWeather,
                   !weather.cityName.isEmpty,
                   weather.cityName != "Current Location" {
                    Text(weather.cityName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.blue)
                } else if weatherManager.hasLocationPermission {
                    Text(t("Using current location", "Χρήση τρέχουσας τοποθεσίας", "Aktuellen Standort verwenden"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text(t("Tap to allow location", "Πάτα για να επιτρέψεις τοποθεσία", "Tippe um Standort zu erlauben"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()

            if weatherManager.isLoading {
                ProgressView()
            } else {
                Button(action: {
                    Task { await weatherManager.manualRefresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                MidnightCountdownView(iconColor: .secondary, textColor: .secondary, fontSize: 12)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
            .padding(.top, 8)

            Button(action: { showResetConfirm = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("Reset Picksy stats", "Επαναφορά στατιστικών Picksy", "Picksy-Statistiken zurücksetzen"))
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.red)
                        Text(t("Pickups, streak, totals", "Σηκώματα, σερί, σύνολα", "Griffe, Serien, Gesamt"))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "trash").font(.system(size: 14)).foregroundColor(.red)
                }
                .padding(.vertical, 16)
            }
            .alert(
                t("Reset Picksy stats?", "Επαναφορά στατιστικών;", "Picksy-Statistiken zurücksetzen?"),
                isPresented: $showResetConfirm
            ) {
                Button(t("Reset", "Επαναφορά", "Zurücksetzen"), role: .destructive) {
                    store.resetAllStats()
                }
                Button(t("Cancel", "Ακύρωση", "Abbrechen"), role: .cancel) {}
            } message: {
                Text(t(
                    "This resets your pickup count, streak, weekly history, and totals.\n\nApp usage time is managed by iOS Screen Time and resets automatically at midnight.",
                    "Αυτό επαναφέρει τα σηκώματα, το σερί, την εβδομαδιαία ιστορία και τα σύνολα.\n\nΟ χρόνος χρήσης εφαρμογών διαχειρίζεται από το iOS Screen Time.",
                    "Dies setzt deine Griffe, Serie, Wochen-Verlauf und Gesamtwerte zurück.\n\nDie App-Nutzungszeit wird von iOS Bildschirmzeit verwaltet."
                ))
            }
        }
    }

    // MARK: - Debug Section (DEBUG builds only)
    //
    // Lets you toggle Pro status during development to verify Free vs Pro UI.
    // Wrapped in #if DEBUG so it is completely stripped from App Store builds.

    #if DEBUG
    /// One-line shield-handoff diagnosis: ShieldAction breadcrumb + ages of the
    /// files the ShieldConfiguration extension tries to write. Decodes whether
    /// (a) the token handoff works, (b) config writes are discarded, or (c) the
    /// app token was nil in the category variant.
    private var shieldDebugInfo: String {
        let groupID = "group.fotiospongas.picksy"
        let action = UserDefaults(suiteName: groupID)?
            .string(forKey: "picksy_shield_debug") ?? "no taps yet"

        func fileAge(_ name: String) -> String {
            guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
                .appendingPathComponent(name),
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                let mod = attrs[.modificationDate] as? Date
            else { return "—" }
            return "\(Int(Date().timeIntervalSince(mod)))s"
        }

        return "shield: \(action)\nmarker: \(fileAge("shield_config_marker.txt")) · token: \(fileAge("last_shield_token.json"))"
    }

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                Text("DEV ONLY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
            }
            .padding(.top, 28)

            HStack(spacing: 8) {
                Image(systemName: proManager.isPro ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundColor(proManager.isPro ? .green : .orange)
                Text("Pro Status: \(proManager.isPro ? "Active" : "Locked")")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }

            // Shield handoff diagnostics: which path the ShieldAction took on the
            // last tap, and whether the ShieldConfiguration extension's writes
            // (marker/token files) are landing at all. Re-enter Settings to refresh.
            Text(shieldDebugInfo)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: { proManager.isPro = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.open.fill").font(.system(size: 12))
                        Text("Force Pro").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(proManager.isPro ? Color.gray : Color.green))
                }
                .disabled(proManager.isPro)

                Button(action: { proManager.isPro = false }) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.system(size: 12))
                        Text("Force Free").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(!proManager.isPro ? Color.gray : Color.orange))
                }
                .disabled(!proManager.isPro)
            }

            Divider().padding(.vertical, 4)

            HStack(spacing: 10) {
                Button(action: { store.resetTodayPickups() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 12))
                        Text("Reset Pickups").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.red.opacity(0.8)))
                }

                Button(action: { showDebugDuelResult = true }) {
                    HStack(spacing: 6) {
                        Text("🏆").font(.system(size: 12))
                        Text("Test Win").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.purple.opacity(0.8)))
                }
            }

            Button(action: {
                // Re-show the onboarding flow without deleting the app.
                UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward.circle.fill").font(.system(size: 12))
                    Text("Reset Onboarding").font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.blue.opacity(0.85)))
            }

            Button(action: {
                // Simulate an older install so "What's new" shows on next launch.
                UserDefaults.standard.set("0.0", forKey: "picksy_last_seen_version")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.rectangle.stack").font(.system(size: 12))
                    Text("Reset What's New (relaunch)").font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.pink.opacity(0.8)))
            }

            // Demo data for App Store screenshots
            HStack(spacing: 10) {
                Button(action: {
                    store.seedDemoData()
                    hourlyTracker.seedDemo()
                    checkInManager.seedDemo()
                    DuelManager.shared.injectDemoDuel()
                    FriendSyncManager.shared.registeredPairs = [
                        RegisteredPair(deviceID: "demo-alex", name: "Alex", registeredAt: Date().addingTimeInterval(-86400 * 3)),
                        RegisteredPair(deviceID: "demo-john", name: "John", registeredAt: Date().addingTimeInterval(-86400 * 8))
                    ]
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars").font(.system(size: 12))
                        Text("Seed Demo").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.teal.opacity(0.85)))
                }

                Button(action: {
                    store.clearDemoData()
                    hourlyTracker.clearDemo()
                    checkInManager.clearDemo()
                    DuelManager.shared.clearDemoDuel()
                    FriendSyncManager.shared.registeredPairs = []
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash").font(.system(size: 12))
                        Text("Clear Demo").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.gray.opacity(0.7)))
                }
            }

            // Funny sounds preview — άμεση ακρόαση χωρίς να στήνεις σενάριο
            // (αγνοεί το toggle και τα once-per-day/hour throttles)
            HStack(spacing: 10) {
                Button(action: { FunnySFX.shared.previewTrombone() }) {
                    HStack(spacing: 6) {
                        Text("🎺").font(.system(size: 12))
                        Text("Test Trombone").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.orange.opacity(0.85)))
                }

                Button(action: { FunnySFX.shared.previewOuf() }) {
                    HStack(spacing: 6) {
                        Text("😮‍💨").font(.system(size: 12))
                        Text("Test Ouf").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.indigo.opacity(0.85)))
                }
            }

            // Duel result sounds preview
            HStack(spacing: 10) {
                Button(action: { FunnySFX.shared.previewVictory() }) {
                    HStack(spacing: 6) {
                        Text("🏆").font(.system(size: 12))
                        Text("Test Victory").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.green.opacity(0.8)))
                }

                Button(action: { FunnySFX.shared.previewDefeat() }) {
                    HStack(spacing: 6) {
                        Text("💀").font(.system(size: 12))
                        Text("Test Defeat").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.red.opacity(0.75)))
                }
            }

            Divider().padding(.vertical, 4)

            // ── Supabase dev panel ─────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text("SUPABASE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Spacer()
                    Button(action: { fetchSupabaseSnapshot() }) {
                        Image(systemName: supabaseLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .rotationEffect(.degrees(supabaseLoading ? 360 : 0))
                            .animation(supabaseLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: supabaseLoading)
                    }
                }

                let devID = FriendSyncManager.shared.deviceID
                HStack(spacing: 4) {
                    Text("id: \(devID.prefix(16))…")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    Button(action: { UIPasteboard.general.string = devID }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                if let err = supabaseSnap.error {
                    Text("❌ \(err)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red)
                } else {
                    Group {
                        supabaseRow("pickups_today",    "\(supabaseSnap.pickupsToday)")
                        supabaseRow("screen_time_2h",   "\(supabaseSnap.screenTime2h / 60) min")
                        supabaseRow("updated_at",       supabaseSnap.updatedAt)
                        if let inv = supabaseSnap.edgeInvocations {
                            let pct = Int(Double(inv) / Double(supabaseSnap.edgeLimit) * 100)
                            supabaseRow("edge_fn_total",
                                        "\(inv.formatted()) / \(supabaseSnap.edgeLimit.formatted()) (\(pct)%)")
                        }
                        if let ms = supabaseSnap.pingMs {
                            supabaseRow("ping", "\(ms) ms")
                        }
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.2), lineWidth: 1))
            .onAppear {
                fetchSupabaseSnapshot()
                fetchEdgeUsage()
            }

            Text("These buttons exist only in DEBUG builds and will not appear in the App Store version.")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    private func supabaseRow(_ key: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private func fetchEdgeUsage() {
        let supabaseURL  = "https://igbtosqmtdrxzmoblvpp.supabase.co"
        let supabaseAnon = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"
        guard let url = URL(string: "\(supabaseURL)/rest/v1/edge_usage?select=calls&id=eq.1") else { return }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(supabaseAnon,        forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseAnon)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let rows  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let calls = rows.first?["calls"] as? Int
            else { return }
            DispatchQueue.main.async {
                supabaseSnap.edgeInvocations = calls
                supabaseSnap.edgeLimit       = 500_000
            }
        }.resume()
    }

    private func fetchSupabaseSnapshot() {
        let deviceID = FriendSyncManager.shared.deviceID
        guard !deviceID.isEmpty else { return }

        let supabaseURL  = "https://igbtosqmtdrxzmoblvpp.supabase.co"
        let supabaseAnon = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"

        let escaped = deviceID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceID
        let urlStr  = "\(supabaseURL)/rest/v1/device_status?device_id=eq.\(escaped)&select=pickups_today,screen_time_last_2h_seconds,updated_at&limit=1"
        guard let url = URL(string: urlStr) else { return }

        supabaseLoading = true
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let edgeKey = "picksy_debug_edge_calls_\(fmt.string(from: Date()))"
        let edgeCalls = UserDefaults(suiteName: "group.fotiospongas.picksy")?.integer(forKey: edgeKey) ?? 0
        // Keep the edge total visible during refresh — don't flash nil
        let savedInv = supabaseSnap.edgeInvocations
        let savedLim = supabaseSnap.edgeLimit
        supabaseSnap = SupabaseSnapshot(edgeCallsToday: edgeCalls)
        supabaseSnap.edgeInvocations = savedInv
        supabaseSnap.edgeLimit       = savedLim

        var req = URLRequest(url: url)
        req.setValue("application/json",   forHTTPHeaderField: "Accept")
        req.setValue(supabaseAnon,         forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseAnon)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8

        let start = Date()
        URLSession.shared.dataTask(with: req) { data, response, error in
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            DispatchQueue.main.async {
                supabaseLoading = false
                if let err = error {
                    supabaseSnap.error = err.localizedDescription
                    return
                }
                guard let data,
                      let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let row  = rows.first
                else {
                    supabaseSnap.error = "no row found"
                    return
                }
                // Preserve edgeInvocations/edgeLimit — fetchEdgeUsage() runs concurrently
                // and whichever callback fires last would otherwise wipe the other's result.
                var snap = SupabaseSnapshot(edgeCallsToday: edgeCalls)
                snap.pickupsToday    = row["pickups_today"]               as? Int ?? 0
                snap.screenTime2h    = row["screen_time_last_2h_seconds"] as? Int ?? 0
                snap.updatedAt       = (row["updated_at"] as? String ?? "—")
                    .replacingOccurrences(of: "T", with: " ")
                    .prefix(19).description
                snap.pingMs          = ms
                snap.edgeInvocations = supabaseSnap.edgeInvocations
                snap.edgeLimit       = supabaseSnap.edgeLimit
                supabaseSnap = snap
            }
        }.resume()
    }
    #endif

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("About", "Σχετικά", "Über"))
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top, 28)

            Text(t(
                "Picksy helps you build awareness of your phone habits. No judgment, no shaming — just a gentle reminder to be intentional.",
                "Το Picksy σε βοηθάει να συνειδητοποιείς τις συνήθειές σου με το κινητό. Χωρίς κριτική — απλά μια ήρεμη υπενθύμιση να είσαι πιο συνειδητός.",
                "Picksy hilft dir, deine Handygewohnheiten zu erkennen. Kein Urteil — nur eine sanfte Erinnerung, bewusster zu sein."
            ))
            .font(.system(size: 14, design: .rounded))
            .foregroundColor(.secondary)
            .lineSpacing(4)

            Text("v\(appVersion) — " + t("Made with care by", "Φτιαγμένο με μεράκι από", "Mit Sorgfalt entwickelt von") + " Fotios Pongas")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

            #if DEBUG
            Text("🛠 internal build \(SettingsView.devBuild)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.orange.opacity(0.7))
                .padding(.bottom, 2)
            #endif

            VStack(spacing: 0) {
                Link(destination: URL(string: "https://fotiospongas.dev")!) {
                    aboutRow(icon: "globe", color: .blue, title: t("Website", "Ιστότοπος", "Webseite"))
                }
                Divider().padding(.leading, 44)
                Link(destination: URL(string: "https://fotiospongas.dev/privacy-policy")!) {
                    aboutRow(icon: "lock.shield.fill", color: .gray, title: t("Privacy Policy", "Πολιτική Απορρήτου", "Datenschutzrichtlinie"))
                }
                Divider().padding(.leading, 44)
                Link(destination: URL(string: "https://apps.apple.com/app/picksy-be-present/id6761116771?action=write-review")!) {
                    aboutRow(icon: "star.fill", color: .orange, title: t("Rate Picksy", "Αξιολόγησε το Picksy", "Picksy bewerten"))
                }
                Divider().padding(.leading, 44)
                Button(action: { showAboutScience = true }) {
                    aboutRow(icon: "atom", color: .green, title: t("Science behind Picksy", "Η επιστήμη πίσω από το Picksy", "Wissenschaft hinter Picksy"))
                }
                Divider().padding(.leading, 44)
                Button(action: { showAppInfo = true }) {
                    aboutRow(icon: "info.circle.fill", color: .purple, title: t("App Info", "Πληροφορίες εφαρμογής", "App-Informationen"))
                }
                .alert(t("App Info", "Πληροφορίες", "App-Info"), isPresented: $showAppInfo) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Picksy: Be Present\n\(t("Version", "Έκδοση", "Version")) \(appVersion) (\(t("Build", "Build", "Build")) \(buildNumber))\n\nFotios Pongas\nfotiospongas.dev")
                }
            }
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 0.5))
            )
        }
    }

    private func aboutRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(.white)
            }
            Text(title)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Family Controls

    private var familyControlsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(t("Screen Time access", "Πρόσβαση στο Screen Time", "Bildschirmzeit-Zugriff"))
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.primary)
                    if isAuthorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 13))
                    }
                }
                Text(isAuthorized
                     ? t("Tracking your selected apps", "Παρακολουθείς τις επιλεγμένες εφαρμογές", "Verfolgt deine ausgewählten Apps")
                     : t("Enable for accurate app tracking", "Ενεργοποίηση για ακριβή μέτρηση", "Für genaue App-Verfolgung aktivieren"))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isAuthorized {
                Text(t("Enabled", "Ενεργό", "Aktiv"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.green)
            } else {
                Button(action: { requestFamilyControls() }) {
                    Text(t("Enable", "Ενεργοποίηση", "Aktivieren"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.purple))
                }
            }
        }
        .padding(.vertical, 16)
    }

    private var sharedAppsRow: some View {
        Button(action: { showSharedAppsPicker = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(t("Apps I share with opponents", "Εφαρμογές που μοιράζομαι", "Apps für Gegner"))
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.primary)
                        Text("⚔️").font(.system(size: 13))
                    }
                    let count = SharedAppsManager.shared.mySelectedApps.count
                    Text(count == 0
                         ? t("Not set — opponents can't see your apps", "Δεν έχεις επιλέξει — οι αντίπαλοι δεν βλέπουν τίποτα", "Nicht gesetzt")
                         : t("\(count) apps selected", "\(count) εφαρμογές επιλεγμένες", "\(count) Apps ausgewählt"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
        }
        .sheet(isPresented: $showSharedAppsPicker) {
            SharedAppsPickerView()
        }
    }

    private var trackedAppsRow: some View {
        Button(action: { openAppPicker() }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(t("Tracked apps", "Παρακολουθούμενες εφαρμογές", "Verfolgte Apps"))
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.primary)
                        Text("📱").font(.system(size: 13))
                    }
                    Text(trackedAppsSubtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
        }
        .disabled(!isAuthorized)
        .opacity(isAuthorized ? 1.0 : 0.5)
    }

    private func requestFamilyControls() {
        Task {
            let granted = await FamilyControlsManager.shared.requestAuthorization()
            await MainActor.run { isAuthorized = granted }
        }
    }

    private func openAppPicker() {
        guard isAuthorized else { return }
        showAppPicker = true
    }

    private func requestAndScheduleNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { scheduleNotifications() }
        }
    }

    /// This used to schedule its OWN generic (non-personalized) "liftoff.midday"/
    /// "liftoff.evening" requests, which — since both share an identifier with
    /// LiftOffApp.rescheduleTimeBasedNotifications — would silently overwrite
    /// the personalized evening notification with generic copy every time the
    /// user toggled notifications on here, and would re-add the retired midday
    /// one. Delegating to the same shared function keeps a single source of
    /// truth for what's actually scheduled.
    private func scheduleNotifications() {
        LiftOffApp.rescheduleTimeBasedNotifications(pickupCount: store.todayPickups)
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, design: .rounded))
                Text(subtitle).font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
            }
            Spacer()
            content()
        }
        .padding(.vertical, 16)
    }
}

#Preview {
    SettingsView()
        .environment(ProManager.shared)
        .environment(LiveActivityManager())
        .environment(DataStore())
        .environment(WeatherManager())
        .environment(ActivityPreferences())
}

