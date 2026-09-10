//
//  WhatsNewView.swift
//  Picksy
//
//  Shown ONCE to existing users after they upgrade to a new major version, so
//  they understand what changed — without redoing the full onboarding (which
//  would re-request permissions). New installs never see this (they get the
//  onboarding instead).
//

import SwiftUI

struct WhatsNewView: View {
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    let onDismiss: () -> Void

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage { case "Ελληνικά": return gr; case "Deutsch": return de; default: return en }
    }

    private struct Item: Identifiable { let id = UUID(); let emoji, title, body: String }

    private var items: [Item] {
        [
            Item(emoji: "🌱",
                 title: t("Your plant", "Το φυτό σου", "Deine Pflanze"),
                 body: t("A living plant on the Dynamic Island and Nudge screen — it grows the longer your phone stays down, and wilts while you're using it.",
                         "Ένα ζωντανό φυτό στο Dynamic Island και την οθόνη Nudge — μεγαλώνει όσο αφήνεις το κινητό κάτω, και μαραίνεται όσο το χρησιμοποιείς.",
                         "Eine lebendige Pflanze auf der Dynamic Island und dem Nudge-Bildschirm — sie wächst, solange das Handy liegen bleibt, und welkt, während du es benutzt.")),
            Item(emoji: "🎯",
                 title: t("Numbers that match Settings", "Νούμερα που ταιριάζουν με τις Ρυθμίσεις", "Zahlen wie in den Einstellungen"),
                 body: t("Pickups and screen time now come straight from Apple's Screen Time. Toggle in Settings → Pickup number.",
                         "Τα σηκώματα και ο χρόνος οθόνης έρχονται πλέον απευθείας από το Screen Time της Apple. Εναλλαγή στις Ρυθμίσεις → Αριθμός σηκωμάτων.",
                         "Griffe und Bildschirmzeit kommen jetzt direkt aus Apples Bildschirmzeit. Umschalten in Einstellungen → Griff-Anzahl.")),
            Item(emoji: "🤔",
                 title: t("Why did you pick up?", "Γιατί το έπιασες;", "Warum hast du gegriffen?"),
                 body: t("Now and then Picksy asks the reason — building awareness of the habit without blocking anything.",
                         "Πού και πού το Picksy ρωτάει τον λόγο — χτίζει επίγνωση της συνήθειας χωρίς να μπλοκάρει τίποτα.",
                         "Ab und zu fragt Picksy nach dem Grund — schafft Bewusstsein für die Gewohnheit, ohne etwas zu blockieren.")),
            Item(emoji: "🏅",
                 title: t("Weekly tournaments", "Εβδομαδιαία τουρνουά", "Wochen-Turniere"),
                 body: t("Compete with a group over a week — the lowest screen time climbs the leaderboard.",
                         "Διαγωνίσου με μια ομάδα για μία εβδομάδα — ο λιγότερος χρόνος οθόνης ανεβαίνει στον πίνακα.",
                         "Tritt eine Woche lang gegen eine Gruppe an — die wenigste Bildschirmzeit klettert die Bestenliste hoch.")),
            Item(emoji: "🔕",
                 title: t("Quieter", "Πιο διακριτικό", "Leiser"),
                 body: t("Fewer notifications — the midday and afternoon check-ins are gone.",
                         "Λιγότερες ειδοποιήσεις — τα μεσημεριανά check-in αφαιρέθηκαν.",
                         "Weniger Mitteilungen — die Mittags-Check-ins sind weg.")),
            Item(emoji: "⚡",
                 title: t("Faster and steadier", "Πιο γρήγορο & σταθερό", "Schneller & stabiler"),
                 body: t("Fixes for the midnight reset, the Dynamic Island going blank, false phone-time alerts during music, and several crashes.",
                         "Διορθώσεις για το reset στα μεσάνυχτα, το Dynamic Island που έσβηνε, ψεύτικες ειδοποιήσεις ώρας ενώ ακούς μουσική, και αρκετά crashes.",
                         "Behebt den Mitternachts-Reset, die leere Dynamic Island, falsche Zeit-Warnungen bei Musik und mehrere Abstürze.")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)

            VStack(spacing: 8) {
                Text("🎉").font(.system(size: 48))
                Text(t("What's new in Picksy 2.1", "Τι νέο στο Picksy 2.1", "Neu in Picksy 2.1"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(t("Picksy doesn't just track — it helps you actually use your phone less.",
                       "Το Picksy δεν μετράει απλά — σε βοηθάει να χρησιμοποιείς λιγότερο το κινητό.",
                       "Picksy zählt nicht nur — es hilft dir, das Handy weniger zu nutzen."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
            }
            .padding(.bottom, 24)

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Text(item.emoji).font(.system(size: 26)).frame(width: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(item.body)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
                    }
                }
                .padding(.horizontal, 24)
            }

            Button(action: onDismiss) {
                Text(t("Let's go", "Πάμε", "Los geht's"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            Text(t("Find it all in Settings & the Friends tab.",
                   "Όλα στις Ρυθμίσεις & στο tab Φίλοι.",
                   "Alles in den Einstellungen & im Freunde-Tab."))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.bottom, 40)
        }
    }
}
