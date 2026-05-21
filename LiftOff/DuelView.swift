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

    // Countdown timer refresh
    @State private var tick: Date = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

                        } else if let invite = duelManager.pendingInvite,
                                  invite.challengerId == pair.deviceID {
                            incomingInviteCard(invite)

                        } else if let sent = duelManager.sentPendingDuel,
                                  sent.opponentId == pair.deviceID {
                            sentPendingCard(sent)

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
            .onReceive(timer) { _ in tick = Date() }
            .task { await duelManager.poll() }
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
                    "Whoever picks up their phone less by midnight wins.",
                    "Όποιος σηκώσει λιγότερο το κινητό μέχρι τα μεσάνυχτα κερδίζει.",
                    "Wer bis Mitternacht sein Handy seltener greift, gewinnt."
                ))
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }

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

    // MARK: - Sent Pending

    private func sentPendingCard(_ duel: DuelRecord) -> some View {
        VStack(spacing: 20) {
            Text("⏳")
                .font(.system(size: 56))

            VStack(spacing: 6) {
                Text(t("Waiting for \(firstName)…",
                       "Αναμένεται ο \(firstName)…",
                       "Warten auf \(firstName)…"))
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(t(
                    "Your duel invite has been sent.",
                    "Η πρόκλησή σου έχει σταλεί.",
                    "Deine Duell-Einladung wurde gesendet."
                ))
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }

            Button(action: { Task { await duelManager.cancelSentDuel(duel) } }) {
                Text(t("Cancel invite", "Ακύρωση πρόσκλησης", "Einladung absagen"))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
    }

    // MARK: - Incoming Invite

    private func incomingInviteCard(_ duel: DuelRecord) -> some View {
        VStack(spacing: 20) {
            Text("🔔")
                .font(.system(size: 56))

            VStack(spacing: 6) {
                Text(t("\(firstName) challenges you!",
                       "Ο \(firstName) σε προκαλεί!",
                       "\(firstName) fordert dich heraus!"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(t(
                    "Whoever picks up less by midnight wins.",
                    "Όποιος σηκώσει λιγότερο μέχρι τα μεσάνυχτα κερδίζει.",
                    "Wer bis Mitternacht seltener greift, gewinnt."
                ))
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: { Task { await duelManager.acceptDuel(duel, myName: myDisplayName) }}) {
                    Text(t("Accept Duel ⚔️", "Αποδοχή ⚔️", "Annehmen ⚔️"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
                }

                Button(action: { Task { await duelManager.declineDuel(duel) }}) {
                    Text(t("Decline", "Απόρριψη", "Ablehnen"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
    }

    // MARK: - Active Duel

    private func activeDuelCard(_ duel: DuelRecord) -> some View {
        VStack(spacing: 24) {

            // Countdown
            if duel.secondsRemaining > 0 {
                VStack(spacing: 4) {
                    Text(formattedCountdown(duel.secondsRemaining))
                        .font(.system(size: 36, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue)
                    Text(t("remaining today", "απομένουν σήμερα", "noch heute"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            // Scoreboard
            HStack(spacing: 0) {
                // Me
                scoreColumn(
                    label: t("You", "Εσύ", "Du"),
                    pickups: duel.myPickups,
                    isLeading: duel.myPickups <= duel.theirPickups,
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
                    pickups: duel.theirPickups,
                    isLeading: duel.theirPickups < duel.myPickups,
                    highlight: false
                )
            }
            .padding(.vertical, 8)

            Text(t(
                "Fewer pickups = winner 🏆",
                "Λιγότερα σηκώματα = νίκη 🏆",
                "Weniger Griffe = Sieg 🏆"
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
                    Text(t("They picked up less than you today. Try again tomorrow!", "Σήκωσαν λιγότερο από εσένα σήμερα. Προσπάθησε αύριο!", "Sie haben heute seltener gegriffen. Versuch's morgen nochmal!"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Final score
            HStack(spacing: 0) {
                scoreColumn(label: t("You", "Εσύ", "Du"), pickups: duel.myPickups, isLeading: duel.iWon, highlight: true)
                Text("VS").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.secondary).frame(width: 40)
                scoreColumn(label: firstName, pickups: duel.theirPickups, isLeading: duel.iLost, highlight: false)
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

    private func scoreColumn(label: String, pickups: Int, isLeading: Bool, highlight: Bool) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(highlight ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text("\(pickups)")
                .font(.system(size: 44, weight: .medium, design: .rounded))
                .foregroundColor(isLeading ? .blue : .primary)

            Text(t("pickups", "σηκώματα", "Griffe"))
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)

            if isLeading && pickups >= 0 {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
            }
        }
        .frame(maxWidth: .infinity)
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
