// TournamentView.swift
// Picksy
//
// Leaderboard view for a single group tournament.

import SwiftUI

struct TournamentView: View {
    let tournament: TournamentRecord
    let participants: [TournamentParticipant]
    let onLeave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private func t(_ en: String, _ gr: String) -> String {
        appLanguage == "Ελληνικά" ? gr : en
    }

    private var sorted: [TournamentParticipant] {
        participants.sorted { $0.effectiveScore < $1.effectiveScore }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Text("⚔️")
                    .font(.system(size: 36))
                Text(tournament.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                HStack(spacing: 16) {
                    Label(t("\(tournament.daysRemaining)d left", "\(tournament.daysRemaining) μέρες"), systemImage: "clock")
                    Label(t("\(participants.count) players", "\(participants.count) παίκτες"), systemImage: "person.2")
                }
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)

                // Invite code pill
                HStack(spacing: 6) {
                    Text(t("Code:", "Κωδικός:"))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(tournament.inviteCode)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                    ShareLink(
                        item: shareText,
                        label: { Image(systemName: "square.and.arrow.up").font(.system(size: 14)) }
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(.systemGray5)))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Divider()

            // Leaderboard
            if sorted.isEmpty {
                Spacer()
                Text(t("No participants yet", "Δεν υπάρχουν συμμετέχοντες ακόμα"))
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15, design: .rounded))
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, participant in
                            ParticipantRow(rank: index + 1, participant: participant)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(t("Leave", "Αποχώρηση")) { dismiss(); onLeave() }
                    .foregroundStyle(.red)
                    .font(.system(size: 15, design: .rounded))
            }
        }
    }

    private var shareText: String {
        t(
            "I'm in a weekly screen time tournament on Picksy! Join my group with code \(tournament.inviteCode)\n\nDownload Picksy 👉 https://apps.apple.com/app/picksy-be-present/id6761116771",
            "Είμαι σε εβδομαδιαία μονομαχία screen time στο Picksy! Μπες στην ομάδα μου με κωδικό \(tournament.inviteCode)\n\nΚατέβασε το Picksy 👉 https://apps.apple.com/app/picksy-be-present/id6761116771"
        )
    }
}

// MARK: - Participant Row

private struct ParticipantRow: View {
    let rank: Int
    let participant: TournamentParticipant

    var body: some View {
        HStack(spacing: 14) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                if rank <= 3 {
                    Text(rankEmoji)
                        .font(.system(size: 20))
                } else {
                    Text("\(rank)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(rankColor)
                }
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(participant.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    if participant.isMe {
                        Text("you")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue))
                    }
                }
                if participant.penaltySeconds > 0 {
                    Text("+ \(formatDuration(participant.penaltySeconds)) handicap")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Score
            Text(participant.formattedScore)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(rank == 1 ? Color.green : Color.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(participant.isMe ? Color.blue.opacity(0.08) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(participant.isMe ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var rankEmoji: String {
        switch rank { case 1: return "🥇"; case 2: return "🥈"; case 3: return "🥉"; default: return "" }
    }

    private var rankColor: Color {
        switch rank { case 1: return .yellow; case 2: return .gray; case 3: return .orange; default: return .secondary }
    }
}

// MARK: - Helper

private func formatDuration(_ seconds: Int) -> String {
    let s = max(0, seconds)
    if s < 60 { return "0m" }
    let h = s / 3600
    let m = (s % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}
