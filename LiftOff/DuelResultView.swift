// DuelResultView.swift
// Picksy
//
// Full-screen result sheet shown when a duel completes.
// Triggered automatically when the user opens the Friends tab
// after a duel has ended (e.g. via the completion push notification).

import SwiftUI

// MARK: - Confetti Particle
// All random values stored at init time — never recomputed during renders.

private struct Particle: Identifiable {
    let id       = UUID()
    let color:   Color
    let offsetX: CGFloat
    let offsetY: CGFloat
    let scale:   CGFloat
    let delay:   Double   // stored once, never changes
    let isEmoji: Bool
    let emoji:   String
}

private func makeParticles() -> [Particle] {
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan]
    let emojis = ["🎉", "⭐", "✨", "💫", "🏆"]
    return (0..<24).map { i in
        let angle = Double(i) / 24.0 * 2 * .pi + Double.random(in: -0.4...0.4)
        let dist  = CGFloat.random(in: 100...240)
        return Particle(
            color:   colors[i % colors.count],
            offsetX: cos(angle) * dist,
            offsetY: sin(angle) * dist,
            scale:   CGFloat.random(in: 0.5...1.0),
            delay:   Double(i) * 0.025,          // evenly staggered, deterministic
            isEmoji: i % 5 == 0,
            emoji:   emojis[i % emojis.count]
        )
    }
}

// MARK: - DuelResultView

struct DuelResultView: View {

    let duel: DuelRecord
    let hourlyData: [Int]   // today's hourly pickups (index = hour)

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @State private var animateHero     = false
    @State private var animateScore    = false
    @State private var animateAnalysis = false
    @State private var particlesOut    = false

