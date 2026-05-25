// FriendsView.swift
// Picksy
//
// Dedicated Friends tab — shows connected friends, active duel status,
// messaging, and duel invites all in one place.

import SwiftUI
import Combine

struct FriendsView: View {

    @Environment(ProManager.self)    private var proManager
    @Environment(DataStore.self)     private var store
    @Environment(HourlyTracker.self) private var hourlyTracker

    @AppStorage("appLanguage")          private var appLanguage: String = "English"
    @AppStorage("challengeDisplayName") private var challengeDisplayName: String = ""
    @AppStorage("dailyGoal")            private var dailyGoal: Int = 15

    private var friendSync: FriendSyncManager { FriendSyncManager.shared }
    private var duelManager: DuelManager      { DuelManager.shared }

    @State private var messagingPair: RegisteredPair? = nil
    @State private var duelPair:      RegisteredPair? = nil
    @State private var renamingPair:  RegisteredPair? = nil
    @State private var renameText:    String = ""
    @State private var showRemoveAllConfirm: Bool = false
    @State private var showPaywall: Bool = false

    // Duel result sheet
    @State private var duelResultToShow: DuelRecord? = nil
    @AppStorage("lastSeenDuelResultId") private var lastSeenDuelResultId: String = ""

    // 1-second tick for live countdown display
    @State private var tick: Date = Date()
    let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    // 5-second poll — combined with DuelManager's 5 s effectivePollInterval this
    // gives near-realtime score updates during active duels (score lag ≤ ~5 s).
    let pollTimer      = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

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
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Active duel cards — one per friend pair, shown at the top
                        ForEach(duelManager.activeDuels) { duel in
                            activeDuelBanner(duel)
                        }

                        // Pending invite (only shown when no active duels occupy the top)
                        if duelManager.activeDuels.isEmpty, let invite = duelManager.pendingInvite {
                            pendingInviteBanner(invite)
                        }

                        // Friends list
                        friendsCard

