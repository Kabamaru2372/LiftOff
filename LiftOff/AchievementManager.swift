import Foundation
import SwiftUI

// MARK: - Rank

enum PicksyRank: Int, CaseIterable {
    case rookie = 0, aware, mindful, focused, zen, master

    var title: String      { ["Rookie","Aware","Mindful","Focused","Zen","Master"][rawValue] }
    var titleGR: String    { ["Αρχάριος","Συνειδητός","Προσεκτικός","Εστιασμένος","Ζεν","Δάσκαλος"][rawValue] }
    var titleDE: String    { ["Anfänger","Bewusst","Achtsam","Fokussiert","Zen","Meister"][rawValue] }
    var emoji: String      { ["🌱","👁","🧘","🎯","🌸","🏆"][rawValue] }

    var color: Color {
        switch self {
        case .rookie:  return .gray
        case .aware:   return .blue
        case .mindful: return .green
        case .focused: return .orange
        case .zen:     return .purple
        case .master:  return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }

    var xpRequired: Int { [0, 80, 200, 450, 900, 1600][rawValue] }
    var nextRank: PicksyRank? { PicksyRank(rawValue: rawValue + 1) }

    static func rank(for xp: Int) -> PicksyRank {
        PicksyRank.allCases.reversed().first { xp >= $0.xpRequired } ?? .rookie
    }
}

// MARK: - Badge Definition

struct BadgeDefinition {
    let id: String
    let emoji: String
    let title: String, titleGR: String, titleDE: String
    let desc: String,  descGR: String,  descDE: String
    let xpReward: Int
}

// MARK: - Achievement Manager

@Observable
class AchievementManager {

    static let shared = AchievementManager()

    var totalXP: Int = 0
    var unlockedBadgeIds: Set<String> = []
    var focusPerfectSessions: Int = 0
    var bestDayPickups: Int = Int.max    // lowest ever (lower = better)
    var duelWins: Int = 0
    var bestStreak: Int = 0
    var pendingBadgeId: String? = nil   // drives unlock popup

    var currentRank: PicksyRank { PicksyRank.rank(for: totalXP) }

    var xpToNextRank: Int {
        guard let next = currentRank.nextRank else { return 0 }
        return next.xpRequired - currentRank.xpRequired
    }
    var xpInCurrentRank: Int { totalXP - currentRank.xpRequired }

    var rankProgress: Double {
        guard xpToNextRank > 0 else { return 1.0 }
        return min(1.0, Double(xpInCurrentRank) / Double(xpToNextRank))
    }

    // MARK: - Pro-only badge IDs (last 2 of 12)
    // Free tier can earn the first 10. month_tracker and personal_best require Pro.
    static let proOnlyBadgeIds: Set<String> = ["month_tracker", "personal_best"]

    // MARK: - All 12 badges

