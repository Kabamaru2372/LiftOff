//
//  PicksyWidget.swift
//  PicksyWidget
//
//  Created by Fotios Pongas on 09.04.26.
//  v1.7: Προστέθηκαν lock screen families (accessoryCircular, accessoryRectangular, accessoryInline)
//  Το DataStore γράφει σε shared UserDefaults και καλεί reloadAllTimelines() σε κάθε pickup,
//  οπότε το widget ανανεώνεται αμέσως — χωρίς να χρειάζεται να ανοιχτεί η app.
//

import WidgetKit
import SwiftUI

// MARK: - Shared Data

private let sharedDefaults = UserDefaults(suiteName: "group.fotiospongas.picksy")

private func loadPickups() -> Int {
    sharedDefaults?.integer(forKey: "todayPickups") ?? 0
}

private func loadGoal() -> Int {
    // C11 fix: default matches app-wide canonical default (50), not 15.
    let goal = sharedDefaults?.integer(forKey: "dailyGoal") ?? 0
    return goal > 0 ? goal : 50
}

private func loadLanguage() -> String {
    sharedDefaults?.string(forKey: "appLanguage") ?? "English"
}

// MARK: - Timeline Entry

struct PicksyEntry: TimelineEntry {
    let date: Date
    let pickups: Int
    let goal: Int
    let language: String
}

// MARK: - Provider

struct PicksyProvider: TimelineProvider {
    func placeholder(in context: Context) -> PicksyEntry {
        PicksyEntry(date: Date(), pickups: 12, goal: 15, language: "English")
    }

    func getSnapshot(in context: Context, completion: @escaping (PicksyEntry) -> Void) {
        completion(PicksyEntry(
            date: Date(),
            pickups: loadPickups(),
            goal: loadGoal(),
            language: loadLanguage()
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PicksyEntry>) -> Void) {
        let entry = PicksyEntry(
            date: Date(),
            pickups: loadPickups(),
            goal: loadGoal(),
            language: loadLanguage()
        )
        // Fallback refresh every 15 minutes — but DataStore calls
        // WidgetCenter.shared.reloadAllTimelines() on EVERY pickup,
        // so in practice the widget updates instantly on each phone pickup.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Widget View

struct PicksyWidgetEntryView: View {
    var entry: PicksyEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    private var isGreek: Bool  { entry.language == "Ελληνικά" }
    private var isGerman: Bool { entry.language == "Deutsch" }

    private var progress: Double { min(Double(entry.pickups) / Double(entry.goal), 1.0) }

    private var progressColor: Color {
        switch progress {
        case 0..<0.5: return .blue
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    private func pickupsLabel(_ short: Bool = false) -> String {
        if short {
            return isGreek ? "σηκ." : isGerman ? "Griffe" : "picks"
        }
        return isGreek ? "σηκώματα" : isGerman ? "Griffe" : "pickups"
    }

    var body: some View {
        switch family {

        // ── Lock Screen (iOS only) ─────────────────────────────────────────────
#if os(iOS)
        case .accessoryCircular:
            accessoryCircularView

        case .accessoryRectangular:
            accessoryRectangularView

        case .accessoryInline:
            accessoryInlineView
#endif

        // ── Home Screen ────────────────────────────────────────────────────────
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    // MARK: - Lock Screen: Circular

    private var accessoryCircularView: some View {
        ZStack {
            // Background progress ring
            Circle()
                .stroke(Color.gray.opacity(0.25), lineWidth: 5)

            // Filled arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Count number
            VStack(spacing: 0) {
                Text("\(entry.pickups)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .widgetAccentable()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(pickupsLabel(true))
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Lock Screen: Rectangular

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Title row
            HStack(spacing: 4) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 10, weight: .medium))
                    .widgetAccentable()
                Text("Picksy")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .widgetAccentable()
            }

            // Count + goal
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(entry.pickups)")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .widgetAccentable()
                Text("/ \(entry.goal) \(pickupsLabel())")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.25))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor)
                        .frame(width: geo.size.width * progress, height: 3)
                        .widgetAccentable()
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: - Lock Screen: Inline

    private var accessoryInlineView: some View {
        Label {
            Text("\(entry.pickups) / \(entry.goal) \(pickupsLabel())")
        } icon: {
            Image(systemName: "hand.raised.fill")
                .widgetAccentable()
        }
    }

    // MARK: - Home Screen: Small

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Picksy")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }

            Spacer()

            Text("\(entry.pickups)")
                .font(.system(size: 48, weight: .medium, design: .rounded))
                .foregroundColor(progressColor)

            Text(pickupsLabel())
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)

            Text(isGreek ? "Στόχος: \(entry.goal)" : isGerman ? "Ziel: \(entry.goal)" : "Goal: \(entry.goal)")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(14)
    }

    // MARK: - Home Screen: Medium

    private var mediumWidget: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Picksy")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Text("\(entry.pickups)")
                    .font(.system(size: 52, weight: .medium, design: .rounded))
                    .foregroundColor(progressColor)

                Text(isGreek ? "σηκώματα σήμερα" : isGerman ? "Griffe heute" : "pickups today")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(progressColor)
                    Text(isGreek ? "στόχος" : isGerman ? "Ziel" : "of goal")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
        }
        .padding(16)
    }
}

// MARK: - Home Screen Widget

struct PicksyWidget: Widget {
    let kind: String = "PicksyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PicksyProvider()) { entry in
            PicksyWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Picksy")
        .description("See your daily phone pickup count.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Lock Screen Widget (iOS 16+)

#if os(iOS)
struct PicksyLockScreenWidget: Widget {
    let kind: String = "PicksyLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PicksyProvider()) { entry in
            PicksyWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Picksy")
        .description("See your pickup count on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
#endif

// MARK: - Previews

#if os(iOS)
#Preview("Lock Screen Circular", as: .accessoryCircular) {
    PicksyLockScreenWidget()
} timeline: {
    PicksyEntry(date: .now, pickups: 8,  goal: 15, language: "English")
    PicksyEntry(date: .now, pickups: 18, goal: 15, language: "English")
}

#Preview("Lock Screen Rectangular", as: .accessoryRectangular) {
    PicksyLockScreenWidget()
} timeline: {
    PicksyEntry(date: .now, pickups: 8,  goal: 15, language: "English")
    PicksyEntry(date: .now, pickups: 18, goal: 15, language: "English")
}
#endif

#Preview("Home Small", as: .systemSmall) {
    PicksyWidget()
} timeline: {
    PicksyEntry(date: .now, pickups: 8,  goal: 15, language: "English")
    PicksyEntry(date: .now, pickups: 18, goal: 15, language: "English")
}

#Preview("Home Medium", as: .systemMedium) {
    PicksyWidget()
} timeline: {
    PicksyEntry(date: .now, pickups: 8,  goal: 15, language: "English")
    PicksyEntry(date: .now, pickups: 18, goal: 15, language: "English")
}
