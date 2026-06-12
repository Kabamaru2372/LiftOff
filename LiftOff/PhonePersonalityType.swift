// PhonePersonalityType.swift
// Picksy
//
// Created by Fotios Pongas
//
// Detects the user's "Phone Personality Type" from their pickup + screen-time
// patterns. Pure local logic — no network required.

import Foundation

// MARK: - Phone Personality Type

enum PhonePersonalityType: String, CaseIterable {

    case midnightScroller   = "midnight_scroller"
    case morningChecker     = "morning_checker"
    case workdayDistractor  = "workday_distractor"
    case weekendBinger      = "weekend_binger"
    case zenPractitioner    = "zen_practitioner"
    case bingePicker        = "binge_picker"

    // MARK: Localised display name

    func name(language: String) -> String {
        switch language {
        case "Ελληνικά":
            switch self {
            case .midnightScroller:  return "Ο Νυχτερινός Scroller"
            case .morningChecker:    return "Ο Πρωινός Ελεγκτής"
            case .workdayDistractor: return "Ο Εργασιακός Αποσπασμένος"
            case .weekendBinger:     return "Ο Binger του Σαββατοκύριακου"
            case .zenPractitioner:   return "Ο Ζεν Ασκητής"
            case .bingePicker:       return "Ο Εκρηκτικός Picker"
            }
        case "Deutsch":
            switch self {
            case .midnightScroller:  return "Der Nacht-Scroller"
            case .morningChecker:    return "Der Morgen-Checker"
            case .workdayDistractor: return "Der Arbeitszeit-Ablenker"
            case .weekendBinger:     return "Der Wochenend-Binger"
            case .zenPractitioner:   return "Der Zen-Praktiker"
            case .bingePicker:       return "Der Intensiv-Picker"
            }
        default:
            switch self {
            case .midnightScroller:  return "The Midnight Scroller"
            case .morningChecker:    return "The Morning Checker"
            case .workdayDistractor: return "The Workday Distractor"
            case .weekendBinger:     return "The Weekend Binger"
            case .zenPractitioner:   return "The Zen Practitioner"
            case .bingePicker:       return "The Binge Picker"
            }
        }
    }

    // MARK: Localised description

    func description(language: String) -> String {
        switch language {
        case "Ελληνικά":
            switch self {
            case .midnightScroller:
                return "Αργά το βράδυ είναι η ώρα σου. Η οθόνη σε τραβά πιο δυνατά μετά τις 22:00."
            case .morningChecker:
                return "Πρώτο πράγμα το πρωί — το κινητό. Ξεκινάς την ημέρα σου με σκρολ."
            case .workdayDistractor:
                return "Η δουλειά σε φέρνει πιο κοντά στο κινητό. Τα περισσότερα σηκώματά σου γίνονται 9–17."
            case .weekendBinger:
                return "Τα Σαββατοκύριακα ξεφεύγεις. Ό,τι εξοικονόμησες τις καθημερινές, το αναπληρώνεις."
            case .zenPractitioner:
                return "Ήρεμος και συγκεντρωμένος. Σηκώνεις λιγότερο από τους περισσότερους — συνέχισε έτσι."
            case .bingePicker:
                return "Χαμηλός τόνος αλλά με εκρήξεις. Λίγες περίοδοι έντονης χρήσης ανεβάζουν το σκορ σου."
            }
        case "Deutsch":
            switch self {
            case .midnightScroller:
                return "Spät in der Nacht bist du am aktivsten. Das Display zieht dich nach 22 Uhr magisch an."
            case .morningChecker:
                return "Das Handy ist das Erste am Morgen. Du startest den Tag mit Scrollen."
            case .workdayDistractor:
                return "Zwischen 9 und 17 Uhr greifst du am häufigsten zum Handy — oft mitten in der Arbeit."
            case .weekendBinger:
                return "Am Wochenende läuft es aus dem Ruder. Was du werktags sparst, holst du am Weekend nach."
            case .zenPractitioner:
                return "Ruhig und fokussiert. Du greifst seltener zum Handy als die meisten — mach weiter so."
            case .bingePicker:
                return "Meist ruhig, doch manchmal intensiv. Kurze Binge-Phasen treiben deinen Tagesschnitt hoch."
            }
        default:
            switch self {
            case .midnightScroller:
                return "Late night is your prime time. The screen pulls hardest after 10 PM."
            case .morningChecker:
                return "First thing in the morning — the phone. You start your day with a scroll."
            case .workdayDistractor:
                return "Work hours bring you closest to your phone. Most of your pickups happen 9–5."
            case .weekendBinger:
                return "Weekends are when it gets out of hand. What you save on weekdays, you make up for."
            case .zenPractitioner:
                return "Calm and focused. You pick up less than most people — keep it up."
            case .bingePicker:
                return "Low baseline but with bursts. A few intense sessions push your daily count higher."
            }
        }
    }

