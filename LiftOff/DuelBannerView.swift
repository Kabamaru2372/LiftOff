// DuelBannerView.swift
// Picksy
//
// Shown on the Stats (Dashboard) tab.
// Analytics: win rate, streak, per-opponent breakdown + full history.

import SwiftUI

struct DuelBannerView: View {

    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private var duelManager: DuelManager { DuelManager.shared }

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    // MARK: - Computed analytics

    private var history: [DuelRecord] { duelManager.duelHistory }

    private var wins:   Int { history.filter { $0.iWon   }.count }
    private var losses: Int { history.filter { $0.iLost  }.count }
    private var ties:   Int { history.filter { $0.isTie  }.count }
    private var total:  Int { wins + losses + ties }
    private var winRate: Double { total > 0 ? Double(wins) / Double(total) : 0 }

    /// Consecutive wins or losses from the newest duel
    private var streakInfo: (count: Int, isWin: Bool) {
        guard let first = history.first, !first.isTie else { return (0, true) }
        let isWin = first.iWon
        var count = 0
        for duel in history {
            if duel.isTie { count += 1; continue }   // ties don't break streak
            if duel.iWon == isWin { count += 1 }
            else { break }
        }
        return (count, isWin)
    }

    /// Per-opponent: name → (wins, losses, ties, lastDate)
    private var opponentRecords: [(name: String, w: Int, l: Int, t: Int, last: Date)] {
        let grouped = Dictionary(grouping: history, by: { $0.theirName })
        return grouped.map { name, duels in
            let w = duels.filter { $0.iWon  }.count
            let l = duels.filter { $0.iLost }.count
            let t = duels.filter { $0.isTie }.count
            let last = duels.map(\.createdAt).max() ?? .distantPast
            return (name: name, w: w, l: l, t: t, last: last)
        }
        .sorted { $0.last > $1.last }   // most recent first
    }

    // MARK: - Body

    var body: some View {
        if !history.isEmpty {
            VStack(spacing: 12) {
                analyticsCard
                historySection
            }
        }
    }

    // MARK: - Analytics Card

    private var analyticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Section label
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(t("DUEL STATS · 7 DAYS", "ΣΤΑΤΙΣΤΙΚΑ ΜΟΝΟΜΑΧΙΩΝ · 7 ΜΕΡΕΣ", "DUELL-STATS · 7 TAGE"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
            }

            // Win rate + streak side by side
            HStack(spacing: 12) {

                // Win rate ring
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 5)
                            .frame(width: 52, height: 52)
                        Circle()
                            .trim(from: 0, to: max(CGFloat(winRate), winRate > 0 ? 0.04 : 0))
                            .stroke(
                                winRate >= 0.5 ? Color.green : Color.orange,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.6), value: winRate)
                        Text(total > 0 ? "\(Int(winRate * 100))%" : "—")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("Win rate", "Ποσοστό νικών", "Siegrate"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                        Text("\(wins)W · \(losses)L\(ties > 0 ? " · \(ties)T" : "")")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))

                // Streak
                let streak = streakInfo
                VStack(spacing: 3) {
                    Text(streak.count > 0 ? (streak.isWin ? "🔥" : "💪") : "➖")
                        .font(.system(size: 22))
                    if streak.count > 1 {
                        Text("\(streak.count) \(streak.isWin ? t("wins", "νίκες", "Siege") : t("losses", "ήττες", "Niederlagen"))")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(streak.isWin ? .green : .orange)
                        Text(t("in a row", "στη σειρά", "hintereinander"))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        Text(t("No streak", "Χωρίς σερί", "Keine Serie"))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            }

            // Per-opponent breakdown
            if opponentRecords.count > 0 {
                VStack(spacing: 6) {
                    ForEach(opponentRecords, id: \.name) { rec in
                        HStack(spacing: 8) {
                            Text(rec.w > rec.l ? "🏆" : (rec.l > rec.w ? "📱" : "🤝"))
                                .font(.system(size: 13))
                            Text("vs \(rec.name)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                            Spacer()
                            Text("\(rec.w)W · \(rec.l)L\(rec.t > 0 ? " · \(rec.t)T" : "")")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                            // Mini win-rate bar
                            let total = rec.w + rec.l + rec.t
                            let frac  = total > 0 ? CGFloat(rec.w) / CGFloat(total) : 0
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color(.systemGray5)).frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(rec.w >= rec.l ? Color.green.opacity(0.7) : Color.orange.opacity(0.7))
                                        .frame(width: max(geo.size.width * frac, 2), height: 4)
                                }
                            }
                            .frame(width: 48, height: 4)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - History Section (full list)

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(t("HISTORY", "ΙΣΤΟΡΙΚΟ", "VERLAUF"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            ForEach(Array(history.prefix(7).enumerated()), id: \.element.id) { idx, duel in
                historyRow(duel, isLast: idx == min(history.count, 7) - 1)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    private func historyRow(_ duel: DuelRecord, isLast: Bool) -> some View {
        let icon      = duel.isTie ? "🤝" : (duel.iWon ? "🏆" : "📱")
        let myColor   = duel.iWon  ? Color.green : (duel.iLost ? Color.red : Color.primary)
        let theirColor = duel.iLost ? Color.green : (duel.iWon  ? Color.red : Color.primary)

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(icon).font(.system(size: 22))

                VStack(alignment: .leading, spacing: 2) {
                    Text(t("vs \(duel.theirName)", "με \(duel.theirName)", "vs. \(duel.theirName)"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    Text(relativeDate(duel.createdAt))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                let myD    = (duel.myScore == 0 && duel.theirScore > 0) ? "?" : "\(duel.myScore)"
                let theirD = (duel.theirScore == 0 && duel.myScore > 0) ? "?" : "\(duel.theirScore)"
                HStack(spacing: 3) {
                    Text(myD).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(myColor)
                    Text("–").font(.system(size: 13, design: .rounded)).foregroundColor(.secondary)
                    Text(theirD).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(theirColor)
                }

                Text(duel.isTie ? t("Tie","Ισοπαλία","Unentsch.") : (duel.iWon ? t("Won","Νίκη","Sieg") : t("Lost","Ήττα","Niederlage")))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(duel.isTie ? .secondary : (duel.iWon ? .green : .red))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(
                        duel.isTie ? Color.secondary.opacity(0.1) : (duel.iWon ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    ))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast { Divider().padding(.leading, 52) }
        }
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return t("Today", "Σήμερα", "Heute") }
        if days == 1 { return t("Yesterday", "Χθες", "Gestern") }
        return t("\(days) days ago", "Πριν \(days) μέρες", "Vor \(days) Tagen")
    }
}
