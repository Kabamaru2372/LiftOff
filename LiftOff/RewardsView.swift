//
//  RewardsView.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
// Δείχνει τα rewards — ξεκλειδωμένα και κλειδωμένα.
// Ο χρήστης βλέπει τι έχει κερδίσει και τι μπορεί να κερδίσει.

import SwiftUI

struct RewardsView: View {
    @Environment(RewardManager.self) var rewardManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    
    private var isGreek: Bool { appLanguage == "Ελληνικά" }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                Text(isGreek ? "Επιβραβεύσεις" : "Rewards")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .padding(.top, 20)
                
                Text(isGreek
                     ? "Βελτιώσου στις χειρότερες ώρες σου για 2 μέρες και ξεκλείδωσε rewards!"
                     : "Improve during your worst hours for 2 days to unlock rewards!")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                
                // Unlocked rewards
                if !rewardManager.unlockedRewards.isEmpty {
                    Text(isGreek ? "Ξεκλειδωμένα" : "Unlocked")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    ForEach(rewardManager.unlockedRewards) { reward in
                        RewardCard(
                            icon: iconForType(reward.type),
                            iconColor: .blue,
                            title: rewardManager.localizedTitle(for: reward, language: appLanguage),
                            description: rewardManager.localizedDescription(for: reward, language: appLanguage),
                            isLocked: false
                        )
                    }
                }
                
                // Locked rewards
                Text(isGreek ? "Διαθέσιμα" : "Available")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                ForEach(lockedRewards, id: \.title) { item in
                    RewardCard(
                        icon: iconForType(item.type),
                        iconColor: .secondary,
                        title: isGreek ? item.titleGR : item.title,
                        description: isGreek ? item.descriptionGR : item.description,
                        isLocked: true
                    )
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // Rewards που δεν έχουν ξεκλειδωθεί ακόμα
    private var lockedRewards: [(type: RewardType, title: String, titleGR: String, description: String, descriptionGR: String)] {
        let unlockedTitles = Set(rewardManager.unlockedRewards.map { $0.title })
        return RewardManager.availableRewards
            .filter { !unlockedTitles.contains($0.title) }
            .map { (type: $0.type, title: $0.title, titleGR: $0.titleGR, description: $0.description, descriptionGR: $0.descriptionGR) }
    }
    
    private func iconForType(_ type: RewardType) -> String {
        switch type {
        case .quotePack: return "text.quote"
        case .badge: return "star.circle.fill"
        case .giftCode: return "gift.fill"
        }
    }
}

// MARK: - Reward Card Component

struct RewardCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isLocked: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isLocked
                              ? Color(.systemGray6)
                              : Color.blue.opacity(0.1))
                )
            
            // Text
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(isLocked ? .secondary : .primary)
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(description)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isLocked
                                ? Color(.systemGray5)
                                : Color.blue.opacity(0.3),
                                lineWidth: 0.5)
                )
        )
        .opacity(isLocked ? 0.7 : 1.0)
    }
}

#Preview {
    RewardsView()
        .environment(RewardManager())
}

