//
//  RewardPopup.swift
//  UnPluq
//
//  Created by Fotios Pongas on 24.03.26.
//
// RewardPopup.swift
// Unpluq
//
// Εμφανίζεται όταν ξεκλειδώνεται reward — minimal, zen celebration.

import SwiftUI

struct RewardPopup: View {
    let reward: Reward
    let language: String
    let onClaim: () -> Void
    let onDismiss: () -> Void
    
    @Environment(RewardManager.self) var rewardManager
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon based on reward type
            rewardIcon
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            // Title
            Text(rewardManager.localizedTitle(for: reward, language: language))
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
            
            // Description
            Text(rewardManager.localizedDescription(for: reward, language: language))
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // "You earned this" message
            Text(language == "Ελληνικά"
                 ? "Τα κατάφερες! Βελτιώθηκες."
                 : language == "Deutsch"
                 ? "Geschafft! Du hast dich verbessert."
                 : "You did it! You improved.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Claim button
            Button(action: onClaim) {
                Text(claimButtonText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.blue)
                    )
            }
            
            // Dismiss
            Button(action: onDismiss) {
                Text(language == "Ελληνικά" ? "Αργότερα" : language == "Deutsch" ? "Später" : "Later")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
                .frame(height: 40)
        }
    }
    
    private var rewardIcon: some View {
        Group {
            switch reward.type {
            case .quotePack:
                Image(systemName: "text.quote")
            case .badge:
                Image(systemName: "star.circle.fill")
            case .giftCode:
                Image(systemName: "gift.fill")
            }
        }
    }
    
    private var claimButtonText: String {
        switch reward.type {
        case .quotePack:
            return language == "Ελληνικά" ? "Ξεκλείδωσε quotes" : "Unlock quotes"
        case .badge:
            return language == "Ελληνικά" ? "Αποδοχή" : "Claim badge"
        case .giftCode:
            return language == "Ελληνικά" ? "Μοιράσου με φίλο" : "Share with a friend"
        }
    }
}