    // MARK: Emoji

    var emoji: String {
        switch self {
        case .midnightScroller:  return "🌙"
        case .morningChecker:    return "☀️"
        case .workdayDistractor: return "💼"
        case .weekendBinger:     return "🎉"
        case .zenPractitioner:   return "🧘"
        case .bingePicker:       return "⚡️"
        }
    }

    // MARK: Detection

    /// Derives the personality type from a week of pickup data and hourly screen-time seconds.
    ///
    /// - Parameters:
    ///   - weeklyPickups: 7 integers, index 0 = Monday … 6 = Sunday
    ///   - hourlyScreenTimeSecs: 24 integers, index = hour of day (0–23)
    static func detect(
        weeklyPickups: [Int],
        hourlyScreenTimeSecs: [Int]
    ) -> PhonePersonalityType {

        let totalPickups = weeklyPickups.reduce(0, +)
        guard totalPickups > 0 else { return .zenPractitioner }

        // ── Hourly screen-time helpers ──────────────────────────────────────
        let totalScreenTime = hourlyScreenTimeSecs.reduce(0, +)

        // Night hours: 22–23 + 0–4
        let nightHours = [22, 23, 0, 1, 2, 3, 4]
        let nightTime = nightHours.compactMap {
            hourlyScreenTimeSecs.indices.contains($0) ? hourlyScreenTimeSecs[$0] : nil
        }.reduce(0, +)

        // Morning hours: 5–8
        let morningHours = [5, 6, 7, 8]
        let morningTime = morningHours.compactMap {
            hourlyScreenTimeSecs.indices.contains($0) ? hourlyScreenTimeSecs[$0] : nil
        }.reduce(0, +)

        // Workday hours: 9–17
        let workdayHours = Array(9...17)
        let workdayTime = workdayHours.compactMap {
            hourlyScreenTimeSecs.indices.contains($0) ? hourlyScreenTimeSecs[$0] : nil
        }.reduce(0, +)

        let nightRatio    = totalScreenTime > 0 ? Double(nightTime)    / Double(totalScreenTime) : 0
        let morningRatio  = totalScreenTime > 0 ? Double(morningTime)  / Double(totalScreenTime) : 0
        let workdayRatio  = totalScreenTime > 0 ? Double(workdayTime)  / Double(totalScreenTime) : 0

        // ── Weekly pickup helpers ───────────────────────────────────────────
        // weeklyPickups index 0 = Monday … 4 = Friday, 5 = Saturday, 6 = Sunday
        let weekdayPickups = Array(weeklyPickups.prefix(5))   // Mon–Fri
        let weekendPickups = Array(weeklyPickups.suffix(2))   // Sat–Sun

        let weekdayTotal  = weekdayPickups.reduce(0, +)
        let weekendTotal  = weekendPickups.reduce(0, +)
        let weekdayAvg    = weekdayTotal > 0 ? Double(weekdayTotal) / 5.0 : 0
        let weekendAvg    = weekendTotal > 0 ? Double(weekendTotal) / 2.0 : 0

        // Binge variance: standard deviation of daily pickups
        let mean     = Double(totalPickups) / 7.0
        let variance = weeklyPickups.map { pow(Double($0) - mean, 2) }.reduce(0, +) / 7.0
        let stdDev   = variance.squareRoot()
        let cv       = mean > 0 ? stdDev / mean : 0   // coefficient of variation

        // ── Classification (priority order) ────────────────────────────────

        // 1. Zen: very low daily average
        if mean <= 15 {
            return .zenPractitioner
        }

        // 2. Midnight Scroller: >28% of screen time after 22:00
        if nightRatio >= 0.28 {
            return .midnightScroller
        }

        // 3. Morning Checker: >25% of screen time before 09:00
        if morningRatio >= 0.25 {
            return .morningChecker
        }

        // 4. Weekend Binger: weekend avg is ≥2× weekday avg
        if weekdayAvg > 0 && weekendAvg >= weekdayAvg * 2.0 {
            return .weekendBinger
        }

        // 5. Workday Distractor: >50% of screen time during 9–17
        if workdayRatio >= 0.50 {
            return .workdayDistractor
        }

        // 6. Binge Picker: high coefficient of variation (>0.6)
        if cv >= 0.60 {
            return .bingePicker
        }

        // 7. Fallback — whichever slot has the highest share wins
        let slots: [(PhonePersonalityType, Double)] = [
            (.midnightScroller,   nightRatio),
            (.morningChecker,     morningRatio),
            (.workdayDistractor,  workdayRatio),
        ]
        return slots.max(by: { $0.1 < $1.1 })?.0 ?? .workdayDistractor
    }
}
