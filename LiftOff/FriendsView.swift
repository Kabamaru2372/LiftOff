// FriendsView.swift
// Picksy
//
// Dedicated Friends tab — shows connected friends, active duel status,
// messaging, and duel invites all in one place.

import SwiftUI
import Combine
import CoreMotion

// MARK: - Duel banner liquid fill

/// Παρακολουθεί το roll της συσκευής ώστε η «επιφάνεια» του γεμίσματος στο duel
/// banner να γέρνει σαν υγρό όταν γέρνει το κινητό. Low-pass φιλτραρισμένο για
/// ομαλή κίνηση· clamped ώστε το γέμισμα να μη φεύγει ποτέ από τη θέση του.
@Observable
final class DuelMotionTilt {
    private let motion = CMMotionManager()
    var rollDegrees: Double = 0

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let roll = data?.attitude.roll else { return }
            let deg = max(-14.0, min(14.0, roll * 180 / .pi))
            // Low-pass: το υγρό «κυλάει» αντί να τρέμει με κάθε μικροκίνηση
            self.rollDegrees = self.rollDegrees * 0.85 + deg * 0.15
        }
    }

    func stop() { motion.stopDeviceMotionUpdates() }
}

/// Το γέμισμα της μπάρας με κεκλιμένο μέτωπο — η κλίση (slant) ακολουθεί το
/// roll της συσκευής ώστε η επιφάνεια να συμπεριφέρεται σαν στάθμη υγρού.
private struct LiquidFillShape: Shape {
    var progress: CGFloat   // 0…1 — πόσο γεμάτη είναι η μπάρα
    var slant: CGFloat      // οριζόντια απόκλιση (pt) πάνω/κάτω άκρης του μετώπου

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, slant) }
        set { progress = newValue.first; slant = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let x = rect.width * progress
        // Κράτα το μέτωπο μέσα στα όρια ώστε το slant να μην «ξεχειλίζει»
        let top    = min(max(x + slant, 0), rect.width)
        let bottom = min(max(x - slant, 0), rect.width)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: top, y: 0))
        p.addLine(to: CGPoint(x: bottom, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

/// Η φωτεινή ακμή στο μέτωπο του γεμίσματος — ίδια γεωμετρία με το LiquidFillShape.
private struct LiquidEdgeShape: Shape {
    var progress: CGFloat
    var slant: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, slant) }
        set { progress = newValue.first; slant = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let x = rect.width * progress
        let top    = min(max(x + slant, 0), rect.width)
        let bottom = min(max(x - slant, 0), rect.width)
        var p = Path()
        p.move(to: CGPoint(x: top, y: 0))
        p.addLine(to: CGPoint(x: bottom, y: rect.height))
        return p
    }
}

struct FriendsView: View {

    @Environment(ProManager.self)    private var proManager
    @Environment(DataStore.self)     private var store
    @Environment(HourlyTracker.self) private var hourlyTracker

    @AppStorage("appLanguage")          private var appLanguage: String = "English"
    @AppStorage("challengeDisplayName") private var challengeDisplayName: String = ""
    @AppStorage("dailyGoal")            private var dailyGoal: Int = 50
    @AppStorage("duelSoundsOn")         private var duelSoundsOn: Bool = false

    private var friendSync: FriendSyncManager { FriendSyncManager.shared }
    private var duelManager: DuelManager      { DuelManager.shared }

    @State private var pokePair:  RegisteredPair? = nil
    @State private var duelPair:  RegisteredPair? = nil
    @State private var renamingPair:  RegisteredPair? = nil
    @State private var renameText:    String = ""
    @State private var showRemoveAllConfirm: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showAllFriends: Bool = false
    @State private var showTournaments: Bool = false
    @State private var showFriendApps: Bool = false
    @State private var friendAppsDeviceID: String = ""
    @State private var friendAppsName: String = ""
    private let defaultVisibleFriends = 3

    // Duel result sheet
    @State private var duelResultToShow: DuelRecord? = nil
    /// Comma-separated set of duel IDs already shown to the user.
    /// Replaces the old single-ID "lastSeenDuelResultId" so multiple same-night results all surface.
    @AppStorage("seenDuelResultIds") private var seenDuelResultIdsRaw: String = ""

