//
//  HeatmapView.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
// HeatmapView.swift
// Unpluq
//
// Δείχνει ένα 7x24 heatmap grid.
// Rows = ημέρες (σήμερα πάνω), Columns = ώρες (0-23)
// Πιο σκούρο χρώμα = πιο πολλά pickups

import SwiftUI

struct HeatmapView: View {
    @Environment(HourlyTracker.self) var tracker
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    
    // Ώρες που δείχνουμε labels (κάθε 3 ώρες)
    private let labeledHours = [0, 3, 6, 9, 12, 15, 18, 21]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Title
                Text(appLanguage == "Ελληνικά" ? "Χάρτης θερμότητας" : "Pickup heatmap")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .padding(.top, 20)
                
                Text(appLanguage == "Ελληνικά"
                     ? "Πιο σκούρο = περισσότερα pickups"
                     : "Darker = more pickups")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                
                // Heatmap Grid
                VStack(spacing: 3) {
                    // Hour labels πάνω
                    HStack(spacing: 0) {
                        // Κενό για day labels
                        Text("")
                            .frame(width: 36)
                        
                        ForEach(0..<24, id: \.self) { hour in
                            if labeledHours.contains(hour) {
                                Text("\(hour)")
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Spacer()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    
                    // Rows: μια γραμμή ανά ημέρα
                    ForEach(0..<7, id: \.self) { dayIndex in
                        HStack(spacing: 2) {
                            // Day label
                            Text(tracker.dayLabel(daysAgo: dayIndex))
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(width: 36, alignment: .trailing)
                            
                            // 24 cells
                            ForEach(0..<24, id: \.self) { hour in
                                let count = tracker.hourlyData[dayIndex][hour]
                                let intensity = cellIntensity(count: count)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cellColor(intensity: intensity))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 20)
                                    .overlay(
                                        // Δείξε αριθμό αν > 0
                                        Group {
                                            if count > 0 {
                                                Text("\(count)")
                                                    .font(.system(size: 8, weight: .medium, design: .rounded))
                                                    .foregroundColor(intensity > 0.5 ? .white : .secondary)
                                            }
                                        }
                                    )
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                
                // Worst hours section
                if !tracker.worstHours.isEmpty && tracker.worstHours[0].avgPickups > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(appLanguage == "Ελληνικά" ? "Οι χειρότερες ώρες σου" : "Your worst hours")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                        
                        ForEach(tracker.worstHours.indices, id: \.self) { index in
                            let worst = tracker.worstHours[index]
                            if worst.avgPickups > 0 {
                                HStack(spacing: 12) {
                                    // Ώρα
                                    Text(formatHour(worst.hour))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .frame(width: 80, alignment: .leading)
                                    
                                    // Bar
                                    GeometryReader { geo in
                                        let maxAvg = tracker.worstHours[0].avgPickups
                                        let width = maxAvg > 0
                                            ? CGFloat(worst.avgPickups / maxAvg) * geo.size.width
                                            : 0
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(barColor(index: index))
                                            .frame(width: max(width, 4), height: 24)
                                    }
                                    .frame(height: 24)
                                    
                                    // Average
                                    Text(String(format: "%.1f", worst.avgPickups))
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .frame(width: 36, alignment: .trailing)
                                    
                                    // Improvement indicator
                                    if tracker.hasImproved(hour: worst.hour) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        
                        // Tip
                        Text(appLanguage == "Ελληνικά"
                             ? "Βελτιώσου σε αυτές τις ώρες για 2 μέρες και ξεκλείδωσε reward!"
                             : "Improve during these hours for 2 days to unlock a reward!")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Helpers
    
    private func cellIntensity(count: Int) -> Double {
        guard tracker.maxHourlyCount > 0 else { return 0 }
        return Double(count) / Double(tracker.maxHourlyCount)
    }
    
    private func cellColor(intensity: Double) -> Color {
        if intensity == 0 {
            return Color(.systemGray6)
        }
        return Color.blue.opacity(0.15 + intensity * 0.75)
    }
    
    private func barColor(index: Int) -> Color {
        switch index {
        case 0: return .red.opacity(0.7)
        case 1: return .orange.opacity(0.7)
        default: return .yellow.opacity(0.7)
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let endHour = (hour + 1) % 24
        return String(format: "%02d:00–%02d:00", hour, endHour)
    }
}

#Preview {
    HeatmapView()
        .environment(HourlyTracker())
}

