// ForecastViews.swift
// Picksy
//
// Stats card for the Pickup Forecast: learning progress until enough days are
// trained, then a 24-hour risk heatmap and the busiest window of today.

import SwiftUI

struct ForecastCard: View {

    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @AppStorage(ForecastStore.enabledKey) private var enabled: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var data = ForecastData()
    @State private var now = Date()

    private let accent = Color.orange

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":   return de
        default:          return en
        }
    }

    // MARK: - Derived

    private var risks: [Double] { data.todayRisks(on: now) }
    private var currentHour: Int { Calendar.current.component(.hour, from: now) }

    /// The same windows the scheduler uses (whole day, quiet hours applied), so
    /// the card never names a window that cannot produce a heads-up.
    private var windows: [ForecastData.Window] { ForecastStore.todaysWindows(now: now) }

    private var peakHour: Int? { windows.max(by: { $0.risk < $1.risk })?.hour }

    private var title: String { t("Today's busy times", "Οι πιο έντονες ώρες σήμερα", "Deine stärksten Zeiten heute") }

    private var learningLine: String {
        t("Learning your routine: \(data.trainedDays) of \(ForecastData.minTrainedDays) days",
          "Μαθαίνω τη ρουτίνα σου: \(data.trainedDays) από \(ForecastData.minTrainedDays) μέρες",
          "Ich lerne deine Routine: \(data.trainedDays) von \(ForecastData.minTrainedDays) Tagen")
    }

    private var hintLine: String {
        t("Picksy learns when you usually reach for your phone. All on your device.",
          "Το Picksy μαθαίνει πότε πιάνεις συνήθως το κινητό. Όλα μένουν στη συσκευή σου.",
          "Picksy lernt, wann du meist zum Handy greifst. Alles bleibt auf deinem Gerät.")
    }

    private var summaryLine: String {
        guard let hour = peakHour else {
            return t("No busy times expected today", "Σήμερα δεν βλέπω έντονες ώρες", "Heute sind keine stärkeren Zeiten zu erwarten")
        }
        let hh = String(format: "%02d:00", hour)
        return t("Busiest window today: \(hh)", "Πιο έντονη ώρα σήμερα: \(hh)", "Stärkstes Zeitfenster heute: \(hh)")
    }

    private var footerLine: String {
        if !enabled {
            return t("Turn on heads-ups in Settings", "Ενεργοποίησε τις υπενθυμίσεις στις Ρυθμίσεις", "Aktiviere Hinweise in den Einstellungen")
        }
        return windows.isEmpty
            ? t("No heads-up needed today.", "Σήμερα δεν χρειάζεται υπενθύμιση.", "Heute ist kein Hinweis nötig.")
            : t("Picksy will give you a heads-up 10 minutes before.", "Το Picksy θα σου θυμίσει 10 λεπτά πριν.", "Picksy gibt dir 10 Minuten vorher einen Hinweis.")
    }

    private var accessibilityText: String {
        data.isReady ? "\(title). \(summaryLine). \(footerLine)" : "\(title). \(learningLine). \(hintLine)"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            if data.isReady {
                readyContent
            } else {
                learningContent
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(accent.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.2), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    private var learningContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(learningLine)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            ProgressView(value: data.progress)
                .progressViewStyle(.linear)
                .tint(accent)
                .scaleEffect(x: 1, y: 0.6, anchor: .center)
            Text(hintLine)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var readyContent: some View {
        let peak = max(risks.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    let risk = risks[hour]
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(risk >= ForecastData.riskThreshold ? accent : Color.secondary.opacity(0.3))
                            .frame(height: 6 + 34 * CGFloat(risk / peak))
                        Circle()
                            .fill(hour == currentHour ? Color.primary : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 48, alignment: .bottom)

            Text(summaryLine)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
            Text(footerLine)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    private func refresh() {
        now = Date()
        data = ForecastStore.load()
    }
}
