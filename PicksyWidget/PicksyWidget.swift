//
//  PicksyWidget.swift
//  PicksyWidget
//
//  Created by Fotios Pongas on 09.04.26.
//

import WidgetKit
import SwiftUI

// MARK: - Shared Data

private func loadPickups() -> Int {
    let defaults = UserDefaults(suiteName: "group.fotiospongas.picksy")
    return defaults?.integer(forKey: "todayPickups") ?? 0
}

private func loadGoal() -> Int {
    let defaults = UserDefaults(suiteName: "group.fotiospongas.picksy")
    let goal = defaults?.integer(forKey: "dailyGoal") ?? 0
    return goal > 0 ? goal : 15
}

private func loadLanguage() -> String {
    let defaults = UserDefaults(suiteName: "group.fotiospongas.picksy")
    return defaults?.string(forKey: "appLanguage") ?? "English"
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
        let entry = PicksyEntry(
            date: Date(),
            pickups: loadPickups(),
            goal: loadGoal(),
            language: loadLanguage()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PicksyEntry>) -> Void) {
        let entry = PicksyEntry(
            date: Date(),
            pickups: loadPickups(),
            goal: loadGoal(),
            language: loadLanguage()
        )

        // Ανανέωση κάθε 15 λεπτά
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View

struct PicksyWidgetEntryView: View {
    var entry: PicksyEntry
    @Environment(\.widgetFamily) var family

    private var isGreek: Bool { entry.language == "Ελληνικά" }
    private var progress: Double { min(Double(entry.pickups) / Double(entry.goal), 1.0) }

    private var progressColor: Color {
        switch progress {
        case 0..<0.5: return .blue
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    // MARK: - Small Widget

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
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

            // Counter
            Text("\(entry.pickups)")
                .font(.system(size: 48, weight: .medium, design: .rounded))
                .foregroundColor(progressColor)

            Text(isGreek ? "σηκώματα" : "pickups")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)

            // Goal
            Text(isGreek
                 ? "Στόχος: \(entry.goal)"
                 : "Goal: \(entry.goal)")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(14)
    }

    // MARK: - Medium Widget

    private var mediumWidget: some View {
        HStack(spacing: 20) {
            // Left — counter
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

                Text(isGreek ? "σηκώματα σήμερα" : "pickups today")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Right — progress circle
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(progressColor)
                    Text(isGreek ? "στόχος" : "of goal")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
        }
        .padding(16)
    }
}

// MARK: - Widget

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

#Preview(as: .systemSmall) {
    PicksyWidget()
} timeline: {
    PicksyEntry(date: .now, pickups: 8, goal: 15, language: "English")
    PicksyEntry(date: .now, pickups: 18, goal: 15, language: "English")
}

#Preview(as: .systemMedium) {
    PicksyWidget()
} timeline: {
    PicksyEntry(date: .now, pickups: 8, goal: 15, language: "English")
    PicksyEntry(date: .now, pickups: 18, goal: 15, language: "English")
}

