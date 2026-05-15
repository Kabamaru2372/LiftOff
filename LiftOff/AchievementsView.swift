import SwiftUI

// MARK: - Achievements View

struct AchievementsView: View {

    @Environment(AchievementManager.self) private var achievementManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @State private var selectedBadge: BadgeDefinition? = nil
    @State private var bannerVisible: Bool = false
    @State private var bannerDismissTask: Task<Void, Never>? = nil

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 20) {
                    // Section 1: Rank Card
                    rankCard

                    // Section 2: Badges
                    badgesSection

                    // Section 3: XP Summary
                    xpSummary
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            // Badge unlock banner
            if bannerVisible, let badgeId = achievementManager.pendingBadgeId,
               let badge = AchievementManager.allBadges.first(where: { $0.id == badgeId }) {
                badgeUnlockBanner(badge: badge)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .navigationTitle(t("Achievements", "Επιτεύγματα", "Errungenschaften"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailSheet(badge: badge, isUnlocked: achievementManager.isUnlocked(badge.id))
                .environment(achievementManager)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: achievementManager.pendingBadgeId) { _, newId in
            if newId != nil {
                showBanner()
            }
        }
    }

    // MARK: - Rank Card

    private var rankCard: some View {
        let rank = achievementManager.currentRank
        return VStack(spacing: 12) {
            Text(rank.emoji)
                .font(.system(size: 56))

            Text(achievementManager.localizedRankTitle(language: appLanguage))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            if rank == .master {
                Text(t("Max Rank", "Μέγιστη Βαθμίδα", "Maximaler Rang") + " 🏆")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(rank.color)
            } else {
                // XP display
                HStack(spacing: 4) {
                    Text("\(achievementManager.totalXP)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(rank.color)
                    Text("/")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    if let next = rank.nextRank {
                        Text("\(next.xpRequired) XP")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(rank.color.opacity(0.15))
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(rank.color)
                            .frame(width: max(0, geo.size.width * achievementManager.rankProgress), height: 10)
                            .animation(.easeInOut(duration: 0.8), value: achievementManager.rankProgress)
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, 8)

                // Next rank hint
                if let next = rank.nextRank {
                    Text(t("Next: ", "Επόμενη: ", "Nächste: ") + next.emoji + " " + {
                        switch appLanguage {
                        case "Ελληνικά": return next.titleGR
                        case "Deutsch":  return next.titleDE
                        default:         return next.title
                        }
                    }())
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(rank.color.opacity(0.12))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(rank.color.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Badges Section

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Achievements", "Επιτεύγματα", "Errungenschaften"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AchievementManager.allBadges, id: \.id) { badge in
                    BadgeCell(
                        badge: badge,
                        isUnlocked: achievementManager.isUnlocked(badge.id),
                        rank: achievementManager.currentRank,
                        language: appLanguage
                    )
                    .onTapGesture {
                        selectedBadge = badge
                    }
                }
            }
        }
    }

    // MARK: - XP Summary

    private var xpSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("\(achievementManager.unlockedBadgeIds.count) \(t("badges unlocked", "badges ξεκλειδωμένα", "Badges freigeschaltet"))")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            Text("·")
                .foregroundColor(.secondary)
            Text("\(achievementManager.totalXP) XP \(t("total", "σύνολο", "gesamt"))")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.6))
        )
    }

    // MARK: - Banner

    private func badgeUnlockBanner(badge: BadgeDefinition) -> some View {
        let (title, _) = achievementManager.localized(badge: badge, language: appLanguage)
        return HStack(spacing: 12) {
            Text(badge.emoji)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(t("Badge Unlocked!", "Badge Ξεκλειδώθηκε!", "Badge freigeschaltet!"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onTapGesture {
            dismissBanner()
        }
    }

    private func showBanner() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            bannerVisible = true
        }
        bannerDismissTask?.cancel()
        bannerDismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                await MainActor.run { dismissBanner() }
            }
        }
    }

    private func dismissBanner() {
        withAnimation(.easeOut(duration: 0.3)) {
            bannerVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            achievementManager.dismissPendingBadge()
        }
    }
}

// MARK: - Badge Cell

struct BadgeCell: View {
    let badge: BadgeDefinition
    let isUnlocked: Bool
    let rank: PicksyRank
    let language: String

    private var localizedTitle: String {
        switch language {
        case "Ελληνικά": return badge.titleGR
        case "Deutsch":  return badge.titleDE
        default:         return badge.title
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? rank.color.opacity(0.12) : Color(.systemGray5).opacity(0.5))
                    .frame(width: 64, height: 64)

                Text(badge.emoji)
                    .font(.system(size: 28))
                    .opacity(isUnlocked ? 1.0 : 0.3)
            }

            Text(localizedTitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 28)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .opacity(isUnlocked ? 1.0 : 0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isUnlocked ? rank.color.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Badge Detail Sheet

struct BadgeDetailSheet: View {
    let badge: BadgeDefinition
    let isUnlocked: Bool

    @Environment(AchievementManager.self) private var achievementManager
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @Environment(\.dismiss) private var dismiss

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    private var localizedTitle: String {
        switch appLanguage {
        case "Ελληνικά": return badge.titleGR
        case "Deutsch":  return badge.titleDE
        default:         return badge.title
        }
    }

    private var localizedDesc: String {
        switch appLanguage {
        case "Ελληνικά": return badge.descGR
        case "Deutsch":  return badge.descDE
        default:         return badge.desc
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Drag indicator
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            // Emoji
            Text(badge.emoji)
                .font(.system(size: 72))

            // Title & status
            VStack(spacing: 8) {
                Text(localizedTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                if isUnlocked {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(t("Unlocked!", "Ξεκλειδώθηκε!", "Freigeschaltet!"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                        Text(t("Locked", "Κλειδωμένο", "Gesperrt"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Description
            Text(localizedDesc)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // XP reward
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                Text("+\(badge.xpReward) XP")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.12))
            )

            Spacer()

            Button {
                dismiss()
            } label: {
                Text(t("Close", "Κλείσιμο", "Schließen"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - BadgeDefinition: Identifiable

extension BadgeDefinition: Identifiable {}

// MARK: - Preview

#Preview {
    NavigationStack {
        AchievementsView()
            .timeGradientBackground()
            .environment(AchievementManager.shared)
            .environment(WeatherManager())
    }
}
