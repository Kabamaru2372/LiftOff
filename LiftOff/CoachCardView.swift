// CoachCardView.swift
// Picksy
//
// Dynamic daily coach message based on the user's actual data.
// Shows a personalised, human insight at the top of the Stats tab.

import SwiftUI

struct CoachCardView: View {

    let todayPickups: Int
    let weeklyPickups: [Int]   // [Mon…Sun] weekly data
    let streak: Int
    let goal: Int
    let worstHours: [(hour: Int, avgPickups: Double)]
    let language: String

    // MARK: - Helpers

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    /// 7-day average, ignoring zero days (untracked)
    private var weeklyAvg: Int {
        let nonZero = weeklyPickups.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(0, +) / nonZero.count
    }

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch language {
        case "Ελληνικά": return gr
        case "Deutsch":   return de
        default:          return en
        }
    }

    // MARK: - Insight

    private var insight: (emoji: String, title: String, message: String, color: Color) {
        let hour  = currentHour
        let avg   = weeklyAvg
        let ratio = avg > 0 ? Double(todayPickups) / Double(avg) : 0
        let isEvening = hour >= 18
        let isMorning  = hour < 10

        // Upcoming peak hour (avg ≥ 2 pickups, still ahead today)
        let upcomingPeak = worstHours.first(where: { $0.hour > hour && $0.avgPickups >= 2 })

        // ── Fresh start ──────────────────────────────────────────────
        if todayPickups == 0 && isMorning {
            return ("🌅",
                    t("Fresh start", "Καθαρή αρχή", "Frischer Start"),
                    t("Your goal today: stay under \(goal) pickups. You've got this.",
                      "Στόχος σήμερα: κάτω από \(goal) σηκώματα. Μπορείς!",
                      "Dein Ziel heute: unter \(goal) Griffe. Du schaffst das."),
                    .blue)
        }

        // ── Way above average (≥ 2×) ─────────────────────────────────
        if ratio >= 2.0 && todayPickups > 8 {
            let multiple = Int(ratio.rounded())
            if let peak = upcomingPeak {
                let hrs = peak.hour - hour
                return ("⚡",
                        t("Tough day", "Δύσκολη μέρα", "Schwerer Tag"),
                        t("You're \(multiple)× your usual average. Your peak hour hits in \(hrs)h — stay mindful.",
                          "Είσαι \(multiple)× πάνω από τον μέσο σου. Δύσκολη ώρα σε \(hrs)h.",
                          "Du bist \(multiple)× über Schnitt. Peak-Stunde in \(hrs)h — bleib achtsam."),
                        .orange)
            }
            return ("⚡",
                    t("Tough day", "Δύσκολη μέρα", "Schwerer Tag"),
                    t("You're \(multiple)× your weekly average. Deep breaths — the day isn't over.",
                      "Είσαι \(multiple)× πάνω από τον εβδομαδιαίο μέσο σου. Η μέρα δεν τελείωσε.",
                      "Du bist \(multiple)× über deinem Wochenschnitt. Noch ist der Tag nicht vorbei."),
                    .orange)
        }

        // ── Great streak + on track ──────────────────────────────────
        if streak >= 5 && todayPickups <= goal {
            return ("🔥",
                    t("\(streak)-day streak!", "\(streak) μέρες σερί!", "\(streak)-Tage-Serie!"),
                    isEvening
                        ? t("Almost there — finish strong tonight.",
                            "Σχεδόν τελείωσες — δυνατό φινάλε απόψε.",
                            "Fast geschafft — stark durch den Abend.")
                        : t("You're in a great flow. Keep going.",
                            "Είσαι σε ρυθμό. Συνέχισε έτσι.",
                            "Du bist im Flow. Mach weiter so."),
                    .orange)
        }

        // ── Crushing it (≤ half goal) ────────────────────────────────
        if todayPickups > 0 && todayPickups <= goal / 2 {
            if let peak = upcomingPeak {
                let hrs = peak.hour - hour
                return ("💪",
                        t("Looking great!", "Τέλεια πορεία!", "Gut unterwegs!"),
                        t("Only \(todayPickups) pickups so far. Heads up — peak hour in \(hrs)h.",
                          "Μόνο \(todayPickups) σηκώματα. Προσοχή — δύσκολη ώρα σε \(hrs)h.",
                          "Nur \(todayPickups) Griffe. Achtung — Peak in \(hrs)h."),
                        .green)
            }
            return ("💪",
                    t("Looking great!", "Τέλεια πορεία!", "Gut unterwegs!"),
                    t("Only \(todayPickups) pickups so far. Stay focused!",
                      "Μόνο \(todayPickups) σηκώματα μέχρι τώρα. Συνέχισε!",
                      "Nur \(todayPickups) Griffe bisher. Bleib fokussiert!"),
                    .green)
        }

        // ── On track (≤ goal) ────────────────────────────────────────
        if todayPickups <= goal {
            let remaining = goal - todayPickups
            return ("✅",
                    t("On track", "Στο σωστό δρόμο", "Auf Kurs"),
                    t("\(remaining) more pickups until you reach your goal.",
                      "\(remaining) σηκώματα ακόμα μέχρι τον στόχο σου.",
                      "Noch \(remaining) Griffe bis zu deinem Ziel."),
                    .blue)
        }

        // ── Over goal ────────────────────────────────────────────────
        let over = todayPickups - goal
        return ("💡",
                isEvening
                    ? t("Almost done", "Σχεδόν τελειώσαμε", "Fast fertig")
                    : t("Keep going", "Συνέχισε", "Weiter"),
                isEvening
                    ? t("\(over) over today's goal. Tomorrow is a fresh start.",
                        "\(over) πάνω από τον στόχο. Αύριο ξεκινάς από μηδέν.",
                        "\(over) über dem Tagesziel. Morgen ist ein neuer Anfang.")
                    : t("\(over) over your goal — but there's still time. Slow down.",
                        "\(over) πάνω από τον στόχο — αλλά υπάρχει ακόμα χρόνος. Χαλάρωσε.",
                        "\(over) über dem Ziel — aber noch Zeit. Bleib ruhig."),
                .purple)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            Text(insight.emoji)
                .font(.system(size: 28))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text(insight.message)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(insight.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(insight.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 14) {
            // Morning, nothing yet
            CoachCardView(todayPickups: 0, weeklyPickups: [12, 15, 8, 10, 0, 0, 0],
                          streak: 0, goal: 15, worstHours: [], language: "English")
            // Crushing it
            CoachCardView(todayPickups: 4, weeklyPickups: [12, 15, 8, 10, 0, 0, 0],
                          streak: 7, goal: 15, worstHours: [(hour: 22, avgPickups: 4)], language: "English")
            // On track
            CoachCardView(todayPickups: 10, weeklyPickups: [12, 15, 8, 10, 0, 0, 0],
                          streak: 12, goal: 15, worstHours: [], language: "English")
            // Tough day
            CoachCardView(todayPickups: 38, weeklyPickups: [12, 15, 8, 10, 0, 0, 0],
                          streak: 0, goal: 15, worstHours: [(hour: 22, avgPickups: 8)], language: "English")
            // Over goal, evening
            CoachCardView(todayPickups: 22, weeklyPickups: [12, 15, 8, 10, 0, 0, 0],
                          streak: 2, goal: 15, worstHours: [], language: "English")
        }
        .padding(24)
    }
}
