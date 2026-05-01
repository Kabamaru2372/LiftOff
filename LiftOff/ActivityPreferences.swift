//
//  ActivityPreferences.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.04.2026
//
//  9 κατηγορίες δραστηριοτήτων για personalization.
//  Αν δεν επιλεγεί καμία, όλες θεωρούνται ενεργές (default).

import Foundation

enum ActivityCategory: String, CaseIterable, Codable, Identifiable {
    case movement      // 🚶 Κίνηση & φύση
    case mindfulness   // 🧘 Ησυχία & mindfulness
    case fitness       // 💪 Γυμναστική
    case reading       // 📚 Διάβασμα & μάθηση
    case cooking       // 🍳 Μαγειρική & φαγητό
    case creative      // 🎨 Δημιουργικά
    case social        // 👥 Κοινωνικά
    case home          // 🏠 Σπίτι & οργάνωση
    case health        // 💧 Υγεία

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .movement:    return "🚶"
        case .mindfulness: return "🧘"
        case .fitness:     return "💪"
        case .reading:     return "📚"
        case .cooking:     return "🍳"
        case .creative:    return "🎨"
        case .social:      return "👥"
        case .home:        return "🏠"
        case .health:      return "💧"
        }
    }

    func title(language: String) -> String {
        switch (self, language) {
        case (.movement, "Ελληνικά"):    return "Κίνηση & φύση"
        case (.movement, "Deutsch"):     return "Bewegung & Natur"
        case (.movement, _):             return "Movement & nature"

        case (.mindfulness, "Ελληνικά"): return "Ησυχία & mindfulness"
        case (.mindfulness, "Deutsch"):  return "Ruhe & Achtsamkeit"
        case (.mindfulness, _):          return "Quiet & mindfulness"

        case (.fitness, "Ελληνικά"):     return "Γυμναστική"
        case (.fitness, "Deutsch"):      return "Fitness"
        case (.fitness, _):              return "Fitness"

        case (.reading, "Ελληνικά"):     return "Διάβασμα & μάθηση"
        case (.reading, "Deutsch"):      return "Lesen & Lernen"
        case (.reading, _):              return "Reading & learning"

        case (.cooking, "Ελληνικά"):     return "Μαγειρική & φαγητό"
        case (.cooking, "Deutsch"):      return "Kochen & Essen"
        case (.cooking, _):              return "Cooking & food"

        case (.creative, "Ελληνικά"):    return "Δημιουργικά"
        case (.creative, "Deutsch"):     return "Kreativ"
        case (.creative, _):             return "Creative"

        case (.social, "Ελληνικά"):      return "Κοινωνικά"
        case (.social, "Deutsch"):       return "Sozial"
        case (.social, _):               return "Social"

        case (.home, "Ελληνικά"):        return "Σπίτι & οργάνωση"
        case (.home, "Deutsch"):         return "Zuhause & Ordnung"
        case (.home, _):                 return "Home & organizing"

        case (.health, "Ελληνικά"):      return "Υγεία"
        case (.health, "Deutsch"):       return "Gesundheit"
        case (.health, _):               return "Health"
        }
    }

    func description(language: String) -> String {
        switch (self, language) {
        case (.movement, "Ελληνικά"):    return "Περίπατοι, έξω, σκάλες"
        case (.movement, "Deutsch"):     return "Spazieren, draußen, Treppen"
        case (.movement, _):             return "Walks, outdoors, stairs"

        case (.mindfulness, "Ελληνικά"): return "Διαλογισμός, αναπνοές"
        case (.mindfulness, "Deutsch"):  return "Meditation, Atmen"
        case (.mindfulness, _):          return "Meditation, breathing"

        case (.fitness, "Ελληνικά"):     return "Squats, stretching, άσκηση"
        case (.fitness, "Deutsch"):      return "Kniebeugen, Dehnen, Übung"
        case (.fitness, _):              return "Squats, stretching, exercise"

        case (.reading, "Ελληνικά"):     return "Βιβλία, ημερολόγιο"
        case (.reading, "Deutsch"):      return "Bücher, Tagebuch"
        case (.reading, _):              return "Books, journaling"

        case (.cooking, "Ελληνικά"):     return "Φαγητό, ροφήματα"
        case (.cooking, "Deutsch"):      return "Essen, Getränke"
        case (.cooking, _):              return "Food, drinks"

        case (.creative, "Ελληνικά"):    return "Ζωγραφική, μουσική, γράψιμο"
        case (.creative, "Deutsch"):     return "Zeichnen, Musik, Schreiben"
        case (.creative, _):             return "Draw, music, write"

        case (.social, "Ελληνικά"):      return "Τηλεφώνα, γράμματα, συναντήσεις"
        case (.social, "Deutsch"):       return "Anrufe, Briefe, Treffen"
        case (.social, _):               return "Calls, letters, meetings"

        case (.home, "Ελληνικά"):        return "Τακτοποίηση, φυτά"
        case (.home, "Deutsch"):         return "Aufräumen, Pflanzen"
        case (.home, _):                 return "Tidying, plants"

        case (.health, "Ελληνικά"):      return "Νερό, ύπνος, σνακ"
        case (.health, "Deutsch"):       return "Wasser, Schlaf, Snacks"
        case (.health, _):               return "Water, sleep, snacks"
        }
    }
}

// MARK: - Manager

@Observable
class ActivityPreferences {

    var selected: Set<ActivityCategory> = []

    private let defaults = UserDefaults.standard
    private let storageKey = "picksyActivityCategories"

    init() {
        load()
    }

    /// Αν δεν έχει επιλέξει καμία κατηγορία, όλες θεωρούνται ενεργές
    var effectiveCategories: Set<ActivityCategory> {
        selected.isEmpty ? Set(ActivityCategory.allCases) : selected
    }

    func toggle(_ category: ActivityCategory) {
        if selected.contains(category) {
            selected.remove(category)
        } else {
            selected.insert(category)
        }
        save()
    }

    func isSelected(_ category: ActivityCategory) -> Bool {
        selected.contains(category)
    }

    func selectAll() {
        selected = Set(ActivityCategory.allCases)
        save()
    }

    func clearAll() {
        selected = []
        save()
    }

    // MARK: - Persistence

    private func save() {
        let raw = selected.map { $0.rawValue }
        defaults.set(raw, forKey: storageKey)
    }

    private func load() {
        // Default: όλες επιλεγμένες (pre-selected)
        if defaults.object(forKey: storageKey) == nil {
            selected = Set(ActivityCategory.allCases)
            save()
            return
        }

        guard let raw = defaults.stringArray(forKey: storageKey) else { return }
        selected = Set(raw.compactMap { ActivityCategory(rawValue: $0) })
    }
}
