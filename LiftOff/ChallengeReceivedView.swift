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

    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

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
        let hours = Int(ago / 3600)
        if hours < 1 { return t("just now", "μόλις τώρα", "gerade eben") }
        if hours < 24 { return t("\(hours)h ago", "πριν \(hours)ώ", "vor \(hours)h") }
        let days = hours / 24
        return t("\(days)d ago", "πριν \(days)μ", "vor \(days)T")
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
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
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
            // Send mine back
            Button(action: sendMineBack) {
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
            .buttonStyle(.plain)

            Button(action: { dismiss() }) {
                Text(t("Maybe later", "Ίσως αργότερα", "Vielleicht später"))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func sendMineBack() {
        guard let url = ChallengeManager.buildURL(
            displayName: displayName,
            weeklyPickups: store.weeklyPickups,
            streak: store.currentStreak,
            dailyGoal: dailyGoal
        ) else { return }

        let msg = ChallengeManager.shareMessage(payload: ChallengePayload(
            name: displayName.isEmpty ? "A friend" : displayName,
            weekly: store.weeklyPickups,
            streak: store.currentStreak,
            goal: dailyGoal,
            sentAt: Date().timeIntervalSince1970
        ), language: appLanguage)

        shareItems = [msg, url.absoluteString]
        showShareSheet = true
    }
}

// MARK: - UIKit Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
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
