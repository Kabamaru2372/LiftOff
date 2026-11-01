//
//  DuoFoldViews.swift
//  Picksy
//
//  Stats card + setup guide for the iPhone Duo fold counter. The data comes
//  from DuoFoldStore (filled by RecordDuoFoldIntent through a Shortcuts
//  automation); these views only read it.
//

import SwiftUI
import UniformTypeIdentifiers

private func duoT(_ language: String, _ en: String, _ gr: String, _ de: String) -> String {
    switch language {
    case "Ελληνικά": return gr
    case "Deutsch": return de
    default: return en
    }
}

// MARK: - Live data

/// Reloads from the store whenever an event is recorded or the app becomes active.
private struct DuoFoldLoader: ViewModifier {
    @Binding var data: DuoFoldData

    func body(content: Content) -> some View {
        content
            .onAppear { data = DuoFoldStore.load() }
            .onReceive(NotificationCenter.default.publisher(for: .duoFoldRecorded)) { _ in
                data = DuoFoldStore.load()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                data = DuoFoldStore.load()
            }
    }
}

private extension View {
    func duoFoldData(_ data: Binding<DuoFoldData>) -> some View {
        modifier(DuoFoldLoader(data: data))
    }
}

// MARK: - Stats card

struct DuoFoldStatsCard: View {
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @State private var data = DuoFoldStore.load()
    @State private var showSetup = false

    private let accent = Color.teal

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        duoT(appLanguage, en, gr, de)
    }

    var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "iphone").font(.system(size: 12)).foregroundColor(accent)
                Text(t("Duo folds", "Διπλώματα Duo", "Duo-Faltungen"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showSetup = true }) {
                    Image(systemName: data.hasData ? "info.circle" : "gearshape")
                        .font(.system(size: 14)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t("Set up fold counting", "Ρύθμιση μέτρησης", "Zählung einrichten"))
            }

            if data.hasData {
                content(now: now)
            } else {
                emptyState
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(accent.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.18), lineWidth: 1))
        )
        .duoFoldData($data)
        .sheet(isPresented: $showSetup) { DuoFoldSetupView() }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let today = data.today(now: now)
        let diff = today - data.yesterday(now: now)

        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(data.total)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(accent)
                .contentTransition(.numericText())
            VStack(alignment: .leading, spacing: 1) {
                Text(t("folds all time", "διπλώματα συνολικά", "Faltungen gesamt"))
                    .font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
                Text(t("≈ \(data.openings) openings", "≈ \(data.openings) ανοίγματα", "≈ \(data.openings) Öffnungen"))
                    .font(.system(size: 11, design: .rounded)).foregroundColor(.secondary.opacity(0.8))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(t("Today \(today)", "Σήμερα \(today)", "Heute \(today)"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if diff != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: diff > 0 ? "arrow.up" : "arrow.down").font(.system(size: 9, weight: .bold))
                        Text("\(abs(diff))").font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(diff > 0 ? .orange : .green)
                } else {
                    Text(t("same as yesterday", "όπως χθες", "wie gestern"))
                        .font(.system(size: 11, design: .rounded)).foregroundColor(.secondary)
                }
            }
        }

        weekBars(now: now)

        if let peak = data.peakHourToday(now: now) {
            Text(t("Busiest hour today: \(peak):00", "Πιο πολλά σήμερα: \(peak):00", "Meiste heute: \(peak):00 Uhr"))
                .font(.system(size: 11, design: .rounded)).foregroundColor(.secondary)
        }
    }

    private func weekBars(now: Date) -> some View {
        let week = data.week(now: now)
        let maxCount = max(week.map(\.count).max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                let isToday = index == week.count - 1
                VStack(spacing: 3) {
                    Text("\(day.count)")
                        .font(.system(size: 9, weight: isToday ? .semibold : .regular, design: .rounded))
                        .foregroundColor(isToday ? .primary : .secondary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isToday ? accent : accent.opacity(0.3))
                        .frame(height: max(3, CGFloat(day.count) / CGFloat(maxCount) * 36))
                    Text(day.weekdayLetter)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 64, alignment: .bottom)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Not counting yet. Picksy needs a one-time Shortcuts automation to see your Duo open and close, even when the app is closed.",
                   "Δεν μετράει ακόμα. Το Picksy χρειάζεται έναν αυτοματισμό στις Συντομεύσεις (μία φορά) για να βλέπει πότε ανοίγει και κλείνει το Duo, ακόμα και με κλειστή την εφαρμογή.",
                   "Zählt noch nicht. Picksy braucht einmalig eine Kurzbefehle-Automation, um das Öffnen und Schließen deines Duo zu erkennen, auch wenn die App geschlossen ist."))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: { showSetup = true }) {
                Text(t("Set up", "Ρύθμιση", "Einrichten"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(accent))
            }
        }
    }
}