                        // How to connect tip
                        if friendSync.registeredPairs.isEmpty {
                            connectTip
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle(t("Friends", "Φίλοι", "Freunde"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    challengeShareLink
                }
            }
        }
        .onReceive(countdownTimer) { date in tick = date }
        .onReceive(pollTimer) { _ in
            Task { await duelManager.poll() }
        }
        .task {
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
        .sheet(item: $duelResultToShow) { duel in
            DuelResultView(duel: duel, hourlyData: hourlyTracker.hourlyData[0])
        }
        .sheet(item: $messagingPair) { pair in
            MessageView(pair: pair)
        }
        .sheet(item: $duelPair) { pair in
            DuelView(pair: pair)
                .environment(store)
                .environment(proManager)
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
        // Always use local store.todayPickups for "You" — it's always up-to-date.
        // duel.theirPickups comes from Supabase via poll().
        let myCount    = store.todayPickups
        let theirCount = duel.theirPickups
        let myColor: Color = myCount < theirCount
            ? Color(red: 0.4, green: 1.0, blue: 0.6)
            : myCount > theirCount
                ? Color(red: 1.0, green: 0.38, blue: 0.38)
                : .white
        let theirColor: Color = theirCount < myCount
            ? Color(red: 0.4, green: 1.0, blue: 0.6)
            : theirCount > myCount
                ? Color(red: 1.0, green: 0.38, blue: 0.38)
                : .white
        return VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("⚔️")
                    .font(.system(size: 15))
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
                    Text("\(myCount)")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundColor(myColor)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("VS")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    Text(t("pickups", "σηκώματα", "Griffe"))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(width: 44)

                VStack(spacing: 2) {
                    Text(duel.theirName)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    Text("\(theirCount)")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundColor(theirColor)
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

            Text(t("Fewer pickups by midnight wins 🏆", "Λιγότερα σηκώματα μέχρι τα μεσάνυχτα νικά 🏆", "Weniger Griffe bis Mitternacht gewinnt 🏆"))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            // Cancel duel button
            Button(action: {
                Task { await DuelManager.shared.cancelActiveDuel(duel) }
            }) {
                Text(t("Cancel duel", "Ακύρωση μονομαχίας", "Duell abbrechen"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [Color(red: 0.28, green: 0.18, blue: 0.52), Color(red: 0.15, green: 0.12, blue: 0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }

    // MARK: - Pending Invite Banner

    private func pendingInviteBanner(_ invite: DuelRecord) -> some View {
        HStack(spacing: 14) {
            Text("🔔").font(.system(size: 28))
            VStack(alignment: .leading, spacing: 4) {
                Text(t("\(invite.theirName) challenges you!", "\(invite.theirName) σε προκαλεί!", "\(invite.theirName) fordert dich heraus!"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(t("Tap to respond", "Πάτα για απάντηση", "Tippe zum Antworten"))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let pair = friendSync.registeredPairs.first(where: { $0.deviceID == invite.challengerId }) {
                Button(action: { duelPair = pair }) {
                    Text("⚔️")
                        .font(.system(size: 22))
                        .padding(10)
                        .background(Circle().fill(Color.blue.opacity(0.12)))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.25), lineWidth: 1))
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
                            "Free plan: 1 friend, no messaging or duels · Upgrade",
                            "Δωρεάν: 1 φίλος, χωρίς μηνύματα ή duels · Αναβάθμιση",
                            "Kostenlos: 1 Freund, kein Messaging oder Duell · Upgrade"
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

        return VStack(spacing: 0) {
            ForEach(Array(sortedPairs.enumerated()), id: \.element.id) { index, pair in
                friendRow(pair: pair, index: index, isLast: pair.id == sortedPairs.last?.id)
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

                    // Message
                    Button(action: {
                        proManager.isPro ? (messagingPair = pair) : (showPaywall = true)
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: proManager.isPro ? "bubble.left.fill" : "lock.fill")
                                .font(.system(size: proManager.isPro ? 18 : 15))
                                .foregroundColor(proManager.isPro ? .blue.opacity(0.75) : .secondary.opacity(0.4))
                            let unread = MessagingManager.shared.unreadCountForFriend(pair.deviceID)
                            if proManager.isPro && unread > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 9, height: 9)
                                    .offset(x: 3, y: -3)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Duel
                    Button(action: {
                        proManager.isPro ? (duelPair = pair) : (showPaywall = true)
                    }) {
                        Text(proManager.isPro ? "⚔️" : "🔒")
                            .font(.system(size: proManager.isPro ? 18 : 14))
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
                    "Tap the Challenge button above and share your link. When a friend opens it, you'll both appear here.",
                    "Πάτησε το κουμπί Πρόκληση παραπάνω και μοιράσου τον σύνδεσμό σου. Όταν ένας φίλος τον ανοίξει, θα εμφανιστείτε εδώ.",
                    "Tippe auf den Challenge-Button oben und teile deinen Link. Wenn ein Freund ihn öffnet, erscheint ihr beide hier."
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

    /// Shows the duel result sheet once per completed duel (tracked by ID in UserDefaults).
    private func checkForNewDuelResult() {
        // Use duelHistory (newest first) — completed duels live there, not in activeDuels
        guard let duel = duelManager.duelHistory.first,
              duel.id != lastSeenDuelResultId,
              // Only show if completed today or yesterday (fresh result)
              Date().timeIntervalSince(duel.createdAt) < 48 * 3600
        else { return }

        duelResultToShow     = duel
        lastSeenDuelResultId = duel.id
    }

    private func formattedCountdown(_ secs: TimeInterval) -> String {
        let total = max(0, Int(secs))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return t("today", "σήμερα", "heute") }
        if days == 1 { return t("yesterday", "χτες", "gestern") }
        if days < 7  { return t("\(days) days ago", "πριν \(days) μέρες", "vor \(days) Tagen") }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: date)
    }

    private func exactDateTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return t("Connected", "Συνδέθηκε", "Verbunden") + " · " + f.string(from: date)
    }

    // ShareLink avoids the UIActivityViewController blank-screen-on-first-tap bug
    // that occurs when wrapping UIActivityViewController in a SwiftUI .sheet().
    private var challengeShareLink: some View {
        let goal = dailyGoal > 0 ? dailyGoal : 50
        let url: URL = ChallengeManager.buildURL(
            displayName: challengeDisplayName,
            weeklyPickups: store.weeklyPickups,
            streak: store.currentStreak,
            dailyGoal: goal
        ) ?? URL(string: "https://fotiospongas.dev/challenge")!

        let payload = ChallengePayload(
            name: challengeDisplayName.isEmpty ? "A friend" : challengeDisplayName,
            weekly: store.weeklyPickups,
            streak: store.currentStreak,
            goal: goal,
            sentAt: Date().timeIntervalSince1970,
            senderDeviceID: FriendSyncManager.shared.deviceID
        )
        let msg = ChallengeManager.shareMessage(payload: payload, language: appLanguage)

        return ShareLink(item: url, message: Text(msg)) {
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(t("Challenge", "Πρόκληση", "Challenge"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(LinearGradient(
                        colors: [.yellow, .orange.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            )
        }
        .buttonStyle(.plain)
    }
}
