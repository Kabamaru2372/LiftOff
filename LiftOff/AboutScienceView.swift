//
//  AboutScienceView.swift
//  Picksy
//
//  Created by Fotios Pongas on 05.05.2026
//
//  In-app screen που εξηγεί την επιστήμη πίσω από το Picksy.
//  Περιλαμβάνει:
//    - Brief intro με dopamine narrative
//    - Zone breakdown με sources για κάθε zone
//    - Full citations με links σε εξωτερικές πηγές
//
//  Multilingual: EN/GR/DE
//  Παρουσιάζεται ως sheet από το SettingsView.
//

import SwiftUI

struct AboutScienceView: View {

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - Header
                    headerSection

                    // MARK: - Intro narrative
                    introSection

                    // MARK: - Zone breakdown
                    zonesSection

                    // MARK: - Picksy Score
                    picksyScoreSection

                    // MARK: - Why it matters
                    whyItMattersSection

                    // MARK: - Full citations
                    sourcesSection

                    // MARK: - Disclaimer
                    disclaimerSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle(t("Science", "Επιστήμη", "Wissenschaft"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text(t("Done", "Τέλος", "Fertig"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("🔬")
                .font(.system(size: 48))

            Text(t(
                "The science behind Picksy",
                "Η επιστήμη πίσω από το Picksy",
                "Die Wissenschaft hinter Picksy"
            ))
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)

            Text(t(
                "Research that shaped the zones",
                "Έρευνες που καθόρισαν τις ζώνες",
                "Forschung, die die Zonen geprägt hat"
            ))
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    // MARK: - Intro

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t(
                "Each pickup gives your brain a small dopamine hit. With 100+ pickups per day, you stay in a constant state of anticipation.",
                "Κάθε φορά που σηκώνεις το κινητό, το μυαλό σου παίρνει ένα μικρό \"hit\" ντοπαμίνης. Με 100+ σηκώματα/μέρα μένεις σε κατάσταση συνεχούς αναμονής.",
                "Jeder Griff zum Handy gibt deinem Gehirn einen kleinen Dopamin-Schub. Bei 100+ Griffen pro Tag bleibst du in einem ständigen Erwartungszustand."
            ))
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
            .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    // MARK: - Zones

    private var zonesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(t("The zones", "Οι ζώνες", "Die Zonen"))

            zoneCard(
                color: .green,
                name: t("Excellent (0-50)", "Εξαιρετικά (0-50)", "Ausgezeichnet (0-50)"),
                description: t(
                    "Mindful use. According to Rosen (2016), under 50 pickups is the healthy range for digital wellbeing.",
                    "Συνειδητή χρήση. Σύμφωνα με Rosen (2016), κάτω από 50 σηκώματα είναι το healthy range για ψηφιακή ευεξία.",
                    "Achtsame Nutzung. Laut Rosen (2016) sind unter 50 Griffe der gesunde Bereich für digitales Wohlbefinden."
                )
            )

            zoneCard(
                color: .yellow,
                name: t("Good (51-100)", "Καλή (51-100)", "Gut (51-100)"),
                description: t(
                    "Mainstream range. Acceptable but with room for improvement. Most people land here.",
                    "Mainstream εύρος. Αποδεκτό αλλά με room for improvement. Οι περισσότεροι εδώ.",
                    "Mainstream-Bereich. Akzeptabel, aber mit Verbesserungspotenzial. Die meisten Menschen liegen hier."
                )
            )

            zoneCard(
                color: .orange,
                name: t("Average (101-150)", "Μέτρια (101-150)", "Durchschnitt (101-150)"),
                description: t(
                    "Reviews.org (2026): average is 186/day. Korean study (2018): risk threshold around 110 pickups.",
                    "Reviews.org (2026): μέσος όρος 186/μέρα. Korean study (2018): risk threshold γύρω στα 110 σηκώματα.",
                    "Reviews.org (2026): Durchschnitt 186/Tag. Koreanische Studie (2018): Risikoschwelle bei ca. 110 Griffen."
                )
            )

            zoneCard(
                color: .red.opacity(0.85),
                name: t("Heavy (151-200)", "Έντονη (151-200)", "Intensiv (151-200)"),
                description: t(
                    "Heavy usage zone. Often correlated with reduced focus and increased anxiety according to recent reviews.",
                    "Ζώνη έντονης χρήσης. Συχνά συνδέεται με μειωμένη συγκέντρωση και αυξημένο άγχος σύμφωνα με πρόσφατες έρευνες.",
                    "Zone intensiver Nutzung. Oft mit reduzierter Konzentration und erhöhter Angst verbunden."
                )
            )

            zoneCard(
                color: .red,
                name: t("Problematic (200+)", "Προβληματική (200+)", "Problematisch (200+)"),
                description: t(
                    "Linked to increased anxiety and reduced focus (Nottingham Trent, 2020). Time to set boundaries.",
                    "Συνδέεται με αύξηση άγχους και μειωμένη συγκέντρωση (Nottingham Trent, 2020). Καιρός να βάλεις όρια.",
                    "Verbunden mit erhöhter Angst und reduzierter Konzentration (Nottingham Trent, 2020). Zeit für Grenzen."
                )
            )
        }
    }