    // LOW fix: cache the parsed Set in @State to avoid splitting the CSV string
    // on every property access (called 3× per checkForNewDuelResult invocation).
    @State private var seenDuelResultIdsCache: Set<String>? = nil

    private var seenDuelResultIds: Set<String> {
        if let cached = seenDuelResultIdsCache { return cached }
        let parsed = Set(seenDuelResultIdsRaw.split(separator: ",").map(String.init))
        return parsed
    }
    private func markDuelSeen(_ id: String) {
        var ids = seenDuelResultIds
        ids.insert(id)
        seenDuelResultIdsCache = ids
        seenDuelResultIdsRaw = ids.joined(separator: ",")
    }

    // Taunt / Nudge
    @State private var tauntDuel:    DuelRecord? = nil
    @State private var toastMessage: String?     = nil

    // Fluid tilt για το γέμισμα του duel banner — ενεργό μόνο όσο φαίνεται το banner
    @State private var motionTilt = DuelMotionTilt()


    // 1-second tick for live countdown display
    // H1 fix: was Timer.publish.autoconnect() — leaked polls after navigation.
    // Now managed by .task modifiers which auto-cancel on view disappear.
    @State private var tick: Date = Date()

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Tournaments entry point
                        tournamentBanner

                        // Active duel cards — one per friend pair, shown at the top
                        ForEach(duelManager.activeDuels) { duel in
                            activeDuelBanner(duel)
                        }

                        // Friends list
                        friendsCard

                        // Rival records — compact per-opponent duel history
                        rivalRecordsSection

