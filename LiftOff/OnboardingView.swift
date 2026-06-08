//
//  OnboardingView.swift
//  Picksy
//
//  Created by Fotios Pongas on 09.04.26.

import SwiftUI
import UserNotifications
import FamilyControls

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @Environment(ActivityPreferences.self) var activityPrefs
    @State private var currentPage: Int = 0
    @State private var familyControlsRequested: Bool = false
    @State private var showAppPicker: Bool = false
    @State private var pickerSelection: FamilyActivitySelection = FamilyActivitySelection()

    private let totalPages = 7 // 0:lang, 1:what, 2:how, 3:family-controls, 4:choose-apps, 5:preferences, 6:notifications

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    /// Computed property που χρησιμοποιεί το τοπικό state για να γίνεται refresh
    private var selectedAppsCount: Int {
        pickerSelection.applicationTokens.count + pickerSelection.categoryTokens.count
    }

    private var hasSelectedApps: Bool {
        !pickerSelection.applicationTokens.isEmpty || !pickerSelection.categoryTokens.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {

            // Back button
            HStack {
                if currentPage > 0 {
                    Button(action: { withAnimation { currentPage -= 1 } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                            Text(t("Back", "Πίσω", "Zurück"))
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                        }
                        .foregroundColor(.blue)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .frame(height: 44)

            TabView(selection: $currentPage) {

                // Page 0: Language
                languagePage.tag(0)

                // Page 1: What is Picksy
                OnboardingPage(
                    icon: "hand.raised.fill",
                    iconColor: .blue,
                    title: t("How often do you pick it up?", "Πόσες φορές το σηκώνεις;", "Wie oft greifst du hin?"),
                    description: t(
                        "Picksy counts every time you pick up your phone. No judgment — just awareness.",
                        "Το Picksy μετράει κάθε φορά που σηκώνεις το κινητό σου. Χωρίς κριτική — απλά συνειδητοποίηση.",
                        "Picksy zählt jedes Mal, wenn du dein Handy aufhebst. Kein Urteil — nur Bewusstsein."
                    ),
                    tag: 1
                )

                // Page 2: How it works
                OnboardingPage(
                    icon: "iphone.and.arrow.forward",
                    iconColor: .orange,
                    title: t("How it works", "Πώς λειτουργεί", "So funktioniert es"),
                    description: t(
                        "Picksy needs to stay open in the foreground to count your pickups.\n\nIf you send it to the background or close it, counting stops automatically.\n\nOpen it every morning and leave it running for accurate results.",
                        "Το Picksy χρειάζεται να είναι ανοιχτό στο προσκήνιο για να μετράει τα σηκώματα.\n\nΑν το στείλεις στο παρασκήνιο ή το κλείσεις εντελώς, η μέτρηση σταματάει αυτόματα.\n\nΆνοιξέ το κάθε πρωί και άφησέ το ανοιχτό για ακριβή αποτελέσματα.",
                        "Picksy muss im Vordergrund geöffnet bleiben, um deine Griffe zu zählen.\n\nWenn du es in den Hintergrund schickst oder schließt, stoppt die Zählung automatisch.\n\nÖffne es jeden Morgen und lass es laufen für genaue Ergebnisse."
                    ),
                    tag: 2
                )

                // Page 3: Family Controls
                familyControlsPage.tag(3)

                // Page 4: Choose Apps (NEW!)
                chooseAppsPage.tag(4)

                // Page 5: Activity preferences
                preferencesPage.tag(5)

                // Page 6: Notifications
                OnboardingPage(
                    icon: "bell.badge.fill",
                    iconColor: .green,
                    title: t("Stay informed", "Μείνε ενημερωμένος", "Bleib informiert"),
                    description: t(
                        "Picksy sends a midday notification with your progress and an evening one with your daily results.\n\nTap \"Get started!\" to enable notifications.",
                        "Το Picksy στέλνει μια ειδοποίηση στο μεσημέρι με την πρόοδό σου και μια το βράδυ με τα αποτελέσματα της ημέρας.\n\nΠάτα \"Ξεκίνα!\" για να ενεργοποιήσεις τις ειδοποιήσεις.",
                        "Picksy sendet eine Mittagsbenachrichtigung mit deinem Fortschritt und eine abendliche mit deinen Tagesergebnissen.\n\nTippe auf \"Los geht's!\", um Benachrichtigungen zu aktivieren."
                    ),
                    tag: 6
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            // Bottom buttons
            VStack(spacing: 12) {
                if currentPage == 0 {
                    Text(t("Tap to select", "Πάτα για να επιλέξεις", "Tippe zum Auswählen"))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 16)
                } else if currentPage < totalPages - 1 {
                    Button(action: { withAnimation { currentPage += 1 } }) {
                        Text(t("Continue", "Συνέχεια", "Weiter"))
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
                    }

                    Button(action: { hasSeenOnboarding = true }) {
                        Text(t("Skip", "Παράλειψη", "Überspringen"))
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button(action: { requestNotificationsAndFinish() }) {
                        Text(t("Get started!", "Ξεκίνα!", "Los geht's!"))
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.green))
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .padding(.top, 8)
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $pickerSelection)
        .onAppear {
            // Φόρτωσε την υπάρχουσα selection στο τοπικό state
            pickerSelection = AppSelectionStore.shared.selection
        }
        .onChange(of: pickerSelection) { _, newValue in
            // Save selection όταν αλλάζει
            AppSelectionStore.shared.selection = newValue
        }
    }

    // MARK: - Language Page

    private var languagePage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle().fill(Color.blue.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: "globe").font(.system(size: 44)).foregroundColor(.blue)
            }

            VStack(spacing: 8) {
                Text("Choose your language")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                Text("Επίλεξε τη γλώσσα σου")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                Text("Wähle deine Sprache")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                languageButton(code: "English", label: "English", badge: "EN")
                languageButton(code: "Ελληνικά", label: "Ελληνικά", badge: "ΕΛ")
                languageButton(code: "Deutsch", label: "Deutsch", badge: "DE")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func languageButton(code: String, label: String, badge: String) -> some View {
        Button(action: {
            appLanguage = code
            withAnimation { currentPage = 1 }
        }) {
            HStack(spacing: 16) {
                Text(badge)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.blue))

                Text(label)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                if appLanguage == code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(appLanguage == code ? Color.blue.opacity(0.08) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(appLanguage == code ? Color.blue : Color.clear, lineWidth: 1.5)
                    )
            )
        }
    }

    // MARK: - Family Controls Page

    private var familyControlsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle().fill(Color.purple.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 44))
                    .foregroundColor(.purple)
            }

            VStack(spacing: 12) {
                Text(t(
                    "Accurate tracking",
                    "Ακριβής μέτρηση",
                    "Genaue Verfolgung"
                ))
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                Text(t(
                    "For the most accurate tracking, Picksy can use Apple's Screen Time data.\n\nThis lets us track time spent in your selected apps — even when Picksy is in the background.\n\nYour data stays private and on your device.",
                    "Για την πιο ακριβή μέτρηση, το Picksy μπορεί να χρησιμοποιήσει τα δεδομένα Screen Time της Apple.\n\nΈτσι μπορούμε να μετράμε τον χρόνο που ξοδεύεις στις επιλεγμένες εφαρμογές — ακόμα και όταν το Picksy είναι στο παρασκήνιο.\n\nΤα δεδομένα σου παραμένουν ιδιωτικά και στη συσκευή σου.",
                    "Für die genaueste Verfolgung kann Picksy die Bildschirmzeit-Daten von Apple verwenden.\n\nSo können wir die Zeit verfolgen, die du in deinen ausgewählten Apps verbringst — auch wenn Picksy im Hintergrund ist.\n\nDeine Daten bleiben privat und auf deinem Gerät."
                ))
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 32)
            }

            // Status badge if already authorized
            if FamilyControlsManager.shared.isAuthorized {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(t("Enabled", "Ενεργοποιημένο", "Aktiviert"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.green.opacity(0.1)))
            } else {
                Button(action: { requestFamilyControls() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill").font(.system(size: 14))
                        Text(t(
                            "Enable accurate tracking",
                            "Ενεργοποίηση ακριβούς μέτρησης",
                            "Genaue Verfolgung aktivieren"
                        ))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple))
                }
            }

            Text(t(
                "Optional — you can skip and enable it later in Settings.",
                "Προαιρετικό — μπορείς να το παραλείψεις και να το ενεργοποιήσεις αργότερα στις Ρυθμίσεις.",
                "Optional — du kannst es überspringen und später in den Einstellungen aktivieren."
            ))
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            Spacer()
        }
        .tag(3)
    }

    private func requestFamilyControls() {
        Task {
            let granted = await FamilyControlsManager.shared.requestAuthorization()
            await MainActor.run {
                familyControlsRequested = true
                if granted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation { currentPage = 4 }
                    }
                }
            }
        }
    }

    // MARK: - Choose Apps Page

    private var chooseAppsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle().fill(Color.indigo.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: "apps.iphone")
                    .font(.system(size: 44))
                    .foregroundColor(.indigo)
            }

            VStack(spacing: 12) {
                Text(t(
                    "Choose your apps",
                    "Επίλεξε τις εφαρμογές σου",
                    "Wähle deine Apps"
                ))
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                Text(t(
                    "Select the apps you want Picksy to track. We recommend the whole Social & Entertainment categories — that's where most time goes.\n\nYou can change this anytime in Settings.",
                    "Επίλεξε τις εφαρμογές που θέλεις να παρακολουθεί το Picksy. Σου προτείνουμε ολόκληρες τις κατηγορίες Social & Entertainment — εκεί πάει ο περισσότερος χρόνος.\n\nΜπορείς να το αλλάξεις οποτεδήποτε στις Ρυθμίσεις.",
                    "Wähle die Apps aus, die Picksy verfolgen soll. Wir empfehlen die ganzen Kategorien Social & Entertainment — dort geht die meiste Zeit hin.\n\nDu kannst dies jederzeit in den Einstellungen ändern."
                ))
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 32)
            }

            // Duel-fairness tip: screen-time duels compare time on the SAME
            // categories, so picking the same ones as friends keeps it fair.
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                Text(t(
                    "For fair duels, pick the same categories as your friends — duels compare your screen time on these apps.",
                    "Για δίκαιες μονομαχίες, διάλεξε τις ίδιες κατηγορίες με τους φίλους σου — η μονομαχία συγκρίνει τον χρόνο οθόνης σε αυτές τις apps.",
                    "Für faire Duelle wähle dieselben Kategorien wie deine Freunde — Duelle vergleichen deine Bildschirmzeit in diesen Apps."
                ))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.08)))
            .padding(.horizontal, 28)

            // Accuracy disclaimer + Accurate Mode hint.
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 14))
                    .foregroundColor(.indigo)
                Text(t(
                    "Pick the apps that eat your time, or pickups won't be reliable. For exact counts, turn on \"Exact pickup counting\" in Settings later.",
                    "Διάλεξε τις apps που σου τρώνε χρόνο, αλλιώς τα σηκώματα δεν θα είναι αξιόπιστα. Για ακριβή μέτρηση, ενεργοποίησε αργότερα το «Ακριβής μέτρηση σηκωμάτων» στις Ρυθμίσεις.",
                    "Wähle die Apps, die deine Zeit fressen, sonst sind die Griffe nicht zuverlässig. Für exakte Zählung aktiviere später \"Exakte Griff-Zählung\" in den Einstellungen."
                ))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.indigo.opacity(0.08)))
            .padding(.horizontal, 28)

            // Selected apps badge — χρησιμοποιεί το τοπικό state
            if hasSelectedApps {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(t(
                        "\(selectedAppsCount) selected",
                        "\(selectedAppsCount) επιλέχθηκαν",
                        "\(selectedAppsCount) ausgewählt"
                    ))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.green.opacity(0.1)))
            }

            Button(action: { openAppPicker() }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 14))
                    Text(hasSelectedApps
                         ? t("Edit selection", "Επεξεργασία επιλογής", "Auswahl bearbeiten")
                         : t("Choose apps", "Επιλογή εφαρμογών", "Apps auswählen"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.indigo))
            }

            Text(t(
                "Optional — you can skip this step.",
                "Προαιρετικό — μπορείς να παραλείψεις αυτό το βήμα.",
                "Optional — du kannst diesen Schritt überspringen."
            ))
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            Spacer()
        }
        .tag(4)
    }

    private func openAppPicker() {
        // Αν δεν έχει εκριθεί Family Controls, ζητάμε πρώτα
        if !FamilyControlsManager.shared.isAuthorized {
            Task {
                let granted = await FamilyControlsManager.shared.requestAuthorization()
                if granted {
                    await MainActor.run {
                        showAppPicker = true
                    }
                }
            }
        } else {
            showAppPicker = true
        }
    }

    // MARK: - Preferences Page

    private var preferencesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.purple.opacity(0.12)).frame(width: 60, height: 60)
                        Image(systemName: "sparkles").font(.system(size: 26)).foregroundColor(.purple)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("What do you enjoy?", "Τι σου αρέσει;", "Was magst du?"))
                            .font(.system(size: 22, weight: .medium, design: .rounded))

                        Text(t(
                            "Personalize your suggestions",
                            "Προσάρμοσε τις προτάσεις σου",
                            "Personalisiere deine Vorschläge"
                        ))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)

                // Main content
                ActivityPreferencesView(showPrivacyBadge: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .tag(5)
    }

    private func requestNotificationsAndFinish() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async { hasSeenOnboarding = true }
        }
    }
}

// MARK: - Onboarding Page

struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let tag: Int

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle().fill(iconColor.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: icon).font(.system(size: 44)).foregroundColor(iconColor)
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(description)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .tag(tag)
    }
}

#Preview {
    OnboardingView()
        .environment(ActivityPreferences())
}