    static let allBadges: [BadgeDefinition] = [
        BadgeDefinition(id: "first_day",     emoji: "📱",
            title: "First Step",       titleGR: "Πρώτο Βήμα",         titleDE: "Erster Schritt",
            desc:  "Track your first day",
            descGR:"Παρακολούθησε την πρώτη σου μέρα",
            descDE:"Deinen ersten Tag verfolgt",
            xpReward: 15),
        BadgeDefinition(id: "first_week",    emoji: "🗓",
            title: "First Week",       titleGR: "Πρώτη Εβδομάδα",     titleDE: "Erste Woche",
            desc:  "Track 7 days total",
            descGR:"7 ημέρες παρακολούθησης",
            descDE:"7 Tage verfolgt",
            xpReward: 20),
        BadgeDefinition(id: "under_goal",    emoji: "🎯",
            title: "On Target",        titleGR: "Στο Στόχο",           titleDE: "Auf Kurs",
            desc:  "First day under your daily goal",
            descGR:"Πρώτη μέρα κάτω από τον στόχο",
            descDE:"Erster Tag unter dem Tagesziel",
            xpReward: 20),
        BadgeDefinition(id: "hat_trick",     emoji: "🔥",
            title: "Hat Trick",        titleGR: "Χατ Τρικ",            titleDE: "Hattrick",
            desc:  "3 days in a row under goal",
            descGR:"3 συνεχόμενες μέρες κάτω από τον στόχο",
            descDE:"3 Tage in Folge unter dem Ziel",
            xpReward: 30),
        BadgeDefinition(id: "week_warrior",  emoji: "💪",
            title: "Week Warrior",     titleGR: "Πολεμιστής",          titleDE: "Wochenkämpfer",
            desc:  "7 days in a row under goal",
            descGR:"7 συνεχόμενες μέρες κάτω από τον στόχο",
            descDE:"7 Tage in Folge unter dem Ziel",
            xpReward: 50),
        BadgeDefinition(id: "perfect_ten",   emoji: "⚡",
            title: "Light Touch",      titleGR: "Ελαφρύ Άγγιγμα",     titleDE: "Leichte Berührung",
            desc:  "Under 10 pickups in a day",
            descGR:"Κάτω από 10 σηκώματα σε μια μέρα",
            descDE:"Unter 10 Griffe an einem Tag",
            xpReward: 25),
        BadgeDefinition(id: "minimalist",    emoji: "✨",
            title: "Minimalist",       titleGR: "Μινιμαλιστής",        titleDE: "Minimalist",
            desc:  "Under 5 pickups in a day",
            descGR:"Κάτω από 5 σηκώματα σε μια μέρα",
            descDE:"Unter 5 Griffe an einem Tag",
            xpReward: 35),
        BadgeDefinition(id: "big_drop",      emoji: "📉",
            title: "Big Drop",         titleGR: "Μεγάλη Πτώση",       titleDE: "Großer Rückgang",
            desc:  "Beat yesterday by 15+ pickups",
            descGR:"Καλύτερος από χθες κατά 15+ σηκώματα",
            descDE:"15+ Griffe weniger als gestern",
            xpReward: 25),
        BadgeDefinition(id: "focus_starter", emoji: "⏱",
            title: "Focus Starter",    titleGR: "Πρώτη Εστίαση",      titleDE: "Fokus-Starter",
            desc:  "Complete a focus session with 0 pickups",
            descGR:"Σύνοδος εστίασης με 0 σηκώματα",
            descDE:"Fokus-Session mit 0 Griffen",
            xpReward: 25),
        BadgeDefinition(id: "focus_master",  emoji: "🏅",
            title: "Focus Master",     titleGR: "Μάστερ Εστίασης",    titleDE: "Fokus-Meister",
            desc:  "Complete 5 perfect focus sessions",
            descGR:"5 τέλειες συνόδους εστίασης",
            descDE:"5 perfekte Fokus-Sessions",
            xpReward: 50),
        BadgeDefinition(id: "month_tracker", emoji: "📅",
            title: "Month Tracker",    titleGR: "Μήνας Παρακολούθησης",titleDE: "Monats-Tracker",
            desc:  "Track 30 days total",
            descGR:"30 ημέρες παρακολούθησης",
            descDE:"30 Tage verfolgt",
            xpReward: 40),
        BadgeDefinition(id: "personal_best", emoji: "🏆",
            title: "Personal Best",    titleGR: "Προσωπικό Ρεκόρ",    titleDE: "Persönlicher Rekord",
            desc:  "Achieve your lowest pickup count ever",
            descGR:"Το χαμηλότερο ρεκόρ σηκωμάτων σου",
            descDE:"Dein niedrigstes Griff-Ergebnis",
            xpReward: 30),
        BadgeDefinition(id: "duel_first_win", emoji: "🥊",
            title: "First Blood",      titleGR: "Πρώτη Νίκη",          titleDE: "Erster Sieg",
            desc:  "Win your first duel",
            descGR:"Νίκη στην πρώτη σου μονομαχία",
            descDE:"Dein erstes Duell gewonnen",
            xpReward: 25),
        BadgeDefinition(id: "duel_fighter",   emoji: "⚔️",
            title: "Fighter",          titleGR: "Μαχητής",              titleDE: "Kämpfer",
            desc:  "Win 5 duels",
            descGR:"Νίκη σε 5 μονομαχίες",
            descDE:"5 Duelle gewonnen",
            xpReward: 40),
        BadgeDefinition(id: "duel_champion",  emoji: "👑",
            title: "Duel Champion",    titleGR: "Πρωταθλητής",          titleDE: "Duell-Champion",
            desc:  "Win 10 duels",
            descGR:"Νίκη σε 10 μονομαχίες",
            descDE:"10 Duelle gewonnen",
            xpReward: 60),
    ]

    private let defaults = UserDefaults.standard

    private init() { load() }

    // MARK: - Public API

