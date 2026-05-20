// ChallengeReceivedView.swift
// Picksy
//
// Shown when the user opens a picksy://challenge link.
// Displays a side-by-side weekly comparison and a "Send mine back" button.

import SwiftUI

struct ChallengeReceivedView: View {

    let payload: ChallengePayload

    @Environment(DataStore.self) var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage")      private var appLanguage: String = "English"
    @AppStorage("dailyGoal")        private var dailyGoal:  Int    = 50
    @AppStorage("challengeDisplayName") private var displayName: String = ""

    @State private var pairingRegistered = false
    @State private var sentBack = false          // shows confirmation after sending

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    // MARK: - Derived

    private var myWeekly: [Int]  { store.weeklyPickups }
    private var theirWeekly: [Int] { payload.weekly }

    private var myAvg: Int {
        guard !myWeekly.isEmpty else { return 0 }
        return myWeekly.reduce(0, +) / myWeekly.count
    }

    private var theirAvg: Int {
        guard !theirWeekly.isEmpty else { return 0 }
        return theirWeekly.reduce(0, +) / theirWeekly.count
    }

    private var iWin: Bool { myAvg <= theirAvg }  // lower = better in Picksy

    private var maxValue: Int {
        max((myWeekly + theirWeekly).max() ?? 1, 1)
    }

    private var dayLabels: [String] {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }

    private var sentAgoText: String {
        let ago = Date().timeIntervalSince1970 - payload.sentAt
        let minutes = Int(ago / 60)
        let hours = minutes / 60
        let days = hours / 24

        if minutes < 2  { return t("just now", "μόλις τώρα", "gerade eben") }
        if minutes < 60 { return t("\(minutes)m ago", "πριν \(minutes)λ", "vor \(minutes)m") }
        if hours < 24   { return t("\(hours)h ago", "πριν \(hours)ώ", "vor \(hours)h") }
        if days < 7     { return t("\(days)d ago", "πριν \(days) μέρες", "vor \(days) Tagen") }

        // Older than a week — show the actual date
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: Date(timeIntervalSince1970: payload.sentAt))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    headerSection

                    // Chart
                    chartSection

                    // Stats summary
                    statsRow

