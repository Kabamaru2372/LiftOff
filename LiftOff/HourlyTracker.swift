//
//  HourlyTracker.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
// HourlyTracker.swift
// Unpluq
//
// Καταγράφει πόσες φορές σήκωσες το κινητό ΑΝΑ ΩΡΑ.
// Αποθηκεύει 7 ημέρες x 24 ώρες = 168 τιμές.
// Αυτά τα δεδομένα τροφοδοτούν το heatmap.

import Foundation

@Observable
class HourlyTracker {
    
    // 7 ημέρες x 24 ώρες
    // Κάθε array είναι μια μέρα [ώρα0, ώρα1, ..., ώρα23]
    // Index 0 = σήμερα, 1 = χθες, ... 6 = πριν 6 μέρες
    var hourlyData: [[Int]] = Array(repeating: Array(repeating: 0, count: 24), count: 7)
    
    private let defaults = UserDefaults.standard
    private let storageKey = "hourlyPickupData"
    private let lastDateKey = "hourlyLastDate"
    
    init() {
        loadData()
    }
    
    // Καταγράφει pickup στην τρέχουσα ώρα
    func recordPickup() {
        checkNewDay()
        let hour = Calendar.current.component(.hour, from: Date())
        hourlyData[0][hour] += 1
        saveData()
    }
    
    // Βρίσκει τις 3 χειρότερες ώρες (πιο πολλά pickups)
    var worstHours: [(hour: Int, avgPickups: Double)] {
        var hourAverages: [(hour: Int, avg: Double)] = []
        
        for hour in 0..<24 {
            var total = 0
            var daysWithData = 0
            
            for day in 0..<7 {
                let count = hourlyData[day][hour]
                if count > 0 {
                    total += count
                    daysWithData += 1
                }
            }
            
            let avg = daysWithData > 0 ? Double(total) / Double(daysWithData) : 0
            hourAverages.append((hour: hour, avg: avg))
        }
        
        // Ταξινόμησε κατά φθίνουσα σειρά και πάρε τις 3 πρώτες
        return hourAverages
            .sorted { $0.avg > $1.avg }
            .prefix(3)
            .map { (hour: $0.hour, avgPickups: $0.avg) }
    }
    
    // Μέγιστο pickups σε μια ώρα (για scaling του heatmap)
    var maxHourlyCount: Int {
        var maxVal = 1
        for day in hourlyData {
            for count in day {
                if count > maxVal { maxVal = count }
            }
        }
        return maxVal
    }
    
    // Ελέγχει αν ο χρήστης βελτιώθηκε σε μια συγκεκριμένη ώρα
    // Σύγκριση: μέσος όρος τελευταίων 2 ημερών vs προηγούμενων 5
    func hasImproved(hour: Int) -> Bool {
        // Τελευταίες 2 μέρες
        let recent = Double(hourlyData[0][hour] + hourlyData[1][hour]) / 2.0
        
        // Προηγούμενες 5 μέρες
        var olderTotal = 0
        var olderDays = 0
        for day in 2..<7 {
            if hourlyData[day][hour] > 0 {
                olderTotal += hourlyData[day][hour]
                olderDays += 1
            }
        }
        
        guard olderDays > 0 else { return false }
        let olderAvg = Double(olderTotal) / Double(olderDays)
        
        // Βελτίωση = τουλάχιστον 30% λιγότερα pickups
        return recent < olderAvg * 0.7
    }
    
    // Ονόματα ημερών για labels
    func dayLabel(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    // MARK: - Persistence
    
    private func checkNewDay() {
        let today = todayString()
        let lastDate = defaults.string(forKey: lastDateKey) ?? ""
        
        if lastDate != today {
            // Νέα μέρα — shift δεδομένα
            // Μετακίνησε τα πάντα μια θέση "πίσω"
            var newData = Array(repeating: Array(repeating: 0, count: 24), count: 7)
            for i in 0..<6 {
                newData[i + 1] = hourlyData[i]
            }
            // Index 0 = νέα μέρα, μηδενικά
            hourlyData = newData
            defaults.set(today, forKey: lastDateKey)
            saveData()
        }
    }
    
    private func saveData() {
        // Μετατρέπουμε σε flat array για αποθήκευση
        let flat = hourlyData.flatMap { $0 }
        defaults.set(flat, forKey: storageKey)
    }
    
    private func loadData() {
        guard let flat = defaults.array(forKey: storageKey) as? [Int],
              flat.count == 168 else { return }
        
        // Ξαναχτίζουμε το 7x24 array
        for day in 0..<7 {
            for hour in 0..<24 {
                hourlyData[day][hour] = flat[day * 24 + hour]
            }
        }
        checkNewDay()
    }
    
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

