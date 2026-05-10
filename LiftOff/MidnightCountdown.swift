//
//  MidnightCountdown.swift
//  Picksy
//
//  Created by Fotios Pongas on 04.05.2026
//
//  Reusable countdown helper για το "Apple data resets in Xh Ym" feature.
//
//  iOS Screen Time data (app usage time, app opens) ανανεώνονται αυτόματα
//  στις 00:00 τοπικής ώρας. Δεν μπορούμε να τα σβήσουμε νωρίτερα.
//
//  Αυτό το component εκπαιδεύει τον χρήστη με ένα φιλικό countdown
//  message που δείχνει πότε θα γίνει το next reset.
//

import SwiftUI

/// View που δείχνει "Apple data resets in Xh Ym".
/// Auto-updates κάθε λεπτό μέσω Timer.
struct MidnightCountdownView: View {
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @State private var timeRemaining: String = ""
    @State private var refreshTimer: Timer? = nil

    /// Optional styling
    var iconColor: Color = .secondary
    var textColor: Color = .secondary
    var fontSize: CGFloat = 12

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: fontSize - 1))
                .foregroundColor(iconColor)

            Text(displayText)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .foregroundColor(textColor)
        }
        .onAppear {
            updateTimeRemaining()
            startRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }

    private var displayText: String {
        t(
            "Apple data resets in \(timeRemaining)",
            "Τα δεδομένα της Apple ανανεώνονται σε \(timeRemaining)",
            "Apple-Daten werden in \(timeRemaining) zurückgesetzt"
        )
    }

    private func updateTimeRemaining() {
        timeRemaining = MidnightCountdown.timeUntilMidnight(language: appLanguage)
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        // Update κάθε λεπτό
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            updateTimeRemaining()
        }
    }
}

/// Static helper για το countdown calculation.
/// Μπορεί να χρησιμοποιηθεί όπου χρειάζεται χωρίς το View.
enum MidnightCountdown {

    /// Calculates seconds until next midnight (00:00 local time).
    static func secondsUntilMidnight() -> TimeInterval {
        let calendar = Calendar.current
        guard let midnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return 0 }

        return midnight.timeIntervalSinceNow
    }

    /// Returns formatted string like "2h 44m" or "44m" or "<1m".
    /// Localized βάσει του language parameter.
    static func timeUntilMidnight(language: String) -> String {
        let totalSeconds = Int(secondsUntilMidnight())

        guard totalSeconds > 0 else {
            return localizedNow(language: language)
        }

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        switch (hours, minutes) {
        case (0, 0):
            return localizedNow(language: language)

        case (0, _):
            // Μόνο λεπτά (πχ "44m" / "44 λ" / "44 Min.")
            return localizedMinutes(minutes, language: language)

        case (_, 0):
            // Ακριβώς ώρες (πχ "2h" / "2 ώρες" / "2 Std.")
            return localizedHours(hours, language: language)

        default:
            // Ώρες + λεπτά (πχ "2h 44m")
            return localizedHoursMinutes(hours: hours, minutes: minutes, language: language)
        }
    }

    // MARK: - Localized Strings

    private static func localizedNow(language: String) -> String {
        switch language {
        case "Ελληνικά": return "λίγη ώρα"
        case "Deutsch":  return "kurzer Zeit"
        default:         return "moments"
        }
    }

    private static func localizedMinutes(_ mins: Int, language: String) -> String {
        switch language {
        case "Ελληνικά": return "\(mins) λ"
        case "Deutsch":  return "\(mins) Min."
        default:         return "\(mins)m"
        }
    }

    private static func localizedHours(_ hours: Int, language: String) -> String {
        switch language {
        case "Ελληνικά": return "\(hours) ώ"
        case "Deutsch":  return "\(hours) Std."
        default:         return "\(hours)h"
        }
    }

    private static func localizedHoursMinutes(hours: Int, minutes: Int, language: String) -> String {
        switch language {
        case "Ελληνικά": return "\(hours)ώ \(minutes)λ"
        case "Deutsch":  return "\(hours)Std. \(minutes)Min."
        default:         return "\(hours)h \(minutes)m"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MidnightCountdownView()
        MidnightCountdownView(iconColor: .blue, textColor: .primary, fontSize: 14)
    }
    .padding()
}
