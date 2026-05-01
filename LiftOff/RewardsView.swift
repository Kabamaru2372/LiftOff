//
//  RewardsView.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.03.26.

import SwiftUI

struct RewardsView: View {
    @Environment(RewardManager.self) var rewardManager
    @Environment(ProManager.self) var proManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @State private var showShareSheet: Bool = false
    @State private var shareText: String = ""
    @State private var showTrialAlert: Bool = false

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                Text(t("Rewards", "Επιβραβεύσεις", "Belohnungen"))
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .padding(.top, 20)

                Text(t(
                    "Improve during your worst hours for 2 days to unlock rewards!",
                    "Βελτιώσου στις χειρότερες ώρες σου για 2 μέρες και ξεκλείδωσε rewards!",
                    "Verbessere dich 2 Tage lang in deinen schlechtesten Stunden und schalte Belohnungen frei!"
                ))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .lineSpacing(4)

                if !rewardManager.unlockedRewards.isEmpty {
                    Text(t("Unlocked", "Ξεκλειδωμένα", "Freigeschaltet"))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    ForEach(rewardManager.unlockedRewards) { reward in
                        UnlockedRewardCard(
                            reward: reward,
                            language: appLanguage,
                            rewardManager: rewardManager,
                            onClaim: { handleClaim(reward) },
                            onPayItForward: { triggerPayItForward(reward) }
                        )
                    }
                }

                Text(t("Available", "Διαθέσιμα", "Verfügbar"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                ForEach(lockedRewards, id: \.title) { item in
                    RewardCard(
                        icon: iconForType(item.type),
                        iconColor: .secondary,
                        title: appLanguage == "Ελληνικά" ? item.titleGR :
                               appLanguage == "Deutsch" ? item.titleDE : item.title,
                        description: appLanguage == "Ελληνικά" ? item.descriptionGR :
                                     appLanguage == "Deutsch" ? item.descriptionDE : item.description,
                        isLocked: true
                    )
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: shareText)
        }
        .alert(
            t("You earned 7 days of Pro!", "Κέρδισες 7 μέρες Pro!", "Du hast 7 Tage Pro gewonnen!"),
            isPresented: $showTrialAlert
        ) {
            Button("OK") {}
        } message: {
            Text(t(
                "Thanks for sharing Picksy! Your 7-day Pro trial has been activated. Enjoy all the features!",
                "Ευχαριστούμε που μοιράστηκες το Picksy! Το 7ήμερο Pro trial σου ενεργοποιήθηκε. Απόλαυσε όλα τα features!",
                "Danke fürs Teilen von Picksy! Dein 7-tägiger Pro-Test wurde aktiviert. Genieße alle Funktionen!"
            ))
        }
    }

    // MARK: - Actions

    private func handleClaim(_ reward: Reward) {
        if reward.type == .quotePack, let pack = reward.quotePack {
            QuoteBank.enablePack(pack)
        }
        rewardManager.claimReward(reward)
    }

    private func triggerPayItForward(_ reward: Reward) {
        // Ο χρήστης που μοιράζεται παίρνει 7 μέρες Pro
        proManager.startTrial()

        // Share text με app link
        shareText = t(
            "I use Picksy to be more mindful with my phone. It counts every time you pick it up — no subscriptions, no data collection, completely free. Download it here: https://apps.apple.com/app/picksy-be-present/id6761116771",
            "Χρησιμοποιώ το Picksy για να γίνω πιο συνειδητός με το κινητό μου. Μετράει κάθε φορά που το σηκώνεις — χωρίς συνδρομές, χωρίς δεδομένα, εντελώς δωρεάν. Κατέβασέ το εδώ: https://apps.apple.com/app/picksy-be-present/id6761116771",
            "Ich nutze Picksy, um bewusster mit meinem Handy umzugehen. Es zählt jeden Griff — keine Abos, keine Daten, komplett kostenlos. Hier herunterladen: https://apps.apple.com/app/picksy-be-present/id6761116771"
        )

        showShareSheet = true
        showTrialAlert = true
        rewardManager.claimReward(reward)
    }

    private var lockedRewards: [(type: RewardType, title: String, titleGR: String, titleDE: String, description: String, descriptionGR: String, descriptionDE: String)] {
        let unlockedTitles = Set(rewardManager.unlockedRewards.map { $0.title })
        return RewardManager.availableRewards
            .filter { !unlockedTitles.contains($0.title) }
            .map { (type: $0.type, title: $0.title, titleGR: $0.titleGR, titleDE: $0.titleDE, description: $0.description, descriptionGR: $0.descriptionGR, descriptionDE: $0.descriptionDE) }
    }

    private func iconForType(_ type: RewardType) -> String {
        switch type {
        case .quotePack: return "text.quote"
        case .badge: return "star.circle.fill"
        case .giftCode: return "gift.fill"
        }
    }
}

// MARK: - Unlocked Reward Card

struct UnlockedRewardCard: View {
    let reward: Reward
    let language: String
    let rewardManager: RewardManager
    let onClaim: () -> Void
    let onPayItForward: () -> Void

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch language {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: iconForType(reward.type))
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.blue.opacity(0.1)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(rewardManager.localizedTitle(for: reward, language: language))
                        .font(.system(size: 15, weight: .medium, design: .rounded))

                    Text(rewardManager.localizedDescription(for: reward, language: language))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if reward.type == .badge {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
            }

            if !reward.claimed {
                if reward.type == .quotePack {
                    Button(action: onClaim) {
                        Text(t("Activate", "Ενεργοποίησε", "Aktivieren"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                    }
                } else if reward.type == .giftCode {
                    Button(action: onPayItForward) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                            Text(t(
                                "Share & get 7 days Pro free!",
                                "Μοιράσου και κέρδισε 7 μέρες Pro!",
                                "Teilen & 7 Tage Pro kostenlos!"
                            ))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                    }
                }
            } else if reward.type == .quotePack {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundColor(.green)
                    Text(t("Active", "Ενεργό", "Aktiv"))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.green)
                }
            } else if reward.type == .giftCode {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundColor(.green)
                    Text(t("Shared!", "Μοιράστηκε!", "Geteilt!"))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.3), lineWidth: 0.5))
        )
    }

    private func iconForType(_ type: RewardType) -> String {
        switch type {
        case .quotePack: return "text.quote"
        case .badge: return "star.circle.fill"
        case .giftCode: return "gift.fill"
        }
    }
}

// MARK: - Locked Reward Card

struct RewardCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(isLocked ? Color(.systemGray6) : Color.blue.opacity(0.1)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(isLocked ? .secondary : .primary)
                    if isLocked {
                        Image(systemName: "lock.fill").font(.system(size: 10)).foregroundColor(.secondary)
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
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 0.5))
        )
        .opacity(isLocked ? 0.7 : 1.0)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    RewardsView()
        .environment(RewardManager())
        .environment(ProManager.shared)
}

