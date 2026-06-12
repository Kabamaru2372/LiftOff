//
//  TimeGradientBackground.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.04.2026
//
//  Απαλό time-based gradient για συνέπεια στα tabs (Stats, Heatmap, Rewards, Settings).
//  Χρησιμοποιεί τα ίδια χρώματα με το NudgeView αλλά σε 50% ένταση
//  ώστε τα cards και charts να παραμένουν ευανάγνωστα.

import SwiftUI

struct TimeGradientBackground: View {

    @Environment(WeatherManager.self) private var weatherManager

    private var timeOfDay: TimeOfDay {
        TimeOfDay.from(
            sunrise: weatherManager.currentWeather?.sunrise,
            sunset:  weatherManager.currentWeather?.sunset
        )
    }

    /// Μίξη των time-based colors με το system background για απαλότερο look
    private var softGradientColors: [Color] {
        let base = timeOfDay.gradientColors
        let systemBG = Color(.systemBackground)

        // Χρησιμοποιούμε opacity για να "ανακατέψουμε" με το system background
        return base.map { color in
            color.opacity(0.55)
        } + [systemBG.opacity(0.4)]
    }

    var body: some View {
        ZStack {
            // Base: system background για να διατηρηθεί το auto dark/light mode
            Color(.systemBackground)
                .ignoresSafeArea()

            // Apply soft time-based gradient on top
            LinearGradient(
                colors: softGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 1.5), value: timeOfDay)
    }
}

// MARK: - View Modifier (πιο εύκολο usage)

extension View {
    /// Προσθέτει απαλό time-based gradient background
    func timeGradientBackground() -> some View {
        self.background(TimeGradientBackground())
    }
}

#Preview {
    VStack {
        Text("Sample content")
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .timeGradientBackground()
    .environment(WeatherManager())
}