// MARK: - Setup guide

struct DuoFoldSetupView: View {
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var data = DuoFoldStore.load()
    @State private var showImporter = false
    @State private var importMessage: String? = nil

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        duoT(appLanguage, en, gr, de)
    }

    private var steps: [(String, String)] {
        [
            (t("Open Shortcuts and create a new shortcut with +.",
               "Άνοιξε τις Συντομεύσεις και φτιάξε μια νέα συντόμευση με το +.",
               "Öffne Kurzbefehle und erstelle mit + einen neuen Kurzbefehl."),
             "1.circle.fill"),
            (t("Add the trigger “When iPhone is Opened or Closed”.",
               "Πρόσθεσε το trigger «When iPhone is Opened or Closed».",
               "Füge den Auslöser „When iPhone is Opened or Closed“ hinzu."),
             "2.circle.fill"),
            (t("Add the action “Record Duo fold” from Picksy.",
               "Πρόσθεσε την ενέργεια «Record Duo fold» από το Picksy.",
               "Füge die Aktion „Record Duo fold“ von Picksy hinzu."),
             "3.circle.fill"),
            (t("Keep Automation on and turn Notify off, so it counts silently.",
               "Άφησε το Automation ενεργό και κλείσε το Notify, ώστε να μετράει αθόρυβα.",
               "Lass Automation an und schalte Notify aus, damit still gezählt wird."),
             "4.circle.fill"),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(t("Picksy counts every time you open or close your iPhone Duo, even when the app is closed. iOS only allows that through a Shortcuts automation, so you set it up once.",
                           "Το Picksy μετράει κάθε φορά που ανοίγεις ή κλείνεις το iPhone Duo, ακόμα και με κλειστή την εφαρμογή. Το iOS το επιτρέπει μόνο μέσω αυτοματισμού στις Συντομεύσεις, γι' αυτό τον ρυθμίζεις μία φορά.",
                           "Picksy zählt jedes Öffnen und Schließen deines iPhone Duo, auch wenn die App geschlossen ist. iOS erlaubt das nur über eine Kurzbefehle-Automation, die du einmal einrichtest."))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("What your shortcut should look like", "Πώς πρέπει να μοιάζει η συντόμευσή σου", "So sollte dein Kurzbefehl aussehen"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        DuoShortcutMock()
                        Text(t("The names in your Shortcuts app may differ slightly depending on your language.",
                               "Τα ονόματα στις Συντομεύσεις μπορεί να διαφέρουν λίγο ανάλογα με τη γλώσσα σου.",
                               "Die Namen in deiner Kurzbefehle-App können je nach Sprache leicht abweichen."))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.8))
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: step.1).font(.system(size: 22)).foregroundColor(.teal)
                                Text(step.0)
                                    .font(.system(size: 15, design: .rounded))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        }
                    }

                    Button(action: { if let url = URL(string: "shortcuts://") { openURL(url) } }) {
                        Label(t("Open Shortcuts", "Άνοιγμα Συντομεύσεων", "Kurzbefehle öffnen"), systemImage: "arrow.up.forward.app")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.teal))
                    }

                    Text(t("Already counting with the Scriptable script? In that shortcut, replace the “Run Duo Folds” action with “Record Duo fold”.",
                           "Μετράς ήδη με το script Scriptable; Σε εκείνη τη συντόμευση αντικατέστησε την ενέργεια «Run Duo Folds» με το «Record Duo fold».",
                           "Zählst du schon mit dem Scriptable-Skript? Ersetze in diesem Kurzbefehl die Aktion „Run Duo Folds“ durch „Record Duo fold“."))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    statusCard

                    if !data.importedFromScriptable {
                        Button(action: { showImporter = true }) {
                            Text(t("Import history from the Scriptable script (duo_folds.json)",
                                   "Εισαγωγή ιστορικού από το script Scriptable (duo_folds.json)",
                                   "Verlauf aus dem Scriptable-Skript importieren (duo_folds.json)"))
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    if let message = importMessage {
                        Text(message).font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle(t("Count your Duo folds", "Μέτρηση διπλωμάτων Duo", "Duo-Faltungen zählen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("Done", "Τέλος", "Fertig")) { dismiss() }
                }
            }
        }
        .duoFoldData($data)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
    }

    private var statusCard: some View {
        let text: String = {
            guard let last = data.last else {
                return t("Nothing recorded yet. Fold your Duo once after setting it up and this will update.",
                         "Δεν έχει καταγραφεί τίποτα ακόμα. Δίπλωσε το Duo μία φορά μετά τη ρύθμιση και θα ενημερωθεί.",
                         "Noch nichts erfasst. Falte dein Duo nach der Einrichtung einmal, dann wird dies aktualisiert.")
            }
            let when = Date(timeIntervalSince1970: last).formatted(date: .abbreviated, time: .shortened)
            return t("Working. Last fold recorded: \(when) · \(data.total) in total.",
                     "Λειτουργεί. Τελευταίο δίπλωμα: \(when) · \(data.total) συνολικά.",
                     "Funktioniert. Letzte Faltung: \(when) · \(data.total) insgesamt.")
        }()
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: data.last == nil ? "clock" : "checkmark.circle.fill")
                .foregroundColor(data.last == nil ? .secondary : .green)
            Text(text).font(.system(size: 13, design: .rounded)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            importMessage = t("Couldn't open the file.", "Δεν άνοιξε το αρχείο.", "Die Datei konnte nicht geöffnet werden.")
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let json = try Data(contentsOf: url)
                data = try DuoFoldStore.importScriptable(json)
                importMessage = t("Imported. Your history is now in Picksy.",
                                  "Έγινε εισαγωγή. Το ιστορικό σου είναι πλέον στο Picksy.",
                                  "Importiert. Dein Verlauf ist jetzt in Picksy.")
            } catch DuoFoldData.ImportError.alreadyImported {
                importMessage = t("Already imported.", "Έχει ήδη εισαχθεί.", "Bereits importiert.")
            } catch DuoFoldData.ImportError.empty {
                importMessage = t("That file has no folds in it.", "Το αρχείο δεν έχει διπλώματα.", "Die Datei enthält keine Faltungen.")
            } catch {
                importMessage = t("That doesn't look like duo_folds.json.",
                                  "Αυτό δεν μοιάζει με duo_folds.json.",
                                  "Das sieht nicht nach duo_folds.json aus.")
            }
        }
    }
}