    // MARK: - Picksy Score

    private var picksyScoreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(t("How the Picksy Score works", "Πώς υπολογίζεται το Picksy Score", "Wie der Picksy Score berechnet wird"))

            VStack(alignment: .leading, spacing: 14) {
                Text(t(
                    "The Picksy Score combines two metrics that research links to digital wellbeing: how often you pick up your phone AND how long you use it.",
                    "Το Picksy Score συνδυάζει δύο μετρικές που η έρευνα συνδέει με ψηφιακή ευεξία: πόσο συχνά σηκώνεις το κινητό ΚΑΙ πόση ώρα το χρησιμοποιείς.",
                    "Der Picksy Score kombiniert zwei Kennzahlen, die die Forschung mit digitalem Wohlbefinden verknüpft: wie oft du das Handy aufnimmst UND wie lange du es nutzt."
                ))
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.secondary)
                .lineSpacing(3)

                VStack(alignment: .leading, spacing: 6) {
                    Text(t("Formula", "Τύπος", "Formel"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("Score = pickups + (screen time minutes × 5)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                    Text(t(
                        "Lower = better. Screen time is weighted 5× more because duration of use is the stronger predictor of anxiety and depression.",
                        "Χαμηλότερο = καλύτερο. Ο χρόνος χρήσης βαρύνει 5× περισσότερο γιατί η διάρκεια χρήσης είναι ο ισχυρότερος προγνωστικός παράγοντας άγχους και κατάθλιψης.",
                        "Niedriger = besser. Die Bildschirmzeit wird 5× stärker gewichtet, da die Nutzungsdauer der stärkere Prädiktor für Angst und Depression ist."
                    ))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                }

                Divider()

                bulletRow(
                    icon: "📊",
                    text: t(
                        "Twenge et al. (2018, JAMA): Screen time duration (not just frequency) predicts depressive symptoms in adolescents — especially above 2h/day.",
                        "Twenge et al. (2018, JAMA): Η διάρκεια χρήσης (όχι μόνο η συχνότητα) προβλέπει καταθλιπτικά συμπτώματα — ιδίως πάνω από 2ω/μέρα.",
                        "Twenge et al. (2018, JAMA): Die Dauer der Bildschirmnutzung (nicht nur die Häufigkeit) sagt depressive Symptome voraus — besonders über 2h/Tag."
                    )
                )
                bulletRow(
                    icon: "🔬",
                    text: t(
                        "Przybylski & Weinstein (2017, Psychological Science): Both frequency AND duration independently predict reduced well-being — combining both metrics gives a more complete picture.",
                        "Przybylski & Weinstein (2017, Psychological Science): Συχνότητα ΚΑΙ διάρκεια προβλέπουν ανεξάρτητα μειωμένη ευεξία — ο συνδυασμός δίνει πληρέστερη εικόνα.",
                        "Przybylski & Weinstein (2017, Psychological Science): Sowohl Häufigkeit als auch Dauer sagen unabhängig verringerte Wohlbefinden voraus — die Kombination gibt ein vollständigeres Bild."
                    )
                )
                bulletRow(
                    icon: "⏱️",
                    text: t(
                        "Kushlev & Dunn (2015, Computers in Human Behavior): Reducing phone checking frequency reduced stress — but sessions lasting 30+ min had additional independent impact.",
                        "Kushlev & Dunn (2015, Computers in Human Behavior): Λιγότερα σηκώματα μείωσαν το άγχος — αλλά sessions 30+ λεπτά είχαν επιπλέον ανεξάρτητη επίδραση.",
                        "Kushlev & Dunn (2015, Computers in Human Behavior): Weniger Griffe reduzierten Stress — aber Sessions von 30+ Minuten hatten zusätzliche unabhängige Auswirkungen."
                    )
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }

    // MARK: - Why it matters

    private var whyItMattersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(t("Why pickups matter", "Γιατί τα σηκώματα μετράνε", "Warum Griffe wichtig sind"))

            VStack(alignment: .leading, spacing: 12) {
                bulletRow(
                    icon: "🧠",
                    text: t(
                        "Each pickup interrupts focus. It takes ~23 minutes to return to deep work after distraction.",
                        "Κάθε σήκωμα διακόπτει τη συγκέντρωση. Χρειάζονται ~23 λεπτά για επιστροφή σε deep work.",
                        "Jeder Griff unterbricht den Fokus. Es dauert ~23 Minuten, um zur tiefen Arbeit zurückzukehren."
                    )
                )
                bulletRow(
                    icon: "💭",
                    text: t(
                        "Frequent pickups train the brain to expect constant stimulation, increasing baseline anxiety.",
                        "Συχνά σηκώματα εκπαιδεύουν το μυαλό σε αναμονή συνεχούς ερεθίσματος, αυξάνοντας το άγχος.",
                        "Häufige Griffe trainieren das Gehirn auf ständige Stimulation und erhöhen die Grundangst."
                    )
                )
                bulletRow(
                    icon: "👨‍👩‍👧",
                    text: t(
                        "Parents with high pickups show measurable stress impact on children (PubMed, 2024).",
                        "Γονείς με υψηλά σηκώματα δείχνουν μετρήσιμη επίδραση άγχους στα παιδιά (PubMed, 2024).",
                        "Eltern mit vielen Griffen zeigen messbare Stress-Auswirkungen auf Kinder (PubMed, 2024)."
                    )
                )
                bulletRow(
                    icon: "💤",
                    text: t(
                        "Evening pickups before sleep are linked to poor sleep quality and shortened REM phases.",
                        "Βραδινά σηκώματα πριν τον ύπνο συνδέονται με κακή ποιότητα ύπνου και μικρότερες REM φάσεις.",
                        "Abendliche Griffe vor dem Schlaf werden mit schlechter Schlafqualität und kürzeren REM-Phasen in Verbindung gebracht."
                    )
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(t("Sources", "Πηγές", "Quellen"))

            sourceCard(
                title: "Twenge, J.M. et al. (2018)",
                subtitle: t(
                    "\"Increases in depressive symptoms linked to screen time\" — JAMA Pediatrics",
                    "\"Αύξηση καταθλιπτικών συμπτωμάτων σχετίζεται με screen time\" — JAMA Pediatrics",
                    "\"Anstieg depressiver Symptome im Zusammenhang mit Bildschirmzeit\" — JAMA Pediatrics"
                ),
                url: "https://jamanetwork.com/journals/jamapediatrics/fullarticle/2737909"
            )

            sourceCard(
                title: "Przybylski, A.K. & Weinstein, N. (2017)",
                subtitle: t(
                    "\"A Large-Scale Test of the Goldilocks Hypothesis\" — Psychological Science",
                    "\"Μεγάλης κλίμακας τεστ της υπόθεσης Goldilocks\" — Psychological Science",
                    "\"Großangelegter Test der Goldilocks-Hypothese\" — Psychological Science"
                ),
                url: "https://journals.sagepub.com/doi/10.1177/0956797616678438"
            )

            sourceCard(
                title: "Kushlev, K. & Dunn, E.W. (2015)",
                subtitle: t(
                    "\"Checking email less frequently reduces stress\" — Computers in Human Behavior",
                    "\"Λιγότερος έλεγχος email μειώνει το άγχος\" — Computers in Human Behavior",
                    "\"Weniger E-Mail-Checks reduzieren Stress\" — Computers in Human Behavior"
                ),
                url: "https://www.sciencedirect.com/science/article/pii/S074756321400283X"
            )

            sourceCard(
                title: "Rosen, L.D. et al. (2016)",
                subtitle: "\"The Distracted Mind: Ancient Brains in a High-Tech World\" — MIT Press",
                url: "https://mitpress.mit.edu/9780262534437/the-distracted-mind/"
            )

            sourceCard(
                title: t(
                    "Nottingham Trent University (2020)",
                    "Nottingham Trent University (2020)",
                    "Nottingham Trent University (2020)"
                ),
                subtitle: t(
                    "Systematic review on problematic smartphone use",
                    "Systematic review για προβληματική χρήση κινητού",
                    "Systematische Übersicht zur problematischen Smartphone-Nutzung"
                ),
                url: "https://pubmed.ncbi.nlm.nih.gov/32479002/"
            )

            sourceCard(
                title: "Keimyung University, Korea (2018)",
                subtitle: t(
                    "Identified ~110 pickups/day as high-risk threshold",
                    "Εντόπισε ~110 σηκώματα/μέρα ως high-risk threshold",
                    "Identifizierte ~110 Griffe/Tag als Hochrisiko-Schwelle"
                ),
                url: "https://pubmed.ncbi.nlm.nih.gov/29983115/"
            )

            sourceCard(
                title: "Reviews.org (2026)",
                subtitle: t(
                    "Annual smartphone usage study — average 186 daily pickups",
                    "Ετήσια έρευνα χρήσης κινητού — μέσος όρος 186 σηκώματα/μέρα",
                    "Jährliche Smartphone-Nutzungsstudie — Durchschnitt 186 Griffe/Tag"
                ),
                url: "https://www.reviews.org/mobile/cell-phone-addiction/"
            )

            sourceCard(
                title: "PubMed Central (2024)",
                subtitle: t(
                    "Parent smartphone use and child stress study",
                    "Έρευνα για smartphone γονέων και άγχος παιδιών",
                    "Studie zu Smartphone-Nutzung der Eltern und Kinder-Stress"
                ),
                url: "https://www.ncbi.nlm.nih.gov/pmc/"
            )
        }
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Disclaimer", "Σημείωση", "Hinweis"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(t(
                "Picksy is a digital wellbeing tool, not medical advice. If smartphone use significantly impacts your life, consult a mental health professional.",
                "Το Picksy είναι εργαλείο ψηφιακής ευεξίας, όχι ιατρική συμβουλή. Αν η χρήση κινητού επηρεάζει σημαντικά τη ζωή σου, μίλα με ειδικό ψυχικής υγείας.",
                "Picksy ist ein Tool für digitales Wohlbefinden, keine medizinische Beratung. Wenn die Smartphone-Nutzung dein Leben erheblich beeinflusst, wende dich an einen Fachmann."
            ))
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
            .lineSpacing(4)
        }
        .padding(.top, 8)
    }

    // MARK: - Helper Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.bottom, 4)
    }

    private func zoneCard(color: Color, name: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Text(description)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .lineSpacing(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func bulletRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(icon)
                .font(.system(size: 16))

            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
                .lineSpacing(3)
        }
    }

    private func sourceCard(title: String, subtitle: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .padding(.top, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AboutScienceView()
}

