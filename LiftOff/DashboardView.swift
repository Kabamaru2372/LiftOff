// DashboardView.swift
// Unpluq
//
// Created by Fotios Pongas 24.03.2026
// Η οθόνη στατιστικών — pickups σήμερα, μέσος χρόνος,
// weekly chart, streak.

import SwiftUI

struct DashboardView: View {
    @Environment(DataStore.self) var store
    
    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                Text("LiftOff")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .padding(.top, 20)
                
                Text("Today")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    StatCard(title: "Pickups", value: "\(store.todayPickups)")
                    StatCard(title: "Avg time", value: "\(store.averageMinutes)m")
                }
                
                Text("This week")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                
                WeeklyChart(data: store.weeklyPickups, dayNames: dayNames)
                    .frame(height: 120)
                
                Text("Streak")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(store.currentStreak)")
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                    
                    Text("days under\n15 pickups")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .medium, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeeklyChart: View {
    let data: [Int]
    let dayNames: [String]
    
    private var maxValue: Int {
        max(data.max() ?? 1, 1)
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index == currentDayIndex()
                              ? Color.blue
                              : Color.blue.opacity(0.4))
                        .frame(height: barHeight(for: data[index]))
                    
                    Text(dayNames[index])
                        .font(.system(size: 11, weight:
                            index == currentDayIndex() ? .medium : .regular,
                            design: .rounded))
                        .foregroundColor(
                            index == currentDayIndex() ? .primary : .secondary)
                }
            }
        }
    }
    
    private func barHeight(for value: Int) -> CGFloat {
        let maxHeight: CGFloat = 80
        guard maxValue > 0 else { return 4 }
        let height = (CGFloat(value) / CGFloat(maxValue)) * maxHeight
        return max(height, 4)
    }
    
    private func currentDayIndex() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }
}

#Preview {
    DashboardView()
        .environment(DataStore())
}
