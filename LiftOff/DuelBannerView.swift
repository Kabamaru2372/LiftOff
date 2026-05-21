// DuelBannerView.swift
// Picksy
//
// Compact duel card shown on the Dashboard whenever there is an
// active, incoming, or just-completed duel. Tapping it opens DuelView.

import SwiftUI
import Combine

struct DuelBannerView: View {

    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @Environment(DataStore.self) private var store

    private var duelManager: DuelManager { DuelManager.shared }
    private var friendSync: FriendSyncManager { FriendSyncManager.shared }

    @State private var tick: Date = Date()
    @State private var showDuelSheet: Bool = false

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
        Group {
            if let duel = duelManager.activeDuel {
                banner(for: duel)
            } else if let invite = duelManager.pendingInvite {
                incomingBanner(invite)
            }
            // sentPendingDuel: no banner — opponent hasn't accepted yet, no score to show
        }
        .onReceive(timer) { _ in tick = Date() }
        .sheet(isPresented: $showDuelSheet) {
            if let pair = activePair {
                DuelView(pair: pair)
                    .environment(store)
            }
        }
    }

    // MARK: - Active / Completed Banner

    @ViewBuilder
    private func banner(for duel: DuelRecord) -> some View {
        Button(action: { showDuelSheet = true }) {
            HStack(spacing: 14) {

                // Icon
                Text(duel.status == .completed
                     ? (duel.iWon ? "🏆" : (duel.isTie ? "🤝" : "📱"))
                     : "⚔️")
                    .font(.system(size: 28))

                // Middle: opponent + score
                VStack(alignment: .leading, spacing: 3) {
                    Text(duel.status == .active
                         ? t("Duel vs \(duel.theirName)", "Duel με \(duel.theirName)", "Duell vs. \(duel.theirName)")
                         : t("Duel result", "Αποτέλεσμα Duel", "Duell-Ergebnis"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    if duel.status == .active {
                        HStack(spacing: 4) {
                            Text(t("You \(duel.myPickups)", "Εσύ \(duel.myPickups)", "Du \(duel.myPickups)"))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(duel.myPickups <= duel.theirPickups ? .blue : .secondary)
                            Text("·")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            Text("\(duel.theirName) \(duel.theirPickups)")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(duel.theirPickups < duel.myPickups ? .blue : .secondary)
                        }
                    } else {
                        // completed
                        Text(duel.isTie
                             ? t("Tie — equally disciplined", "Ισοπαλία!", "Unentschieden!")
                             : (duel.iWon
                                ? t("You won! 🎉", "Κέρδισες! 🎉", "Du hast gewonnen! 🎉")
                                : t("\(duel.theirName) won", "\(duel.theirName) κέρδισε", "\(duel.theirName) gewann")))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Right: countdown or final scores
                if duel.status == .active, duel.secondsRemaining > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedCountdown(duel.secondsRemaining))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)
                        Text(t("left", "απομένει", "übrig"))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                } else if duel.status == .completed {
                    HStack(spacing: 4) {
                        Text("\(duel.myPickups)")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(duel.iWon ? .blue : .secondary)
                        Text("–")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("\(duel.theirPickups)")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(duel.iLost ? .blue : .secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        duel.status == .active ? Color.blue.opacity(0.25) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Incoming Invite Banner

    private func incomingBanner(_ duel: DuelRecord) -> some View {
        Button(action: { showDuelSheet = true }) {
            HStack(spacing: 14) {
                Text("🔔")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 3) {
                    Text(t("\(duel.theirName) challenges you!", "\(duel.theirName) σε προκαλεί!", "\(duel.theirName) fordert dich heraus!"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(t("Tap to accept the duel", "Πάτησε για να αποδεχτείς", "Tippe zum Annehmen"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(t("Accept", "Αποδοχή", "Annehmen"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.blue))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// Finds the RegisteredPair that matches the active/pending duel.
    private var activePair: RegisteredPair? {
        let opponentID: String?
        if let duel = duelManager.activeDuel {
            opponentID = duel.amChallenger ? duel.opponentId : duel.challengerId
        } else if let invite = duelManager.pendingInvite {
            opponentID = invite.challengerId
        } else {
            return nil
        }
        return friendSync.registeredPairs.first { $0.deviceID == opponentID }
            ?? RegisteredPair(deviceID: opponentID ?? "", name: "Friend", registeredAt: Date())
    }

    private func formattedCountdown(_ secs: TimeInterval) -> String {
        let total = max(0, Int(secs))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
