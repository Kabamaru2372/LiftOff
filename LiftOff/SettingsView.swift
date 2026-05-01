// SettingsView.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026

import SwiftUI
import UserNotifications
import StoreKit
import FamilyControls

struct SettingsView: View {
    @AppStorage("dailyGoal") private var dailyGoal: Int = 15
    @AppStorage("showTimer") private var showTimer: Bool = true
    @AppStorage("quietStart") private var quietStart: Int = 22
    @AppStorage("quietEnd") private var quietEnd: Int = 7
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled: Bool = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

    @Environment(ProManager.self) var proManager
    @Environment(LiveActivityManager.self) var liveActivity
    @Environment(DataStore.self) var store
    @Environment(WeatherManager.self) var weatherManager
    @Environment(ActivityPreferences.self) var activityPrefs

    @State private var showPaywall: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var showAppInfo: Bool = false
    @State private var showCityPicker: Bool = false
    @State private var showCityError: Bool = false
    @State private var showActivityPrefs: Bool = false

    // Family Controls / App Selection state
    @State private var showAppPicker: Bool = false
    @State private var pickerSelection: FamilyActivitySelection = FamilyActivitySelection()
    @State private var isAuthorized: Bool = false

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.4"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "12"
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

        if count == 0 {
            return t("All categories active", "Όλες οι κατηγορίες ενεργές", "Alle Kategorien aktiv")
        } else if count == total {
            return t("All categories active", "Όλες οι κατηγορίες ενεργές", "Alle Kategorien aktiv")
        } else {
            return t(
                "\(count) of \(total) categories",
                "\(count) από \(total) κατηγορίες",
                "\(count) von \(total) Kategorien"
            )
        }
    }

    /// Subtitle για το tracked apps section
    private var trackedAppsSubtitle: String {
        let appsCount = pickerSelection.applicationTokens.count
        let categoriesCount = pickerSelection.categoryTokens.count

        if appsCount == 0 && categoriesCount == 0 {
            return t("Tap to choose apps", "Πάτα για να επιλέξεις εφαρμογές", "Tippe, um Apps auszuwählen")
        }

        var parts: [String] = []
        if appsCount > 0 {
            parts.append(t(
                "\(appsCount) apps",
                "\(appsCount) εφαρμογές",
                "\(appsCount) Apps"
            ))
        }
        if categoriesCount > 0 {
            parts.append(t(
                "\(categoriesCount) categories",
                "\(categoriesCount) κατηγορίες",
                "\(categoriesCount) Kategorien"
            ))
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text(t("Settings", "Ρυθμίσεις", "Einstellungen"))
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                // Picksy Pro status
                if proManager.isPro {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                        Text("Picksy Pro").font(.system(size: 15, weight: .medium, design: .rounded))
                        Spacer()
                        Text(t("Active", "Ενεργό", "Aktiv"))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
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
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
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

                // Daily goal — αυξάνουμε το max σε 200
                SettingRow(
                    title: t("Daily goal", "Ημερήσιος στόχος", "Tagesziel"),
                    subtitle: t("Max pickups per day", "Μέγιστα pickups ανά μέρα", "Maximale Griffe pro Tag")
                ) {
                    Stepper("\(dailyGoal)", value: $dailyGoal, in: 5...200, step: 5)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }

                Divider()

                SettingRow(
                    title: t("Timer visible", "Χρονόμετρο", "Timer anzeigen"),
                    subtitle: t("Show live counter on nudge", "Δείξε live μετρητή", "Live-Zähler beim Nudge anzeigen")
                ) {
                    Toggle("", isOn: $showTimer).labelsHidden()
                }

                Divider()

                SettingRow(
                    title: "Live Activity",
                    subtitle: t("Show pickups on Lock Screen", "Δείξε pickups στο Lock Screen", "Griffe auf dem Sperrbildschirm anzeigen")
                ) {
                    Toggle("", isOn: Binding(
                        get: { liveActivityEnabled },
                        set: { newValue in
                            liveActivityEnabled = newValue
                            if newValue {
                                let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
                                liveActivity.start(pickupCount: store.todayPickups, dailyGoal: goal > 0 ? goal : 15)
                            } else {
                                liveActivity.stopAll()
                            }
                        }
                    )).labelsHidden()
                }

                Divider()

                SettingRow(
                    title: t("Notifications", "Ειδοποιήσεις", "Benachrichtigungen"),
                    subtitle: t("Midday and evening check-in", "Μεσημεριανή και βραδινή ενημέρωση", "Mittags- und Abend-Erinnerung")
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

                // MARK: - Weather City
                weatherSection

                Divider()

                // MARK: - Activity Preferences
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
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                }

                Divider()

                // MARK: - Accurate Tracking Header
                Text(t("Accurate tracking", "Ακριβής μέτρηση", "Genaue Verfolgung"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 24)
                    .padding(.bottom, 4)

                // MARK: - Family Controls Toggle
                familyControlsRow

                Divider()

                // MARK: - Tracked Apps
                trackedAppsRow

                Divider()

                // MARK: - Reset Stats
                Button(action: { showResetConfirm = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("Reset all stats", "Επαναφορά στατιστικών", "Alle Statistiken zurücksetzen"))
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.red)
                            Text(t("Permanently deletes all your data", "Διαγράφει όλα τα δεδομένα σου", "Löscht alle deine Daten dauerhaft"))
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "trash").font(.system(size: 14)).foregroundColor(.red)
                    }
                    .padding(.vertical, 16)
                }
                .alert(
                    t("Reset all stats?", "Επαναφορά στατιστικών;", "Alle Statistiken zurücksetzen?"),
                    isPresented: $showResetConfirm
                ) {
                    Button(t("Yes, delete everything", "Ναι, διέγραψε τα πάντα", "Ja, alles löschen"),
                           role: .destructive) { store.resetAllStats() }
                    Button(t("Cancel", "Ακύρωση", "Abbrechen"), role: .cancel) {}
                } message: {
                    Text(t(
                        "This cannot be undone. All your pickups, streak, and history will be permanently lost.",
                        "Αυτή η ενέργεια δεν μπορεί να αναιρεθεί. Θα χαθούν όλα τα pickups, το streak και το ιστορικό σου.",
                        "Dies kann nicht rückgängig gemacht werden. Alle Griffe, Serien und Verlauf werden dauerhaft gelöscht."
                    ))
                }

                // MARK: - About
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("About", "Σχετικά", "Über"))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.top, 28)

                    Text(t(
                        "Picksy helps you build awareness of your phone habits. No judgment, no shaming — just a gentle reminder to be intentional.",
                        "Το Picksy σε βοηθάει να συνειδητοποιείς τις συνήθειές σου με το κινητό. Χωρίς κριτική — απλά μια ήρεμη υπενθύμιση να είσαι πιο συνειδητός.",
                        "Picksy hilft dir, deine Handygewohnheiten zu erkennen. Kein Urteil — nur eine sanfte Erinnerung, bewusster zu sein."
                    ))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)

                    Text("v\(appVersion) — " + t("Made with care by", "Φτιαγμένο με μεράκι από", "Mit Sorgfalt entwickelt von") + " Fotios Pongas")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    VStack(spacing: 0) {
                        Link(destination: URL(string: "https://fotiospongas.dev")!) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(Color.blue).frame(width: 32, height: 32)
                                    Image(systemName: "globe").font(.system(size: 15)).foregroundColor(.white)
                                }
                                Text(t("Website", "Ιστότοπος", "Webseite"))
                                    .font(.system(size: 15, weight: .regular, design: .rounded)).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                        }

                        Divider().padding(.leading, 44)

                        Link(destination: URL(string: "https://fotiospongas.dev/privacy-policy")!) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(Color.gray).frame(width: 32, height: 32)
                                    Image(systemName: "lock.shield.fill").font(.system(size: 15)).foregroundColor(.white)
                                }
                                Text(t("Privacy Policy", "Πολιτική Απορρήτου", "Datenschutzrichtlinie"))
                                    .font(.system(size: 15, weight: .regular, design: .rounded)).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                        }

                        Divider().padding(.leading, 44)

                        Link(destination: URL(string: "https://apps.apple.com/app/picksy-be-present/id6761116771?action=write-review")!) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(Color.orange).frame(width: 32, height: 32)
                                    Image(systemName: "star.fill").font(.system(size: 15)).foregroundColor(.white)
                                }
                                Text(t("Rate Picksy", "Αξιολόγησε το Picksy", "Picksy bewerten"))
                                    .font(.system(size: 15, weight: .regular, design: .rounded)).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                        }

                        Divider().padding(.leading, 44)

                        Button(action: { showAppInfo = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(Color.purple).frame(width: 32, height: 32)
                                    Image(systemName: "info.circle.fill").font(.system(size: 15)).foregroundColor(.white)
                                }
                                Text(t("App Info", "Πληροφορίες εφαρμογής", "App-Informationen"))
                                    .font(.system(size: 15, weight: .regular, design: .rounded)).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                        }
                        .alert(
                            t("App Info", "Πληροφορίες", "App-Info"),
                            isPresented: $showAppInfo
                        ) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text("""
                            Picksy: Be Present
                            \(t("Version", "Έκδοση", "Version")) \(appVersion) (\(t("Build", "Build", "Build")) \(buildNumber))

                            \(t("Developed by", "Ανάπτυξη", "Entwickelt von")) Fotios Pongas
                            fotiospongas.dev

                            \(t("Your data stays strictly on your device.", "Τα δεδομένα σου παραμένουν αποκλειστικά στη συσκευή σου.", "Deine Daten bleiben ausschließlich auf deinem Gerät."))
                            """)
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemBackground))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 0.5))
                    )
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView().environment(proManager)
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerSheet { city in
                Task { await weatherManager.selectCity(city) }
            }
        }
        .sheet(isPresented: $showActivityPrefs) {
            ActivityPreferencesSheet()
                .environment(activityPrefs)
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $pickerSelection)
        .onAppear {
            // Φόρτωσε state
            isAuthorized = FamilyControlsManager.shared.isAuthorized
            pickerSelection = AppSelectionStore.shared.selection
        }
        .onChange(of: pickerSelection) { _, newValue in
            AppSelectionStore.shared.selection = newValue
        }
        .alert(
            t("Could not get weather", "Αδυναμία λήψης καιρού", "Wetter konnte nicht geladen werden"),
            isPresented: $showCityError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(weatherManager.errorMessage ?? "")
        }
    }

    // MARK: - Family Controls Row

    private var familyControlsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(t("Screen Time access", "Πρόσβαση στο Screen Time", "Bildschirmzeit-Zugriff"))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
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
                    .font(.system(size: 12, weight: .regular, design: .rounded))
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

    // MARK: - Tracked Apps Row

    private var trackedAppsRow: some View {
        Button(action: { openAppPicker() }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(t("Tracked apps", "Παρακολουθούμενες εφαρμογές", "Verfolgte Apps"))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                        Text("📱").font(.system(size: 13))
                    }

                    Text(trackedAppsSubtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
        }
        .disabled(!isAuthorized)
        .opacity(isAuthorized ? 1.0 : 0.5)
    }

    // MARK: - Family Controls Actions

    private func requestFamilyControls() {
        Task {
            let granted = await FamilyControlsManager.shared.requestAuthorization()
            await MainActor.run {
                isAuthorized = granted
            }
        }
    }

    private func openAppPicker() {
        guard isAuthorized else { return }
        showAppPicker = true
    }

    // MARK: - Weather Section

    private var weatherSection: some View {
        Button(action: { showCityPicker = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(t("Weather city", "Πόλη καιρού", "Wetter-Stadt"))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)

                        if let weather = weatherManager.currentWeather {
                            Text(weather.condition.emoji)
                                .font(.system(size: 14))
                            Text("\(Int(weather.temperature))°C")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let city = weatherManager.savedCity {
                        HStack(spacing: 4) {
                            Text(city.countryFlag).font(.system(size: 12))
                            Text(city.localizedName(language: appLanguage))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    } else {
                        Text(t(
                            "Tap to choose your city",
                            "Πάτα για να επιλέξεις πόλη",
                            "Tippe, um deine Stadt zu wählen"
                        ))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    }
                }
                Spacer()

                if weatherManager.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 16)
        }
        .onChange(of: weatherManager.errorMessage) { _, newValue in
            if newValue != nil { showCityError = true }
        }
    }

    private func requestAndScheduleNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { scheduleNotifications() }
        }
    }

    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["liftoff.midday", "liftoff.evening"])

        let middayContent = UNMutableNotificationContent()
        middayContent.title = t("How's it going so far?", "Πώς πας μέχρι τώρα;", "Wie läuft es bisher?")
        middayContent.body = t("Check your stats on Picksy.", "Κοίτα τα στατιστικά σου στο Picksy.", "Schau dir deine Statistiken in Picksy an.")
        middayContent.sound = .default
        var midday = DateComponents(); midday.hour = 12; midday.minute = 0
        center.add(UNNotificationRequest(identifier: "liftoff.midday", content: middayContent,
            trigger: UNCalendarNotificationTrigger(dateMatching: midday, repeats: true)))

        let eveningContent = UNMutableNotificationContent()
        eveningContent.title = t("Your phone day in review", "Η μέρα σου με το κινητό", "Dein Handy-Tag im Rückblick")
        eveningContent.body = t("Open Picksy to see how you did today.", "Άνοιξε το Picksy για να δεις πώς πήγες σήμερα.", "Öffne Picksy, um zu sehen, wie dein Tag war.")
        eveningContent.sound = .default
        var evening = DateComponents(); evening.hour = 21; evening.minute = 0
        center.add(UNNotificationRequest(identifier: "liftoff.evening", content: eveningContent,
            trigger: UNCalendarNotificationTrigger(dateMatching: evening, repeats: true)))
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .regular, design: .rounded))
                Text(subtitle).font(.system(size: 12, weight: .regular, design: .rounded)).foregroundColor(.secondary)
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