    /// Called from DataStore.checkNewDay() BEFORE resetting todayPickups
    func onDayCompleted(pickups: Int, goal: Int, streak: Int, totalDays: Int, previousDayPickups: Int) {
        guard pickups > 0 else { return }

        // XP for the day
        var xp = 0
        if pickups <= goal {
            xp += 10
            if streak >= 3 { xp += min(streak, 7) }
        } else if pickups <= Int(Double(goal) * 1.5) {
            xp += 2
        } else {
            xp = max(xp - 5, -totalXP)
        }
        addXP(xp)

        // Badge checks
        if totalDays >= 1  { unlock("first_day",     xp: 15) }
        if totalDays >= 7  { unlock("first_week",    xp: 20) }
        if totalDays >= 30 && ProManager.shared.isPro { unlock("month_tracker", xp: 40) }
        if pickups <= goal { unlock("under_goal",    xp: 20) }
        if streak >= 3     { unlock("hat_trick",     xp: 30) }
        if streak >= 7     { unlock("week_warrior",  xp: 50) }
        if pickups < 10    { unlock("perfect_ten",   xp: 25) }
        if pickups < 5     { unlock("minimalist",    xp: 35) }
        if previousDayPickups > 0 && (previousDayPickups - pickups) >= 15 {
            unlock("big_drop", xp: 25)
        }
        // Personal best (lower is better) — Pro only
        if pickups < bestDayPickups {
            let wasSet = bestDayPickups != Int.max
            bestDayPickups = pickups
            defaults.set(bestDayPickups, forKey: "ach_bestDay")
            if wasSet && ProManager.shared.isPro { unlock("personal_best", xp: 30) }
        }
        // Best streak ever
        if streak > bestStreak {
            bestStreak = streak
            defaults.set(bestStreak, forKey: "ach_bestStreak")
        }
    }

    /// Called from DuelManager.finalizeDuel() when the local user wins a duel.
    func onDuelWon() {
        duelWins += 1
        defaults.set(duelWins, forKey: "ach_duelWins")
        addXP(15)
        unlock("duel_first_win", xp: 25)
        if duelWins >= 5  { unlock("duel_fighter",  xp: 40) }
        if duelWins >= 10 { unlock("duel_champion", xp: 60) }
    }

    /// Called when a perfect focus session (0 pickups) completes
    func onFocusPerfectSession() {
        focusPerfectSessions += 1
        defaults.set(focusPerfectSessions, forKey: "ach_focusPerfect")
        addXP(8)
        unlock("focus_starter", xp: 25)
        if focusPerfectSessions >= 5 { unlock("focus_master", xp: 50) }
    }

    func dismissPendingBadge() { pendingBadgeId = nil }

    func isUnlocked(_ id: String) -> Bool { unlockedBadgeIds.contains(id) }

    func localized(badge: BadgeDefinition, language: String) -> (title: String, desc: String) {
        switch language {
        case "Ελληνικά": return (badge.titleGR, badge.descGR)
        case "Deutsch":  return (badge.titleDE, badge.descDE)
        default:         return (badge.title,   badge.desc)
        }
    }

    func localizedRankTitle(language: String) -> String {
        switch language {
        case "Ελληνικά": return currentRank.titleGR
        case "Deutsch":  return currentRank.titleDE
        default:         return currentRank.title
        }
    }

    // MARK: - Private

    private func addXP(_ amount: Int) {
        totalXP = max(0, totalXP + amount)
        defaults.set(totalXP, forKey: "ach_totalXP")
    }

    private func unlock(_ id: String, xp: Int) {
        guard !unlockedBadgeIds.contains(id) else { return }
        unlockedBadgeIds.insert(id)
        save()
        if pendingBadgeId == nil { pendingBadgeId = id }
        addXP(xp)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Array(unlockedBadgeIds)) {
            defaults.set(data, forKey: "ach_badgeIds")
        }
    }

    private func load() {
        totalXP              = defaults.integer(forKey: "ach_totalXP")
        focusPerfectSessions = defaults.integer(forKey: "ach_focusPerfect")
        duelWins             = defaults.integer(forKey: "ach_duelWins")
        bestStreak           = defaults.integer(forKey: "ach_bestStreak")
        let best             = defaults.integer(forKey: "ach_bestDay")
        bestDayPickups       = best > 0 ? best : Int.max

        if let data = defaults.data(forKey: "ach_badgeIds"),
           let ids  = try? JSONDecoder().decode([String].self, from: data) {
            unlockedBadgeIds = Set(ids)
        }
    }
}