// MARK: - Shortcut illustration

/// A drawn replica of the Shortcuts editor showing the finished shortcut, with
/// numbered badges that match the steps below it. Drawn (not a screenshot) so it
/// stays sharp, adapts to the Duo's two screens and carries no personal data.
/// Always dark, like the Shortcuts editor itself.
private struct DuoShortcutMock: View {
    private let panel = Color(white: 0.11)
    private let row = Color(white: 0.17)
    private let pillBlue = Color(red: 0.25, green: 0.52, blue: 1.0)

    var body: some View {
        VStack(spacing: 12) {
            triggerBlock
            actionBlock
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shortcut with the trigger When iPhone is Opened or Closed, Automation on, Notify off, followed by the action Record Duo fold.")
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(pillBlue)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(pillBlue.opacity(0.18)))
    }

    private func toggle(on: Bool) -> some View {
        Capsule()
            .fill(on ? Color.green : Color(white: 0.32))
            .frame(width: 46, height: 28)
            .overlay(alignment: on ? .trailing : .leading) {
                Circle().fill(Color.white).frame(width: 24, height: 24).padding(2)
            }
    }

    private func badge(_ number: Int) -> some View {
        Text("\(number)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(Color.teal))
            .overlay(Circle().stroke(Color.black, lineWidth: 2))
    }

    private var triggerBlock: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "iphone").font(.system(size: 15)).foregroundColor(pillBlue)
                Text("When iPhone is").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.white)
                pill("Opened or Closed")
                Spacer(minLength: 0)
            }
            .padding(12)
            .overlay(alignment: .topTrailing) { badge(2).offset(x: 6, y: -6) }

            Divider().overlay(Color(white: 0.25))

            HStack {
                Text("Automation").font(.system(size: 14, design: .rounded)).foregroundColor(.white)
                Spacer()
                toggle(on: true)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider().overlay(Color(white: 0.25))

            HStack {
                Text("Notify").font(.system(size: 14, design: .rounded)).foregroundColor(.white)
                Spacer()
                toggle(on: false)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .overlay(alignment: .topTrailing) { badge(4).offset(x: 6, y: -2) }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(row))
    }

    private var actionBlock: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26, height: 26)
                .overlay(Image(systemName: "hand.raised.fill").font(.system(size: 13)).foregroundColor(.white))
            Text("Record Duo").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.white)
            pill("Opened or Closed")
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(row))
        .overlay(alignment: .topTrailing) { badge(3).offset(x: 6, y: -6) }
    }
}