                        // How to connect tip
                        if friendSync.registeredPairs.isEmpty {
                            connectTip
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // ── Toast ──────────────────────────────────────────────
                if let msg = toastMessage {
                    HStack(spacing: 10) {
                        Text(msg)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(white: 0.12).opacity(0.95)))
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(99)
                }
            }
            .navigationTitle(t("Friends", "Φίλοι", "Freunde"))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showTournaments) {
                TournamentListView()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    addFriendsShareLink
                }
            }
        }
        .task {
            // Tick every second for live countdown — cancelled automatically on disappear
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1000))
                tick = Date()
            }
        }
        .task {
            // Poll every 5 s during active duels — initial delay lets forcePoll run first
            try? await Task.sleep(for: .seconds(3))
            while !Task.isCancelled {
                await duelManager.poll()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .task {
            // One-time migration: absorb the old single-ID key into the new set.
            let legacyKey = "lastSeenDuelResultId"
            if let old = UserDefaults.standard.string(forKey: legacyKey), !old.isEmpty {
                markDuelSeen(old)
                UserDefaults.standard.removeObject(forKey: legacyKey)
            }
            // Force (bypass rate-limit) on first appearance so scores are always fresh.
            await duelManager.forcePoll()
            checkForNewDuelResult()
        }
        .onChange(of: duelManager.activeDuels.count) { _, newCount in
            // A new duel just became active — force-poll immediately so both sides
            // see each other's real pickup counts without waiting for the next timer tick.
            guard newCount > 0 else { return }
            Task { await duelManager.forcePoll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .picksyDuelNotifTapped)) { _ in
            // User tapped a duel/message push notification — re-poll and show result if new.
            // This fires even when FriendsView is already loaded (i.e. .task doesn't re-run).
            Task {
                await duelManager.forcePoll()
                checkForNewDuelResult()
            }
        }
        .sheet(item: $duelResultToShow, onDismiss: {
            // Chain-show the next unseen result if there is one (e.g. two duels ended at midnight)
            checkForNewDuelResult()
        }) { duel in
            DuelResultView(duel: duel, hourlyData: hourlyTracker.hourlyData[0])
        }
        .confirmationDialog(
            pokePair.map { t("Nudge \($0.name)", "Nudge τον \($0.name)", "\($0.name) anstupsen") } ?? "",
            isPresented: Binding(get: { pokePair != nil }, set: { if !$0 { pokePair = nil } }),
            titleVisibility: .visible
        ) {
            let nudges: [String] = [
                "🏆 " + t("I'm winning and you know it.", "Κερδίζω και το ξέρεις.", "Ich gewinne und du weißt es."),
                "😂 " + t("You don't stand a chance.", "Δεν έχεις καμία ελπίδα.", "Du hast keine Chance."),
                "📱 " + t("Still on your phone? Embarrassing.", "Ακόμα στο κινητό; Ντροπή.", "Noch am Handy? Peinlich."),
                "👀 " + t("I see you scrolling...", "Σε βλέπω που σκρολάρεις...", "Ich sehe dich scrollen..."),
                "🔥 " + t("Put it down. You can't beat me.", "Κατέβασέ το. Δεν μπορείς να με νικήσεις.", "Leg es weg. Du kannst mich nicht schlagen.")
            ]
            ForEach(nudges, id: \.self) { nudge in
                Button(nudge) {
                    guard let pair = pokePair else { return }
                    Task { await duelManager.sendNudge(toDeviceID: pair.deviceID, text: nudge, senderName: challengeDisplayName) }
                    pokePair = nil
                    showToast(t("Nudge sent 👋", "Το nudge στάλθηκε 👋", "Nudge gesendet 👋"))
                }
            }
            Button(t("Cancel", "Άκυρο", "Abbrechen"), role: .cancel) { pokePair = nil }
        }
        .sheet(item: $duelPair) { pair in
            DuelView(pair: pair)
                .environment(store)
                .environment(proManager)
        }
        .sheet(isPresented: $showFriendApps) {
            FriendAppsSheet(deviceID: friendAppsDeviceID, friendName: friendAppsName)
        }
        .confirmationDialog(
            t("Pick a taunt", "Διάλεξε taunt", "Taunt auswählen"),
            isPresented: Binding(get: { tauntDuel != nil }, set: { if !$0 { tauntDuel = nil } }),
            titleVisibility: .visible
        ) {
            let taunts: [String] = [
                "🏆 " + t("Enjoy second place.", "Απόλαυσε τη δεύτερη θέση.", "Genieß den zweiten Platz."),
                "😂 " + t("Is that all you've got?", "Αυτά έχεις;", "Ist das alles?"),
                "📉 " + t("Your score is a disaster.", "Το σκορ σου είναι καταστροφή.", "Dein Score ist eine Katastrophe."),
                "😤 " + t("I'm not even trying.", "Δεν κάνω καν προσπάθεια.", "Ich geb mir nicht mal Mühe."),
                "🔒 " + t("My phone is basically off.", "Το κινητό μου είναι σχεδόν κλειστό.", "Mein Handy ist quasi aus.")
            ]
            ForEach(taunts, id: \.self) { taunt in
                Button(taunt) {
                    guard let duel = tauntDuel else { return }
                    Task { await duelManager.sendTaunt(to: duel, tauntText: taunt, myName: challengeDisplayName) }
                    tauntDuel = nil
                    showToast(t("Taunt sent 😤", "Το taunt στάλθηκε 😤", "Taunt gesendet 😤"))
                }
            }
            Button(t("Cancel", "Άκυρο", "Abbrechen"), role: .cancel) { tauntDuel = nil }
        }
        .alert(
            t("Rename friend", "Μετονομασία φίλου", "Freund umbenennen"),
            isPresented: Binding(
                get: { renamingPair != nil },
                set: { if !$0 { renamingPair = nil } }
            )
        ) {
            TextField(t("Name", "Όνομα", "Name"), text: $renameText)
            Button(t("Save", "Αποθήκευση", "Speichern")) {
                applyRename()
            }
            Button(t("Cancel", "Άκυρο", "Abbrechen"), role: .cancel) {
                renamingPair = nil
            }
        } message: {
            Text(t(
                "This name is only visible to you.",
                "Αυτό το όνομα είναι ορατό μόνο σε εσένα.",
                "Dieser Name ist nur für dich sichtbar."
            ))
        }
        .alert(
            t("Remove all friends?", "Αφαίρεση όλων των φίλων;", "Alle Freunde entfernen?"),
            isPresented: $showRemoveAllConfirm
        ) {
            Button(t("Remove all", "Αφαίρεση όλων", "Alle entfernen"), role: .destructive) {
                withAnimation { friendSync.removeAllPairs() }
            }
            Button(t("Cancel", "Άκυρο", "Abbrechen"), role: .cancel) {}
        } message: {
            Text(t(
                "You'll stop receiving nudges when friends are overusing their phones.",
                "Θα σταματήσεις να λαμβάνεις ειδοποιήσεις όταν φίλοι υπερχρησιμοποιούν.",
                "Du erhältst keine Benachrichtigungen mehr, wenn Freunde ihr Handy zu viel nutzen."
            ))
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView().environment(proManager)
        }
    }

    // MARK: - Active Duel Banner

    private func activeDuelBanner(_ duel: DuelRecord) -> some View {
        // Duel metric = SCREEN TIME (seconds). Lower = better (less phone use).
        // For "me" we use the local store value (always up-to-date); for the
        // opponent the Supabase-synced value via poll(). Screen time is reliable in
        // the background, so the comparison stays accurate even when apps sleep.
        let myScore    = store.bestScreenTimeSecs
        let theirScore = duel.theirScore
        let myColor: Color = myScore < theirScore
            ? Color(red: 0.4, green: 1.0, blue: 0.6)
            : myScore > theirScore
                ? Color(red: 1.0, green: 0.38, blue: 0.38)
                : .white
        let theirColor: Color = theirScore < myScore
            ? Color(red: 0.4, green: 1.0, blue: 0.6)
            : theirScore > myScore
                ? Color(red: 1.0, green: 0.38, blue: 0.38)
                : .white
        return VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("⚔️")
                    .font(.system(size: 15))
                    // Σύντομο "clash" κάθε ~8 s — μικρό σκίρτημα και ησυχία,
                    // ΟΧΙ συνεχές κούνημα (ζάλιζε). Trigger από το 1s tick.
                    .phaseAnimator(
                        [0.0, 12, -10, 7, -4, 0],
                        trigger: Int(tick.timeIntervalSince1970 / 8)
                    ) { content, angle in
                        content.rotationEffect(.degrees(angle))
                    } animation: { _ in
                        .easeInOut(duration: 0.12)
                    }
                Text(t("ACTIVE DUEL", "ΕΝΕΡΓΗ ΜΟΝΟΜΑΧΙΑ", "AKTIVES DUELL"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(1)
            }

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(t("You", "Εσύ", "Du"))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text(formatDuelTime(myScore))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(myColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.bouncy(duration: 0.5), value: myScore)
                        // The leader's number radiates — glow only when winning
                        .shadow(color: myScore < theirScore ? myColor.opacity(0.65) : .clear,
                                radius: 10)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("VS")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    Text(t("Screen time", "Χρόνος οθόνης", "Bildschirmzeit"))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 56)

                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text(duel.theirName)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                        Button {
                            friendAppsDeviceID = duel.theirDeviceID
                            friendAppsName = duel.theirName
                            showFriendApps = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    let theirDisplay = (theirScore == 0 && myScore > 0) ? "?" : formatDuelTime(theirScore)
                    Text(theirDisplay)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(theirDisplay == "?" ? .white.opacity(0.4) : theirColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.bouncy(duration: 0.5), value: theirScore)
                        .shadow(color: (theirDisplay != "?" && theirScore < myScore)
                                ? theirColor.opacity(0.65) : .clear,
                                radius: 10)
                }
                .frame(maxWidth: .infinity)
            }

            // Live countdown
            if let end = duel.endsAt {
                let secs = max(0, end.timeIntervalSince(tick))
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    Text(formattedCountdown(secs))
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                    Text(t("remaining", "απομένουν", "übrig"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.vertical, 2)
            }

            Text(t("Less screen time by midnight wins 🏆", "Λιγότερος χρόνος οθόνης μέχρι τα μεσάνυχτα νικά 🏆", "Weniger Bildschirmzeit bis Mitternacht gewinnt 🏆"))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            // Taunt button
            Button(action: { tauntDuel = duel }) {
                HStack(spacing: 6) {
                    Text("😤")
                        .font(.system(size: 13))
                    Text(t("Send a taunt", "Στείλε taunt", "Taunt senden"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)

            // Cancel duel button
            Button(action: {
                Task { await DuelManager.shared.cancelActiveDuel(duel) }
            }) {
                Text(t("Cancel duel", "Ακύρωση μονομαχίας", "Duell abbrechen"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            // Day-progress liquid fill: η μπάρα γεμίζει με το «κανονικό» μωβ από
            // αριστερά προς δεξιά όσο πλησιάζουν τα μεσάνυχτα (πρόοδος ημέρας,
            // όχι μονομαχίας) πάνω σε σκουρότερη βάση. Το μέτωπο γέρνει σαν
            // στάθμη υγρού ακολουθώντας το roll της συσκευής (DuelMotionTilt).
            GeometryReader { geo in
                let progress = duelProgress(duel)
                let slant = CGFloat(tan(motionTilt.rollDegrees * .pi / 180)) * geo.size.height / 2
                ZStack(alignment: .leading) {
                    // Σκούρα βάση — το «άδειο» μέρος του χρόνου (1-2 τόνους
                    // σκουρότερη από το μωβ γέμισμα ώστε να ξεχωρίζει καθαρά)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.09, green: 0.06, blue: 0.18),
                                     Color(red: 0.05, green: 0.04, blue: 0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    // Γέμισμα — το αυθεντικό μωβ του banner, με υγρό μέτωπο
                    LiquidFillShape(progress: progress, slant: slant)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.28, green: 0.18, blue: 0.52),
                                     Color(red: 0.15, green: 0.12, blue: 0.38)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .animation(.linear(duration: 1.0), value: progress)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: slant)

                    // Λεπτή φωτεινή ακμή στο μέτωπο του γεμίσματος
                    if progress > 0.01 && progress < 0.995 {
                        LiquidEdgeShape(progress: progress, slant: slant)
                            .stroke(Color.white.opacity(0.30), lineWidth: 2)
                            .blur(radius: 1.5)
                            .animation(.linear(duration: 1.0), value: progress)
                            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: slant)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        )
        .shadow(color: Color(red: 0.45, green: 0.30, blue: 0.95).opacity(0.30), radius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        // Ηχειάκι: on/off για τους ήχους αποτελέσματος (χειροκρότημα/ήττα).
        // Προσωπική προτίμηση — default off, το ανάβει όποιος το θέλει.
        .overlay(alignment: .topTrailing) {
            Button(action: { duelSoundsOn.toggle() }) {
                Image(systemName: duelSoundsOn
                      ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(duelSoundsOn ? 0.85 : 0.40))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        // Fluid tilt: ενεργό μόνο όσο το banner είναι ορατό — το gyroscope
        // καταναλώνει ενέργεια, δεν το αφήνουμε να τρέχει σε άλλα tabs.
        .onAppear { motionTilt.start() }
        .onDisappear { motionTilt.stop() }
    }

    /// Πρόοδος της ΗΜΕΡΑΣ 0…1 — πόσο κοντά είμαστε στις 24:00, το τέλος κάθε
    /// μονομαχίας. Ανεξάρτητη από την ώρα έναρξης: μονομαχία που ξεκινά το
    /// μεσημέρι δείχνει την μπάρα ήδη μισογεμάτη — γεμίζει πλήρως τα μεσάνυχτα.
    /// Υπολογίζεται με βάση το 1s tick ώστε να προχωράει live όσο μένει ορατή.
    private func duelProgress(_ duel: DuelRecord) -> CGFloat {
        let startOfDay = Calendar.current.startOfDay(for: tick)
        let p = tick.timeIntervalSince(startOfDay) / 86_400
        return CGFloat(min(max(p, 0), 1))
    }

    // MARK: - Friends Card

    private var friendsCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(t("CONNECTED FRIENDS", "ΣΥΝΔΕΔΕΜΕΝΟΙ ΦΙΛΟΙ", "VERBUNDENE FREUNDE"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                }

                if !proManager.isPro {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill").font(.system(size: 9))
                        Text("\(min(friendSync.registeredPairs.count, 1))/1")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.12)))
                }

                Spacer()

                if !friendSync.registeredPairs.isEmpty {
                    Button(action: { showRemoveAllConfirm = true }) {
                        Text(t("Remove all", "Αφαίρεση όλων", "Alle entfernen"))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            if friendSync.registeredPairs.isEmpty {
                emptyFriendsState
            } else {
                friendsList
            }

            // Free tier hint
            if !proManager.isPro && !friendSync.registeredPairs.isEmpty {
                Button(action: { showPaywall = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.system(size: 10))
                        Text(t(
                            "Free plan: 1 friend & 1 duel, no accountability nudges · Upgrade",
                            "Δωρεάν: 1 φίλος & 1 μονομαχία, χωρίς accountability nudges · Αναβάθμιση",
                            "Kostenlos: 1 Freund & 1 Duell, kein Accountability-Nudge · Upgrade"
                        ))
                        .font(.system(size: 11, design: .rounded))
                    }
                    .foregroundColor(.blue.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
    }

    private var emptyFriendsState: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.45))
            VStack(alignment: .leading, spacing: 3) {
                Text(t("No connected friends yet", "Κανένας φίλος ακόμα", "Noch keine Freunde"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Text(t(
                    "Tap the Challenge button above to invite friends.",
                    "Πάτησε το κουμπί Πρόκληση παραπάνω για να καλέσεις φίλους.",
                    "Tippe auf den Challenge-Button oben, um Freunde einzuladen."
                ))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var friendsList: some View {
        let sortedPairs = friendSync.registeredPairs.sorted { $0.registeredAt < $1.registeredAt }
        let total       = sortedPairs.count
        let visible     = showAllFriends ? sortedPairs : Array(sortedPairs.prefix(defaultVisibleFriends))
        let hidden      = total - defaultVisibleFriends

        return VStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, pair in
                friendRow(pair: pair, index: index, isLast: pair.id == visible.last?.id && (showAllFriends || hidden <= 0))
            }

            // "Show N more / Show less" button
            if total > defaultVisibleFriends {
                Button(action: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        showAllFriends.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: showAllFriends ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                        Text(showAllFriends
                             ? t("Show less", "Λιγότερα", "Weniger")
                             : t("Show \(hidden) more", "Εμφάνιση \(hidden) ακόμα", "\(hidden) weitere"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGroupedBackground).opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func friendRow(pair: RegisteredPair, index: Int, isLast: Bool) -> some View {
        let isUnknown  = pair.name == "A friend" || pair.name.trimmingCharacters(in: .whitespaces).isEmpty
        let friendNum  = index + 1
        let fallback   = t("Friend #\(friendNum)", "Φίλος #\(friendNum)", "Freund #\(friendNum)")
        let name       = isUnknown ? fallback : pair.name

        // Duel status for this friend
        let hasDuel: Bool = duelManager.activeDuels.contains {
            $0.challengerId == pair.deviceID || $0.opponentId == pair.deviceID
        }

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(hasDuel ? Color.purple.opacity(0.15) : Color.blue.opacity(isUnknown ? 0.07 : 0.12))
                        .frame(width: 42, height: 42)
                    if hasDuel {
                        Text("⚔️").font(.system(size: 18))
                    } else {
                        Text(isUnknown ? "#\(friendNum)" : String(pair.name.prefix(1)).uppercased())
                            .font(.system(size: isUnknown ? 12 : 16, weight: .semibold, design: .rounded))
                            .foregroundColor(isUnknown ? .secondary : .blue)
                    }
                }

                // Name + date
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(isUnknown ? .secondary : .primary)

                    if isUnknown {
                        Text(exactDateTime(pair.registeredAt))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)
                    } else if hasDuel {
                        Text(t("⚔️ Duel in progress", "⚔️ Μονομαχία σε εξέλιξη", "⚔️ Duell läuft"))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.purple)
                    } else {
                        Text(t("Connected", "Συνδέθηκε", "Verbunden") + " · " + relativeDate(pair.registeredAt))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 14) {
                    // Rename
                    Button(action: {
                        renameText  = isUnknown ? "" : pair.name
                        renamingPair = pair
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(isUnknown ? .blue : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)

                    // Poke / Nudge
                    Button(action: {
                        proManager.isPro ? (pokePair = pair) : (showPaywall = true)
                    }) {
                        Image(systemName: proManager.isPro ? "hand.wave.fill" : "lock.fill")
                            .font(.system(size: proManager.isPro ? 18 : 15))
                            .foregroundColor(proManager.isPro ? .orange.opacity(0.8) : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)

                    // Duel — available on Free (1 friend = 1 duel) and Pro (unlimited)
                    Button(action: { duelPair = pair }) {
                        Text("⚔️")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)

                    // Remove
                    Button(action: {
                        withAnimation { friendSync.removePair(deviceID: pair.deviceID) }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider().padding(.leading, 72)
            }
        }
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                toastMessage = nil
            }
        }
    }

    // MARK: - Tournament Banner

    private var tournamentBanner: some View {
        let activeTournaments = TournamentManager.shared.activeTournaments
        return Button { showTournaments = true } label: {
            HStack(spacing: 14) {
                Text("⚔️").font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Group Tournaments", "Ομαδικά Τουρνουά", "Gruppen-Turniere"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(activeTournaments.isEmpty
                         ? t("Challenge groups of friends weekly", "Πρόκλεσε ομάδες φίλων κάθε εβδομάδα", "Fordere Freundesgruppen wöchentlich heraus")
                         : t("\(activeTournaments.count) active", "\(activeTournaments.count) ενεργά", "\(activeTournaments.count) aktiv"))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connect Tip

    private var connectTip: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.2.arms.open")
                .font(.system(size: 36))
                .foregroundColor(.blue.opacity(0.5))
            VStack(spacing: 6) {
                Text(t("Connect with friends", "Σύνδεσε φίλους", "Verbinde Freunde"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(t(
                    "Tap \"Add Friends\" above and share your link. Whether they already have Picksy or not — the link handles it.",
                    "Πάτησε «Πρόσθεσε φίλους» πάνω και μοιράσου τον σύνδεσμό σου. Είτε έχουν ήδη το Picksy είτε όχι — ο σύνδεσμος τα βολεύει.",
                    "Tippe auf \"Freunde einladen\" oben und teile deinen Link. Egal ob sie Picksy schon haben — der Link regelt alles."
                ))
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
    }

    // MARK: - Rival Records

    /// Per-opponent summary: name → (wins, losses, ties, lastDate), sorted by most recent.
    private var opponentRecords: [(name: String, w: Int, l: Int, t: Int, last: Date)] {
        let history = duelManager.duelHistory
        guard !history.isEmpty else { return [] }
        let grouped = Dictionary(grouping: history, by: { $0.theirName })
        return grouped.map { name, duels in
            let w = duels.filter { $0.iWon  }.count
            let l = duels.filter { $0.iLost }.count
            let t = duels.filter { $0.isTie }.count
            let last = duels.map(\.createdAt).max() ?? .distantPast
            return (name: name, w: w, l: l, t: t, last: last)
        }
        .sorted { $0.last > $1.last }
    }

    @ViewBuilder
    private var rivalRecordsSection: some View {
        let records = opponentRecords
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(t("RIVAL RECORDS", "ΙΣΤΟΡΙΚΟ ΜΟΝΟΜΑΧΙΩΝ", "DUELLE"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Divider().padding(.horizontal, 16)

                ForEach(Array(records.enumerated()), id: \.element.name) { idx, rec in
                    rivalRow(rec, isLast: idx == records.count - 1)
                }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        }
    }

    private func rivalRow(_ rec: (name: String, w: Int, l: Int, t: Int, last: Date), isLast: Bool) -> some View {
        let icon    = rec.w > rec.l ? "🏆" : (rec.l > rec.w ? "📱" : "🤝")
        let record  = "\(rec.w)W · \(rec.l)L" + (rec.t > 0 ? " · \(rec.t)T" : "")
        let outcome = rec.w > rec.l
            ? t("Winning", "Κερδίζεις", "Gewinnst")
            : rec.l > rec.w
                ? t("Losing", "Χάνεις", "Verlierst")
                : t("Tied", "Ισοπαλία", "Unentsch.")
        let outcomeColor: Color = rec.w > rec.l ? .green : (rec.l > rec.w ? .orange : .secondary)

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(icon)
                    .font(.system(size: 22))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(t("vs \(rec.name)", "με \(rec.name)", "vs. \(rec.name)"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    Text(relativeDate(rec.last))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(record)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(outcome)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(outcomeColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider().padding(.leading, 62)
            }
        }
    }

    // MARK: - Helpers

    private func applyRename() {
        guard let pair = renamingPair else { return }
        let name = renameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { renamingPair = nil; return }
        var pairs = friendSync.registeredPairs
        if let idx = pairs.firstIndex(where: { $0.deviceID == pair.deviceID }) {
            pairs[idx] = RegisteredPair(
                deviceID: pair.deviceID,
                name: name,
                registeredAt: pair.registeredAt
            )
            friendSync.registeredPairs = pairs
        }
        renamingPair = nil
    }

    /// Shows the next unseen duel result sheet.
    /// Called on launch, on notification tap, and on sheet dismiss — so multiple
    /// same-night results surface one by one (fixes the "second duel never shown" bug).
    private func checkForNewDuelResult() {
        guard duelResultToShow == nil else { return }   // already showing one
        let seen = seenDuelResultIds
        guard let duel = duelManager.duelHistory.first(where: {
            !seen.contains($0.id) &&
            Date().timeIntervalSince($0.createdAt) < 48 * 3600
        }) else { return }

        duelResultToShow = duel
        markDuelSeen(duel.id)
    }

    private func formattedCountdown(_ secs: TimeInterval) -> String {
        let total = max(0, Int(secs))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    /// Formats duel screen-time seconds as a compact duration, e.g. "1h 23m" / "45m".
    private func formatDuelTime(_ seconds: Int) -> String {
        let secs = max(0, seconds)
        if secs < 60 { return "0m" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // Static formatters — DateFormatter is expensive to construct; cache once.
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return t("today", "σήμερα", "heute") }
        if days == 1 { return t("yesterday", "χτες", "gestern") }
        if days < 7  { return t("\(days) days ago", "πριν \(days) μέρες", "vor \(days) Tagen") }
        return Self.dateOnlyFormatter.string(from: date)
    }

    private func exactDateTime(_ date: Date) -> String {
        return t("Connected", "Συνδέθηκε", "Verbunden") + " · " + Self.dateTimeFormatter.string(from: date)
    }

    // MARK: - Add Friends Share Link

    // ShareLink avoids the UIActivityViewController blank-screen-on-first-tap bug.
    // The link is smart: existing Picksy users get deep-linked to connect with you;
    // new users land on the App Store first, then connect after downloading.
    private var addFriendsShareLink: some View {
        let goal = dailyGoal > 0 ? dailyGoal : 50
        let url: URL = ChallengeManager.buildURL(
            displayName: challengeDisplayName,
            weeklyPickups: store.weeklyPickups,
            streak: store.currentStreak,
            dailyGoal: goal
        ) ?? URL(string: "https://fotiospongas.dev/challenge")!

        let message = t(
            "I'm using Picksy to cut down my phone pickups — want to compete? 📱👇",
            "Χρησιμοποιώ το Picksy για να μειώσω τα σηκώματα κινητού — να κάνουμε κόντρα; 📱👇",
            "Ich nutze Picksy, um meine Handy-Griffe zu reduzieren — wollen wir konkurrieren? 📱👇"
        )

        return ShareLink(item: url, message: Text(message)) {
            HStack(spacing: 6) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                Text(t("Add Friends", "Πρόσθεσε φίλους", "Freunde einladen"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.blue))
        }
        .buttonStyle(.plain)
    }
}

