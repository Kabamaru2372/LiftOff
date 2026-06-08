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

    // 0:lang, 1:setup-choice, 2:what, 3:how, 4:family-controls, 5:choose-apps,
    // 6:preferences, 7:notifications, 8:next-steps (tips)
    private let totalPages = 9
    /// Guided "Quick setup" flow. Each step shows a short explanation BEFORE the
    /// system prompt, so the user knows why they're approving / what to pick.
    enum QuickStep: Hashable { case screenTime, chooseApps }
    @State private var quickStep: QuickStep? = nil

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

                // Page 1: Setup choice (Quick vs Customize)
                setupChoicePage.tag(1)

                // Page 2: What is Picksy
                OnboardingPage(
                    icon: "hand.raised.fill",
                    iconColor: .blue,
                    title: t("Use your phone less. For real.", "Λιγότερο κινητό. Στ' αλήθεια.", "Weniger Handy. Wirklich."),
                    description: t(
                        "You've watched your screen time climb. Picksy actually helps you bring it down — no guilt, and a bit of fun.",
                        "Έχεις δει τον χρόνο σου να ανεβαίνει. Το Picksy σε βοηθάει να τον ρίξεις — χωρίς ενοχές, με λίγη πλάκα.",
                        "Du hast deine Bildschirmzeit steigen sehen. Picksy hilft dir wirklich, sie zu senken — ohne Schuldgefühle, mit etwas Spaß."
                    ),
                    tag: 2
                )

                // Page 3: How it works
                OnboardingPage(
                    icon: "target",
                    iconColor: .orange,
                    title: t("How it works", "Πώς λειτουργεί", "So funktioniert es"),
                    description: t(
                        "1. Pick the apps that eat your time.\n2. Set a daily limit — Picksy locks them when you reach it.\n3. Duel friends to see who's on their phone less.\n\nSimple as that.",
                        "1. Διάλεξε τις apps που σου τρώνε χρόνο.\n2. Βάλε ημερήσιο όριο — το Picksy τις κλειδώνει όταν το φτάσεις.\n3. Μονομάχησε με φίλους για το ποιος είναι λιγότερο στο κινητό.\n\nΤόσο απλό.",
                        "1. Wähle die Apps, die deine Zeit fressen.\n2. Setze ein Tageslimit — Picksy sperrt sie, wenn du es erreichst.\n3. Duelliere Freunde, wer weniger am Handy ist.\n\nSo einfach."
                    ),
                    tag: 3
                )

                // Page 4: Family Controls
                familyControlsPage.tag(4)

                // Page 5: Choose Apps
                chooseAppsPage.tag(5)

                // Page 6: Activity preferences
                preferencesPage.tag(6)

                // Page 7: Notifications
                OnboardingPage(
                    icon: "bell.badge.fill",
                    iconColor: .green,
                    title: t("Gentle reminders", "Ευγενικές υπενθυμίσεις", "Sanfte Erinnerungen"),
                    description: t(
                        "Picksy sends a few friendly nudges and a daily summary, so you stay on track without thinking about it.\n\nTap \"Get started!\" to turn them on.",
                        "Το Picksy στέλνει λίγες φιλικές υπενθυμίσεις και μια ημερήσια σύνοψη, για να μένεις σε φόρμα χωρίς να το σκέφτεσαι.\n\nΠάτα \"Ξεκίνα!\" για να τις ενεργοποιήσεις.",
                        "Picksy sendet ein paar freundliche Anstöße und eine Tageszusammenfassung, damit du mühelos dranbleibst.\n\nTippe auf \"Los geht's!\", um sie zu aktivieren."
                    ),
                    tag: 7
                )

                // Page 8: Next steps (what else to do in Settings)
                nextStepsPage.tag(8)
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
                } else if currentPage == 1 {
                    // Setup-choice page has its own buttons; offer only Skip here.
                    Button(action: { hasSeenOnboarding = true }) {
                        Text(t("Skip", "Παράλειψη", "Überspringen"))
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
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

            // Guided Quick-setup overlay (explains each step before its prompt).
            if let step = quickStep {
                quickFlowOverlay(step)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: quickStep)
        .familyActivityPicker(isPresented: $showAppPicker, selection: $pickerSelection)
        .onAppear {
            // Φόρτωσε την υπάρχουσα selection στο τοπικό state
            pickerSelection = AppSelectionStore.shared.selection
        }
        .onChange(of: pickerSelection) { _, newValue in
            // Save selection όταν αλλάζει
            AppSelectionStore.shared.selection = newValue
        }
        .onChange(of: showAppPicker) { wasShowing, isShowing in
            // Quick setup: the app picker just closed → go to the final tips page.
            if quickStep == .chooseApps && wasShowing && !isShowing {
                quickStep = nil
                withAnimation { currentPage = 8 }   // tips / next-steps page
            }
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

    // MARK: - Setup Choice Page

    private var setupChoicePage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle().fill(Color.blue.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: "wand.and.stars").font(.system(size: 44)).foregroundColor(.blue)
            }

            VStack(spacing: 8) {
                Text(t("How do you want to start?", "Πώς θες να ξεκινήσεις;", "Wie möchtest du starten?"))
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(t("You can change everything later in Settings.",
                       "Μπορείς να τα αλλάξεις όλα αργότερα στις Ρυθμίσεις.",
                       "Du kannst alles später in den Einstellungen ändern."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 14) {
                Button(action: { runQuickSetup() }) {
                    choiceCard(
                        icon: "bolt.fill", color: .blue,
                        title: t("Quick setup", "Γρήγορο setup", "Schnell einrichten"),
                        subtitle: t("We set it up — just approve the prompts and pick your apps once.",
                                    "Τα ρυθμίζουμε εμείς — απλά ενέκρινε και διάλεξε apps μία φορά.",
                                    "Wir richten ein — bestätige und wähle einmal deine Apps.")
                    )
                }
                Button(action: { withAnimation { currentPage = 2 } }) {
                    choiceCard(
                        icon: "slider.horizontal.3", color: .secondary,
                        title: t("Customize", "Προσαρμογή", "Anpassen"),
                        subtitle: t("Go through each step yourself.",
                                    "Πέρνα από κάθε βήμα μόνος σου.",
                                    "Gehe jeden Schritt selbst durch.")
                    )
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
    }

    private func choiceCard(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 22)).foregroundColor(color).frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 13, design: .rounded)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
    }

    /// Starts the guided Quick setup at the first explained step.
    private func runQuickSetup() {
        quickStep = .screenTime
    }

    /// Full-screen explanation shown before each Quick-setup system prompt.
    @ViewBuilder
    private func quickFlowOverlay(_ step: QuickStep) -> some View {
        let icon: String; let color: Color; let title: String
        let bodyText: String; let buttonText: String; let action: () -> Void
        switch step {
        case .screenTime:
            icon = "lock.shield.fill"; color = .purple
            title = t("Allow Screen Time", "Άδεια Screen Time", "Bildschirmzeit erlauben")
            bodyText = t("Tap “Allow” on the next screen so Picksy can see how much time you spend on your apps.",
                         "Πάτα «Επιτρέπεται» στην επόμενη οθόνη ώστε το Picksy να ξέρει πόσο χρόνο ξοδεύεις στις apps σου.",
                         "Tippe als Nächstes auf „Erlauben“, damit Picksy sehen kann, wie viel Zeit du in deinen Apps verbringst.")
            buttonText = t("Continue", "Συνέχεια", "Weiter"); action = quickRequestScreenTime
        case .chooseApps:
            icon = "apps.iphone"; color = .indigo
            title = t("Choose your apps", "Διάλεξε τις apps σου", "Wähle deine Apps")
            bodyText = t("Pick the apps you want Picksy to track — the ones that eat your time (social, video, messaging).",
                         "Διάλεξε τις apps που θες να παρακολουθεί το Picksy — αυτές που σου τρώνε χρόνο (social, video, μηνύματα).",
                         "Wähle die Apps, die Picksy verfolgen soll — die, die deine Zeit fressen (Social, Video, Messaging).")
            buttonText = t("Choose apps", "Επιλογή εφαρμογών", "Apps wählen"); action = quickChooseApps
        }

        return ZStack {
            Color(.systemBackground)
            VStack(spacing: 26) {
                Spacer()
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 100, height: 100)
                    Image(systemName: icon).font(.system(size: 44)).foregroundColor(color)
                }
                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(bodyText)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 36)
                }
                HStack(spacing: 8) {
                    ForEach([QuickStep.screenTime, .chooseApps], id: \.self) { s in
                        Circle().fill(s == step ? color : color.opacity(0.2)).frame(width: 8, height: 8)
                    }
                }
                Spacer()
                Button(action: action) {
                    Text(buttonText)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(color))
                }
                .padding(.horizontal, 32)
                Button(action: { quickStep = nil }) {
                    Text(t("Cancel", "Άκυρο", "Abbrechen"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    // MARK: - Next Steps (final onboarding page)

    private var nextStepsPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer().frame(height: 16)

                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 88, height: 88)
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 38)).foregroundColor(.green)
                }

                VStack(spacing: 8) {
                    Text(t("You're almost set! 🎉", "Σχεδόν έτοιμος! 🎉", "Fast fertig! 🎉"))
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(t("A few optional extras — all in Settings — to get the most out of Picksy:",
                           "Λίγα προαιρετικά extra — όλα στις Ρυθμίσεις — για να αξιοποιήσεις πλήρως το Picksy:",
                           "Ein paar optionale Extras — alle in den Einstellungen — um Picksy voll zu nutzen:"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)
                }

                VStack(spacing: 10) {
                    tipRow("⏱️", t("Daily time limit", "Ημερήσιο όριο χρόνου", "Tageslimit"),
                           t("Lock apps after X minutes a day.", "Κλείδωσε apps μετά από Χ λεπτά την ημέρα.", "Sperre Apps nach X Minuten pro Tag."))
                    tipRow("🛡️", t("Exact pickup counting", "Ακριβής μέτρηση σηκωμάτων", "Exakte Griff-Zählung"),
                           t("A quick tap screen for precise counts.", "Μια γρήγορη οθόνη για ακριβή νούμερα.", "Ein kurzer Tipp-Screen für genaue Zahlen."))
                    tipRow("👨‍👩‍👧", t("Parent passcode", "Γονικός κωδικός", "Eltern-Code"),
                           t("Hand the phone to your kid, locked to a set time.", "Δώσε το κινητό στο παιδί, κλειδωμένο για συγκεκριμένο χρόνο.", "Gib dem Kind das Handy, auf eine feste Zeit gesperrt."))
                    tipRow("⚔️", t("Duel your friends", "Μονομαχίες με φίλους", "Freunde duellieren"),
                           t("Less screen time than them wins — from the Friends tab.", "Λιγότερος χρόνος από αυτούς νικάει — από το tab Φίλοι.", "Weniger Bildschirmzeit gewinnt — im Freunde-Tab."))
                }
                .padding(.horizontal, 24)

                Text(t("Tap “Get started!” — we'll ask for notification permission.",
                       "Πάτα «Ξεκίνα!» — θα ζητήσουμε άδεια για ειδοποιήσεις.",
                       "Tippe „Los geht's!“ — wir fragen nach Mitteilungserlaubnis."))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .padding(.top, 2)

                Spacer(minLength: 16)
            }
            .padding(.bottom, 16)
        }
        .tag(8)
    }

    private func tipRow(_ emoji: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.system(size: 20)).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.system(size: 13, design: .rounded)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    /// Step 1 action: request Screen Time permission, then move to the app step.
    /// If denied, jump straight to the final tips page (apps can be picked later).
    private func quickRequestScreenTime() {
        Task {
            let granted = await FamilyControlsManager.shared.requestAuthorization()
            await MainActor.run {
                FamilyControlsManager.shared.isAuthorized = granted
                if granted {
                    quickStep = .chooseApps
                } else {
                    quickStep = nil
                    withAnimation { currentPage = 8 }   // tips / next-steps page
                }
            }
        }
    }

    /// Step 2 action: open the system app picker. The showAppPicker onChange
    /// sends the user to the final tips page once it closes.
    private func quickChooseApps() {
        showAppPicker = true
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
                    "To measure your screen time and lock apps, Picksy needs Screen Time permission.\n\nIt keeps working even when Picksy is closed — and your data stays private, on your device.",
                    "Για να μετράει τον χρόνο σου και να κλειδώνει apps, το Picksy χρειάζεται άδεια Screen Time.\n\nΛειτουργεί ακόμα κι όταν το Picksy είναι κλειστό — και τα δεδομένα σου μένουν ιδιωτικά, στη συσκευή σου.",
                    "Um deine Bildschirmzeit zu messen und Apps zu sperren, braucht Picksy die Bildschirmzeit-Berechtigung.\n\nEs funktioniert auch wenn Picksy geschlossen ist — und deine Daten bleiben privat, auf deinem Gerät."
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
        .tag(4)
    }

    private func requestFamilyControls() {
        Task {
            let granted = await FamilyControlsManager.shared.requestAuthorization()
            await MainActor.run {
                familyControlsRequested = true
                if granted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation { currentPage = 5 }
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

            // Parental hint: time limit + passcode live in Settings; for a full
            // lock, disable app deletion in iOS Settings.
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "figure.and.child.holdinghands")
                    .font(.system(size: 14))
                    .foregroundColor(.pink)
                Text(t(
                    "Parents: set a daily time limit + passcode in Settings. For a full lock, also turn off app deletion in iOS Settings → Screen Time.",
                    "Γονείς: ορίστε ημερήσιο όριο + κωδικό στις Ρυθμίσεις. Για πλήρες κλείδωμα, απενεργοποιήστε και τη διαγραφή εφαρμογών στις Ρυθμίσεις iOS → Χρόνος επί οθόνης.",
                    "Eltern: Tageslimit + Code in den Einstellungen festlegen. Für volle Sperre auch App-Löschung in iOS → Bildschirmzeit deaktivieren."
                ))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.pink.opacity(0.07)))
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
        .tag(5)
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
        .tag(6)
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
                    .fixedSize(horizontal: false, vertical: true)
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