    // Particles created once — static per view instance
    private let particles = makeParticles()

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            // Confetti — only when won, only 24 particles
            if duel.iWon && particlesOut {
                ForEach(particles) { p in
                    Group {
                        if p.isEmoji {
                            Text(p.emoji).font(.system(size: 18 * p.scale))
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(p.color)
                                .frame(width: 9 * p.scale, height: 9 * p.scale)
                        }
                    }
                    .offset(x: p.offsetX, y: p.offsetY)
                    .opacity(0)                              // fade out after burst
                    .animation(
                        .easeOut(duration: 1.0).delay(p.delay),
                        value: particlesOut
                    )
                }
            }

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)
                    heroSection
                    scoreCard
                    if totalPickups > 0 { analysisCard }
                    closeButton
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                animateHero = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25)) {
                animateScore = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.45)) {
                animateAnalysis = true
            }
            if duel.iWon {
                withAnimation(.easeOut(duration: 0.1).delay(0.1)) {
                    particlesOut = true
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            Text(duel.isTie ? "🤝" : (duel.iWon ? "🏆" : "📱"))
                .font(.system(size: 76))
                .scaleEffect(animateHero ? 1 : 0.3)
                .opacity(animateHero ? 1 : 0)

            VStack(spacing: 6) {
                Text(duel.isTie
                     ? t("It's a Tie!", "Ισοπαλία!", "Unentschieden!")
                     : (duel.iWon
                        ? t("You Won! 🎉", "Κέρδισες! 🎉", "Du hast gewonnen! 🎉")
                        : t("You Lost", "Έχασες", "Du hast verloren")))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(duel.isTie
                     ? t("Equally disciplined today.", "Ίσα-ίσα σήμερα.", "Heute gleichauf.")
                     : (duel.iWon
                        ? t("You picked up less than \(duel.theirName).", "Πήρες το κινητό λιγότερο από τον \(duel.theirName).", "Du hast seltener als \(duel.theirName) gegriffen.")
                        : t("\(duel.theirName) was more disciplined today.", "Ο \(duel.theirName) ήταν πιο πειθαρχημένος σήμερα.", "\(duel.theirName) war heute disziplinierter.")))
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .scaleEffect(animateHero ? 1 : 0.8)
            .opacity(animateHero ? 1 : 0)
        }
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        VStack(spacing: 14) {
            Text(t("Final Score", "Τελικό Σκορ", "Endstand"))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .tracking(1)

            HStack(spacing: 0) {
                // My side
                VStack(spacing: 4) {
                    Text(t("You", "Εσύ", "Du"))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(duel.myPickups)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(
                            duel.iWon  ? Color(red: 0.4, green: 1.0, blue: 0.6) :
                            duel.iLost ? Color(red: 1.0, green: 0.38, blue: 0.38) : .white
                        )
                    if duel.iWon {
                        Label(t("Winner", "Νικητής", "Sieger"), systemImage: "crown.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.2))
                    }
                }
                .frame(maxWidth: .infinity)

                Text("–")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(width: 32)

                // Opponent side
                VStack(spacing: 4) {
                    Text(duel.theirName)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    let theirDisplay = (duel.theirPickups == 0 && duel.myPickups > 0) ? "?" : "\(duel.theirPickups)"
                    Text(theirDisplay)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(
                            duel.iLost ? Color(red: 0.4, green: 1.0, blue: 0.6) :
                            duel.iWon  ? Color(red: 1.0, green: 0.38, blue: 0.38) : .white
                        )
                    if duel.iLost {
                        Label(t("Winner", "Νικητής", "Sieger"), systemImage: "crown.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.2))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.12)))
        }
        .opacity(animateScore ? 1 : 0)
        .offset(y: animateScore ? 0 : 24)
    }

    // MARK: - Hourly Analysis

    private var totalPickups: Int { hourlyData.reduce(0, +) }

    // Precomputed period data — stable, not recomputed per-render
    private var periods: [(name: String, count: Int, icon: String)] {[
        (t("Morning",   "Πρωί",      "Morgen"),    hourlyData[6..<12].reduce(0, +),  "sunrise.fill"),
        (t("Afternoon", "Μεσημέρι",  "Mittag"),    hourlyData[12..<18].reduce(0, +), "sun.max.fill"),
        (t("Evening",   "Βράδυ",     "Abend"),     hourlyData[18..<24].reduce(0, +), "moon.stars.fill"),
        (t("Night",     "Νύχτα",     "Nacht"),     hourlyData[0..<6].reduce(0, +),   "moon.zzz.fill")
    ]}

    private var analysisCard: some View {
        let ps       = periods
        let maxVal   = max(1, ps.map(\.count).max() ?? 1)
        let peakName = ps.max(by: { $0.count < $1.count })?.name ?? ""

        return VStack(alignment: .leading, spacing: 14) {
            Text(t("Your Day", "Η Μέρα Σου", "Dein Tag"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .tracking(0.5)

            VStack(spacing: 10) {
                ForEach(Array(ps.enumerated()), id: \.offset) { idx, period in
                    HStack(spacing: 10) {
                        Image(systemName: period.icon)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.55))
                            .frame(width: 18)

                        Text(period.name)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 72, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.1))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor(count: period.count, max: maxVal))
                                    .frame(
                                        width: animateAnalysis
                                            ? max(4, geo.size.width * CGFloat(period.count) / CGFloat(maxVal))
                                            : 4
                                    )
                                    .animation(
                                        .spring(response: 0.6).delay(0.5 + Double(idx) * 0.08),
                                        value: animateAnalysis
                                    )
                            }
                        }
                        .frame(height: 8)

                        Text("\(period.count)")
                            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundColor(.white.opacity(0.65))
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }

            if !peakName.isEmpty && totalPickups > 0 {
                Text("📊 " + t(
                    "Most pickups in the \(peakName.lowercased()).",
                    "Τα περισσότερα σηκώματα το \(peakName.lowercased()).",
                    "Die meisten Griffe am \(peakName.lowercased())."
                ))
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 2)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.1)))
        .opacity(animateAnalysis ? 1 : 0)
        .offset(y: animateAnalysis ? 0 : 24)
    }

    private func barColor(count: Int, max: Int) -> Color {
        let r = Double(count) / Double(max)
        if r > 0.7 { return Color(red: 1.0, green: 0.45, blue: 0.35) }
        if r > 0.4 { return Color(red: 1.0, green: 0.75, blue: 0.35) }
        return Color(red: 0.45, green: 0.9, blue: 0.65)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Text(t("Done", "Τέλος", "Fertig"))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.18)))
        }
        .opacity(animateAnalysis ? 1 : 0)
        .animation(.easeIn.delay(0.7), value: animateAnalysis)
    }

    // MARK: - Background

    private var background: LinearGradient {
        duel.iWon  ? LinearGradient(colors: [Color(red: 0.08, green: 0.32, blue: 0.14), Color(red: 0.04, green: 0.18, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing) :
        duel.iLost ? LinearGradient(colors: [Color(red: 0.18, green: 0.10, blue: 0.28), Color(red: 0.10, green: 0.07, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                     LinearGradient(colors: [Color(red: 0.14, green: 0.14, blue: 0.26), Color(red: 0.08, green: 0.08, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