                    // CTA
                    ctaSection

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .navigationTitle(t("Challenge", "Πρόκληση", "Herausforderung"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Close", "Κλείσιμο", "Schließen")) { dismiss() }
                        .font(.system(size: 15, design: .rounded))
                }
            }
        }
        .onAppear {
            // Register anonymous pair if sender included their device ID.
            // Free tier: max 1 friend. Pro: unlimited.
            if let senderID = payload.senderDeviceID, !senderID.isEmpty {
                Task {
                    let friendSync = FriendSyncManager.shared
                    let alreadyKnown = friendSync.registeredPairs.contains { $0.deviceID == senderID }
                    let isPro = ProManager.shared.isPro
                    let atLimit = friendSync.registeredPairs.count >= 1

                    // Allow if: friend already paired, OR user is Pro, OR haven't hit the 1-friend limit
                    if alreadyKnown || isPro || !atLimit {
                        await friendSync.registerPair(
                            theirDeviceID: senderID,
                            theirName: payload.name
                        )
                    }
                    await MainActor.run { pairingRegistered = true }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(iWin ? "🏆" : "💪")
                .font(.system(size: 52))

            Text(iWin
                 ? t("You're winning!", "Κερδίζεις!", "Du gewinnst!")
                 : t("You can beat this!", "Μπορείς να τα πας καλύτερα!", "Das kannst du toppen!")
            )
            .font(.system(size: 22, weight: .bold, design: .rounded))

            Text(t(
                "\(payload.name) sent you a challenge · \(sentAgoText)",
                "Ο \(payload.name) σου έστειλε πρόκληση · \(sentAgoText)",
                "\(payload.name) hat dich herausgefordert · \(sentAgoText)"
            ))
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("This week — pickups per day", "Αυτή η εβδομάδα — σηκώματα ανά μέρα", "Diese Woche — Griffe pro Tag"))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)

            // Grouped bar chart
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 4) {
                        // Grouped bars
                        HStack(alignment: .bottom, spacing: 2) {
                            // Mine
                            let myH = barHeight(for: i < myWeekly.count ? myWeekly[i] : 0)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.blue.opacity(0.75))
                                .frame(width: 14, height: myH)

                            // Theirs
                            let theirH = barHeight(for: i < theirWeekly.count ? theirWeekly[i] : 0)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.orange.opacity(0.75))
                                .frame(width: 14, height: theirH)
                        }

                        Text(dayLabels[i])
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))

            // Legend
            HStack(spacing: 16) {
                legendDot(color: .blue,   label: t("You", "Εσύ", "Du"))
                legendDot(color: .orange, label: payload.name)
            }
            .padding(.leading, 4)
        }
    }

    private func barHeight(for value: Int) -> CGFloat {
        let maxH: CGFloat = 72
        return max(CGFloat(value) / CGFloat(maxValue) * maxH, 4)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color.opacity(0.75))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statBox(
                title: t("Your avg", "Μέσος σου", "Dein Ø"),
                value: "\(myAvg)",
                color: .blue,
                isWinner: iWin
            )

            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1, height: 56)

            statBox(
                title: payload.name,
                value: "\(theirAvg)",
                color: .orange,
                isWinner: !iWin
            )
        }
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private func statBox(title: String, value: String, color: Color, isWinner: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
                if isWinner {
                    Text("🏆")
                        .font(.system(size: 16))
                }
            }
            Text(title)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 12) {
            if sentBack {
                // ── Confirmation state ──────────────────────────────────────
                VStack(spacing: 10) {
                    Text("🤝")
                        .font(.system(size: 40))

                    Text(t(
                        "You're connected!",
                        "Είστε συνδεδεμένοι!",
                        "Ihr seid verbunden!"
                    ))
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                    Text(t(
                        "Picksy will nudge both of you when you're both reaching for your phone a lot. No accounts, no data shared.",
                        "Το Picksy θα σας ειδοποιεί και τους δύο όταν σηκώνετε πολύ το κινητό. Χωρίς λογαριασμούς, χωρίς κοινά δεδομένα.",
                        "Picksy benachrichtigt euch beide, wenn ihr oft zum Handy greift. Keine Konten, keine geteilten Daten."
                    ))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))

                Button(action: { dismiss() }) {
                    Text(t("Close", "Κλείσιμο", "Schließen"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
                }
                .buttonStyle(.plain)

            } else {
                // ── Default state ────────────────────────────────────────────
                // ShareLink — native iOS 16+ share sheet, no UIApplication needed.
                // Works correctly even when ChallengeReceivedView is itself presented
                // as a sheet (avoids the black-screen UIActivityViewController bug).
                Group {
                    if let url   = ChallengeManager.buildURL(
                            displayName:   displayName,
                            weeklyPickups: store.weeklyPickups,
                            streak:        store.currentStreak,
                            dailyGoal:     dailyGoal),
                       let shareURL = URL(string: url.absoluteString) {

                        let msg = ChallengeManager.shareMessage(
                            payload: ChallengePayload(
                                name:           displayName.isEmpty ? "A friend" : displayName,
                                weekly:         store.weeklyPickups,
                                streak:         store.currentStreak,
                                goal:           dailyGoal,
                                sentAt:         Date().timeIntervalSince1970,
                                senderDeviceID: FriendSyncManager.shared.deviceID
                            ),
                            language: appLanguage
                        )

                        ShareLink(item: shareURL, message: Text(msg)) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.turn.up.right")
                                    .font(.system(size: 14))
                                Text(t("Send mine back", "Στείλε τα δικά μου", "Meine zurückschicken"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.7)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            )
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            // Show confirmation after a short delay (share sheet appears first)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                withAnimation { sentBack = true }
                            }
                        })
                    }
                }

                Button(action: { dismiss() }) {
                    Text(t("Maybe later", "Ίσως αργότερα", "Vielleicht später"))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                if pairingRegistered || payload.senderDeviceID != nil {
                    privacyNotice
                }
            }
        }
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(t(
                "Your daily pickup count will be shared anonymously with \(payload.name) so Picksy can alert you both when you're both reaching for your phones a lot. No account, no name, no personal data.",
                "Ο αριθμός σηκωμάτων σου θα μοιραστεί ανώνυμα με τον \(payload.name) ώστε το Picksy να σας ειδοποιεί και τους δύο αν σηκώνετε πολύ το κινητό. Χωρίς λογαριασμό, χωρίς όνομα, χωρίς προσωπικά δεδομένα.",
                "Deine tägliche Greifanzahl wird anonym mit \(payload.name) geteilt, damit Picksy euch beide benachrichtigen kann, wenn ihr beide viel zum Handy greift. Kein Konto, kein Name, keine persönlichen Daten."
            ))
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Actions

}

// MARK: - UIKit Share Sheet (multi-item)

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ChallengeReceivedView(payload: ChallengePayload(
        name: "Maria",
        weekly: [28, 15, 22, 31, 19, 24, 12],
        streak: 3,
        goal: 30,
        sentAt: Date().addingTimeInterval(-3600).timeIntervalSince1970
    ))
    .environment(DataStore())
}
