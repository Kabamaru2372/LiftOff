// DuelView.swift
// Picksy
//
// Shows the Pickup Duel UI for a specific friend pair.
// States: idle → pending (sent/received) → active → completed.

import SwiftUI
import Combine

struct DuelView: View {

    let pair: RegisteredPair

    @Environment(\.dismiss)   private var dismiss
    @Environment(DataStore.self)   private var store
    @Environment(ProManager.self)  private var proManager

    @AppStorage("appLanguage")         private var appLanguage: String = "English"
    @AppStorage("challengeDisplayName") private var displayName: String = ""

    private var duelManager: DuelManager { DuelManager.shared }

    // H2 fix: was Timer.publish.autoconnect() — leaked polls after sheet dismissed.
    // Replaced with .task modifiers that auto-cancel on view disappear.
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
            ZStack {
                backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {

                        // Opponent header
                        opponentHeader
                            .padding(.top, 8)

                        // State-driven content
                        if let duel = duelManager.activeDuel,
                           duel.challengerId == pair.deviceID || duel.opponentId == pair.deviceID {
                            if duel.status == .active {
                                activeDuelCard(duel)
                            } else if duel.status == .completed {
                                completedDuelCard(duel)
                            }
                        } else {
                            idleCard
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle(t("Pickup Duel", "Pickup Duel", "Pickup Duell"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Close", "Κλείσιμο", "Schließen")) { dismiss() }
                        .font(.system(size: 15, design: .rounded))
                }
            }
            .task { await duelManager.poll() }
            .task {
                // 1-second tick for live countdown — auto-cancelled on dismiss
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(1000))
                    tick = Date()
                }
            }
            .task {
                // Poll opponent score every 15 s — auto-cancelled on dismiss
                try? await Task.sleep(for: .seconds(5))
                while !Task.isCancelled {
                    await duelManager.poll()
                    try? await Task.sleep(for: .seconds(15))
                }
            }
        }
    }

    // MARK: - Opponent Header

    private var opponentHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 64, height: 64)
                Text(pair.name.isEmpty ? "?" : String(pair.name.prefix(1)).uppercased())
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
            }
            Text(pair.name.isEmpty
                 ? t("Friend", "Φίλος", "Freund")
                 : pair.name)
                .font(.system(size: 20, weight: .semibold, design: .rounded))

            Text(t("⚔️ Pickup Duel", "⚔️ Pickup Duel", "⚔️ Pickup Duell"))
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Idle (no active duel)

    private var idleCard: some View {
        VStack(spacing: 20) {
            Text("⚔️")
                .font(.system(size: 60))

            VStack(spacing: 6) {
                Text(t("Challenge \(firstName) today!",
                       "Προκάλεσε τον \(firstName) σήμερα!",
                       "Fordere \(firstName) heute heraus!"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(t(
                    "Whoever has less screen time by midnight wins.",
                    "Όποιος έχει λιγότερο χρόνο οθόνης μέχρι τα μεσάνυχτα κερδίζει.",
                    "Wer bis Mitternacht weniger Bildschirmzeit hat, gewinnt."
                ))
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }

            // Fairness: the duel counts time only on each player's SELECTED apps.
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "scale.3d")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
                Text(t(
                    "Counts time on your selected apps only — make sure you both track the same categories (ideally all of Social).",
                    "Μετράει χρόνο μόνο στις επιλεγμένες apps — βεβαιωθείτε ότι μετράτε και οι δύο τις ίδιες κατηγορίες (ιδανικά όλη τη Social).",
                    "Zählt nur Zeit in den gewählten Apps — stellt sicher, dass ihr beide dieselben Kategorien trackt (ideal: ganz Social)."
                ))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.08)))

            Button(action: sendDuel) {
                Label(
                    t("Send Duel", "Αποστολή Duel", "Duell senden"),
                    systemImage: "paperplane.fill"
                )
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
    }

    // MARK: - Active Duel

    private func activeDuelCard(_ duel: DuelRecord) -> some View {
        // "You" = my SCREEN TIME (seconds). This is the SAME value we sync to
        // Supabase (challenger/opponent_screen_time), so the opponent sees the exact
        // same number for you and the comparison is fair. Screen time is the metric
        // Apple reports reliably in the background, so the duel stays accurate even
        // when the app is suspended.
        let myCount = store.bestScreenTimeSecs

        // Compute remaining seconds using `tick` so the view re-renders every second
        let secsRemaining: TimeInterval = {
            guard let end = duel.endsAt else { return 0 }
            return max(0, end.timeIntervalSince(tick))
        }()

        return VStack(spacing: 24) {

            // Countdown
            if secsRemaining > 0 {
                VStack(spacing: 4) {
                    Text(formattedCountdown(secsRemaining))
                        .font(.system(size: 36, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue)
                    Text(t("remaining today", "απομένουν σήμερα", "noch heute"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            // Scoreboard
            HStack(spacing: 0) {
                // Me — app-side Picksy Score (the same value synced to Supabase,
                // so you and your friend always see the exact same number for you).
                scoreColumn(
                    label: t("You", "Εσύ", "Du"),
                    display: formatScreenTime(myCount),
                    numberColor: myCount < duel.theirScore
                        ? Color(red: 0.2, green: 0.8, blue: 0.4)
                        : myCount > duel.theirScore
                            ? Color(red: 1.0, green: 0.3, blue: 0.3)
                            : .primary,
                    isLeading: myCount < duel.theirScore,
                    highlight: true
                )

                // VS divider
                VStack(spacing: 4) {
                    Text("VS")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(width: 40)

                // Opponent
                scoreColumn(
                    label: firstName,
                    display: formatScreenTime(duel.theirScore),
                    numberColor: duel.theirScore < myCount
                        ? Color(red: 0.2, green: 0.8, blue: 0.4)
                        : duel.theirScore > myCount
                            ? Color(red: 1.0, green: 0.3, blue: 0.3)
                            : .primary,
                    isLeading: duel.theirScore < myCount,
                    highlight: false
                )
            }
            .padding(.vertical, 8)

            Text(t(
                "Less screen time = winner 🏆",
                "Λιγότερος χρόνος οθόνης = νίκη 🏆",
                "Weniger Bildschirmzeit = Sieg 🏆"
            ))
            .font(.system(size: 13, design: .rounded))
            .foregroundColor(.secondary)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
    }

    // MARK: - Completed Duel

    private func completedDuelCard(_ duel: DuelRecord) -> some View {
        VStack(spacing: 20) {

            Text(duel.isTie ? "🤝" : (duel.iWon ? "🏆" : "📱"))
                .font(.system(size: 60))

            VStack(spacing: 6) {
                if duel.isTie {
                    Text(t("It's a tie!", "Ισοπαλία!", "Unentschieden!"))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text(t("You're both equally disciplined.", "Είστε εξίσου πειθαρχημένοι.", "Ihr seid beide gleich diszipliniert."))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else if duel.iWon {
                    Text(t("You won! 🎉", "Κέρδισες! 🎉", "Du hast gewonnen! 🎉"))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text(t("You used your phone less than \(firstName) today.", "Χρησιμοποίησες λιγότερο το κινητό σου από τον \(firstName) σήμερα.", "Du hast heute dein Handy seltener genutzt als \(firstName)."))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(t("\(firstName) won", "\(firstName) κέρδισε", "\(firstName) hat gewonnen"))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text(t("They used their phone less than you today. Try again tomorrow!", "Χρησιμοποίησαν λιγότερο το κινητό τους από εσένα σήμερα. Προσπάθησε αύριο!", "Sie haben heute ihr Handy weniger genutzt als du. Versuch's morgen nochmal!"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Final score
            HStack(spacing: 0) {
                scoreColumn(
                    label: t("You", "Εσύ", "Du"),
                    display: formatScreenTime(duel.myScore),
                    numberColor: duel.iWon
                        ? Color(red: 0.2, green: 0.8, blue: 0.4)
                        : duel.iLost
                            ? Color(red: 1.0, green: 0.3, blue: 0.3)
                            : .primary,
                    isLeading: duel.iWon,
                    highlight: true
                )
                Text("VS").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.secondary).frame(width: 40)
                scoreColumn(
                    label: firstName,
                    display: formatScreenTime(duel.theirScore),
                    numberColor: duel.iLost
                        ? Color(red: 0.2, green: 0.8, blue: 0.4)
                        : duel.iWon
                            ? Color(red: 1.0, green: 0.3, blue: 0.3)
                            : .primary,
                    isLeading: duel.iLost,
                    highlight: false
                )
            }

            // Rematch
            Button(action: sendDuel) {
                Text(t("Rematch ⚔️", "Ξανά ⚔️", "Revanche ⚔️"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
    }

    // MARK: - Helpers

    private func scoreColumn(label: String, display: String, numberColor: Color, isLeading: Bool, highlight: Bool) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(highlight ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(display)
                .font(.system(size: 34, weight: .medium, design: .rounded))
                .foregroundColor(numberColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(t("Screen time", "Χρόνος οθόνης", "Bildschirmzeit"))
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)

            if isLeading {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Formats screen-time seconds as a compact duration, e.g. "1h 23m" / "45m".
    private func formatScreenTime(_ seconds: Int) -> String {
        let secs = max(0, seconds)
        if secs < 60 { return "0m" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var firstName: String {
        pair.name.isEmpty
            ? t("Friend", "Φίλος", "Freund")
            : pair.name.components(separatedBy: " ").first ?? pair.name
    }

    private var myDisplayName: String {
        displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? t("A friend", "Φίλος", "Ein Freund")
            : displayName
    }

    private func sendDuel() {
        Task {
            await duelManager.createDuel(
                opponent: pair,
                myName: myDisplayName,
                myCurrentPickups: store.todayPickups
            )
        }
    }

    private func formattedCountdown(_ secs: TimeInterval) -> String {
        let total  = max(0, Int(secs))
        let h      = total / 3600
        let m      = (total % 3600) / 60
        let s      = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.06), Color(.systemBackground)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
