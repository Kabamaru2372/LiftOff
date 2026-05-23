// DuelBannerView.swift
// Picksy
//
// Shown on the Stats (Dashboard) tab.
// Active duels live in the Friends tab now — this view shows:
//   1. Incoming pending invite (if any) — still needs action
//   2. Completed duel history (last 7 days)

import SwiftUI
import Combine

struct DuelBannerView: View {

    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @Environment(DataStore.self) private var store

    private var duelManager: DuelManager { DuelManager.shared }
    private var friendSync:  FriendSyncManager { FriendSyncManager.shared }

    @State private var showDuelSheet: Bool = false

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {

            // Incoming invite — still needs action, so keep it here too
            if let invite = duelManager.pendingInvite {
                incomingBanner(invite)
            }

            // Completed duel history
            if !duelManager.duelHistory.isEmpty {
                historySection
            }
        }
        .sheet(isPresented: $showDuelSheet) {
            if let pair = invitePair {
                DuelView(pair: pair)
                    .environment(store)
            }
        }
    }

    // MARK: - Incoming Invite Banner

    private func incomingBanner(_ duel: DuelRecord) -> some View {
        Button(action: { showDuelSheet = true }) {
            HStack(spacing: 14) {
                Text("🔔")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 3) {
                    Text(t(
                        "\(duel.theirName) challenges you!",
                        "\(duel.theirName) σε προκαλεί!",
                        "\(duel.theirName) fordert dich heraus!"
                    ))
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

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(t("DUEL HISTORY · 7 DAYS", "ΙΣΤΟΡΙΚΟ ΜΟΝΟΜΑΧΙΩΝ · 7 ΜΕΡΕΣ", "DUELL-VERLAUF · 7 TAGE"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            ForEach(Array(duelManager.duelHistory.prefix(5).enumerated()), id: \.element.id) { idx, duel in
                historyRow(duel, isLast: idx == min(duelManager.duelHistory.count, 5) - 1)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    private func historyRow(_ duel: DuelRecord, isLast: Bool) -> some View {
        let icon   = duel.isTie ? "🤝" : (duel.iWon ? "🏆" : "📱")
        let myC    = duel.myPickups
        let theirC = duel.theirPickups
        let myColor: Color   = duel.iWon ? Color(red: 0.2, green: 0.78, blue: 0.4) : (duel.iLost ? Color(red: 1.0, green: 0.3, blue: 0.3) : .primary)
        let theirColor: Color = duel.iLost ? Color(red: 0.2, green: 0.78, blue: 0.4) : (duel.iWon ? Color(red: 1.0, green: 0.3, blue: 0.3) : .primary)

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(icon)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 2) {
                    Text(t(
                        "vs \(duel.theirName)",
                        "με \(duel.theirName)",
                        "vs. \(duel.theirName)"
                    ))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)

                    Text(relativeDate(duel.createdAt))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Score — show "?" when a side never synced (stayed at 0 while other played)
                let myDisplay    = (myC == 0 && theirC > 0) ? "?" : "\(myC)"
                let theirDisplay = (theirC == 0 && myC > 0) ? "?" : "\(theirC)"
                HStack(spacing: 3) {
                    Text(myDisplay)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(myC == 0 && theirC > 0 ? .secondary : myColor)
                    Text("–")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(theirDisplay)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(theirC == 0 && myC > 0 ? .secondary : theirColor)
                }

                // Result label
                Text(duel.isTie
                     ? t("Tie", "Ισοπαλία", "Unentschieden")
                     : (duel.iWon
                        ? t("Won", "Νίκη", "Sieg")
                        : t("Lost", "Ήττα", "Niederlage")))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(duel.isTie ? .secondary : (duel.iWon ? Color(red: 0.2, green: 0.78, blue: 0.4) : Color(red: 1.0, green: 0.3, blue: 0.3)))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(
                        duel.isTie ? Color.secondary.opacity(0.1)
                            : (duel.iWon ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    ))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider().padding(.leading, 52)
            }
        }
    }

    // MARK: - Helpers

    private var invitePair: RegisteredPair? {
        guard let invite = duelManager.pendingInvite else { return nil }
        return friendSync.registeredPairs.first { $0.deviceID == invite.challengerId }
            ?? RegisteredPair(deviceID: invite.challengerId, name: invite.theirName, registeredAt: Date())
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return t("Today", "Σήμερα", "Heute") }
        if days == 1 { return t("Yesterday", "Χθες", "Gestern") }
        return t("\(days) days ago", "Πριν \(days) μέρες", "Vor \(days) Tagen")
    }
}
