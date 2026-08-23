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
            Item(emoji: "⚔️",
                 title: t("Duels on screen time", "Μονομαχίες στον χρόνο", "Duelle bei der Bildschirmzeit"),
                 body: t("Challenge friends — least screen time by midnight wins. Fair and accurate.",
                         "Προκάλεσε φίλους — ο λιγότερος χρόνος μέχρι τα μεσάνυχτα νικάει. Δίκαιο & ακριβές.",
                         "Fordere Freunde heraus — am wenigsten Bildschirmzeit gewinnt. Fair & genau.")),
            Item(emoji: "🛡️",
                 title: t("Smart limits", "Έξυπνα όρια", "Smarte Limits"),
                 body: t("Set a daily limit and Picksy locks the apps that eat your time.",
                         "Βάλε ημερήσιο όριο και το Picksy κλειδώνει τις apps που σου τρώνε χρόνο.",
                         "Setze ein Tageslimit und Picksy sperrt die zeitfressenden Apps.")),
            Item(emoji: "🎯",
                 title: t("Apple-accurate pickups", "Ακριβή σηκώματα από την Apple", "Apple-genaue Griffe"),
                 body: t("On by default — Settings → Pickup number lets you switch to live counting instead.",
                         "Ενεργό από προεπιλογή — Ρυθμίσεις → Αριθμός σηκωμάτων για εναλλαγή σε ζωντανή μέτρηση.",
                         "Standardmäßig aktiv — in Einstellungen → Griff-Anzahl auf Live-Zählung umschaltbar.")),
            Item(emoji: "👨‍👩‍👧",
                 title: t("Family passcode", "Γονικός κωδικός", "Eltern-Code"),
                 body: t("Hand your kid the phone for a set time, locked behind your passcode.",
                         "Δώσε το κινητό στο παιδί για συγκεκριμένο χρόνο, κλειδωμένο με κωδικό.",
                         "Gib dem Kind das Handy für eine feste Zeit, mit deinem Code gesperrt.")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)

            VStack(spacing: 8) {
                Text("🎉").font(.system(size: 48))
                Text(t("What's new in Picksy 2.0", "Τι νέο στο Picksy 2.0", "Neu in Picksy 2.0"))
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
