
//
//  CheckInManager.swift
//  Picksy
//
//  Created by Fotios Pongas on 22.04.2026

import Foundation
import SwiftUI

enum CheckInMood: String, Codable {
    case great
    case okay
    case rough

    var emoji: String {
        switch self {
        case .great: return "🟢"
        case .okay: return "🟡"
        case .rough: return "🔴"
        }
    }

    var color: Color {
        switch self {
        case .great: return .green
        case .okay: return .yellow
        case .rough: return .red
        }
    }
}

struct CheckInEntry: Codable, Identifiable {
    var id: String { date }
    let date: String // yyyy-MM-dd
    let mood: CheckInMood
    let note: String
    let timestamp: Date
}

@Observable
class CheckInManager {

    var entries: [CheckInEntry] = []

    private let defaults = UserDefaults.standard
    private let storageKey = "picksyCheckInEntries"

    init() {
        loadEntries()
    }

    // MARK: - Check if check-in is needed

    /// Επιστρέφει true αν είναι μετά τις 21:00 και δεν έχει γίνει check-in σήμερα
    var shouldShowCheckIn: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 21 else { return false }
        return !hasCheckedInToday
    }

    var hasCheckedInToday: Bool {
        let today = todayDateString()
        return entries.contains(where: { $0.date == today })
    }

    // MARK: - Save check-in

    func saveCheckIn(mood: CheckInMood, note: String) {
        let today = todayDateString()

        // Αφαίρεσε υπάρχον entry για σήμερα αν υπάρχει (update)
        entries.removeAll(where: { $0.date == today })

        let entry = CheckInEntry(
            date: today,
            mood: mood,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            timestamp: Date()
        )

        entries.append(entry)
        saveEntries()
    }

    // MARK: - Get last 7 days moods

    /// Επιστρέφει τις moods των τελευταίων 7 ημερών (σήμερα = index 6)
    var last7DaysMoods: [CheckInMood?] {
        var result: [CheckInMood?] = Array(repeating: nil, count: 7)
        let calendar = Calendar.current

        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -(6 - i), to: Date()) else { continue }
            let dateString = dateStringFor(date)
            if let entry = entries.first(where: { $0.date == dateString }) {
                result[i] = entry.mood
            }
        }

        return result
    }

    // MARK: - Persistence

    private func loadEntries() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CheckInEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }

    // MARK: - Helpers

    private func todayDateString() -> String {
        return dateStringFor(Date())
    }

    private func dateStringFor(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
