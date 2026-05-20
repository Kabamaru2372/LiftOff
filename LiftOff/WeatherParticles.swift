//
//  WeatherParticles.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.04.2026
//
//  Level 3 particles:
//  - Realistic clouds με gradients & shadows
//  - Multi-shape snowflakes
//  - Angled rain με splash effects
//  - Twinkling stars με size variation
//  - Realistic lightning με branching

import SwiftUI

// MARK: - Rain Layer

enum RainIntensity {
    case light, medium, heavy

    var dropCount: Int {
        switch self {
        case .light:  return 50
        case .medium: return 100
        case .heavy:  return 180
        }
    }
}

struct RainLayer: View {
    let intensity: RainIntensity
    let speed: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<intensity.dropCount, id: \.self) { i in
                    RainDrop(
                        startX: Double.random(in: -50...geo.size.width),
                        screenHeight: geo.size.height,
                        duration: Double.random(in: 0.5...1.0) / speed,
                        delay: Double.random(in: 0...2),
                        length: Double.random(in: 12...28),
                        opacity: Double.random(in: 0.3...0.75),
                        thickness: Double.random(in: 1.0...2.0)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct RainDrop: View {
    let startX: Double
    let screenHeight: Double
    let duration: Double
    let delay: Double
    let length: Double
    let opacity: Double
    let thickness: Double

    @State private var isFalling = false

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(opacity * 0.3),
                        Color.white.opacity(opacity)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: thickness, height: length)
            .rotationEffect(.degrees(15))
            .offset(
                x: isFalling ? startX + 40 : startX,
                y: isFalling ? screenHeight + 50 : -50
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        isFalling = true
                    }
                }
            }
    }
}

// MARK: - Snow Layer

struct SnowLayer: View {
    let speed: Double
    private let flakeCount = 70

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<flakeCount, id: \.self) { i in
                    Snowflake(
                        startX: Double.random(in: -20...geo.size.width),
                        screenWidth: geo.size.width,
                        screenHeight: geo.size.height,
                        size: Double.random(in: 3...11),
                        duration: Double.random(in: 7...14) / speed,
                        delay: Double.random(in: 0...6),
                        opacity: Double.random(in: 0.55...0.95),
                        swayAmount: Double.random(in: 25...50),
                        flakeStyle: i % 4
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct Snowflake: View {
    let startX: Double
    let screenWidth: Double
    let screenHeight: Double
    let size: Double
    let duration: Double
    let delay: Double
    let opacity: Double
    let swayAmount: Double
    let flakeStyle: Int

    @State private var isFalling = false
    @State private var sway = false

    var body: some View {
        flakeShape
            .foregroundColor(Color.white.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 0.4)
            .shadow(color: .white.opacity(0.4), radius: 1)
            .offset(
                x: isFalling ? startX + (sway ? swayAmount : -swayAmount) : startX,
                y: isFalling ? screenHeight + 50 : -50
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        isFalling = true
                    }
                    withAnimation(.easeInOut(duration: duration / 4).repeatForever(autoreverses: true)) {
                        sway = true
                    }
                }
            }
    }

    @ViewBuilder
    private var flakeShape: some View {
        switch flakeStyle {
        case 0: // Simple dot
            Circle()
        case 1: // 4-point asterisk
            Image(systemName: "snowflake")
                .resizable()
                .scaledToFit()
        case 2: // 6-point star
            Image(systemName: "sparkle")
                .resizable()
                .scaledToFit()
        default: // Soft circle
            Circle()
        }
    }
}

// MARK: - Stars Layer

struct StarsLayer: View {
    let speed: Double
    private let starCount = 120

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<starCount, id: \.self) { i in
                    Star(
                        x: Double.random(in: 0...geo.size.width),
                        y: Double.random(in: 0...(geo.size.height * 0.65)),
                        size: starSize(for: i),
                        twinkleDuration: Double.random(in: 1.5...4.5) / speed,
                        initialDelay: Double.random(in: 0...4),
                        bright: i % 7 == 0
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func starSize(for index: Int) -> Double {
        // Mix sizes — more small, fewer large
        switch index % 10 {
        case 0:    return Double.random(in: 2.5...3.5)  // bright
        case 1, 2: return Double.random(in: 1.8...2.4)  // medium
        default:   return Double.random(in: 0.8...1.6)  // small
        }
    }
}

struct Star: View {
    let x: Double
    let y: Double
    let size: Double
    let twinkleDuration: Double
    let initialDelay: Double
    let bright: Bool

    @State private var twinkling = false

    var body: some View {
        ZStack {
            if bright {
                // Bright star με cross-shaped glow
                Image(systemName: "sparkle")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white)
                    .frame(width: size * 3, height: size * 3)
                    .opacity(twinkling ? 0.4 : 0.95)
                    .blur(radius: 0.3)
            } else {
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .shadow(color: .white.opacity(0.6), radius: twinkling ? 0.5 : 2.5)
                    .opacity(twinkling ? 0.35 : 1.0)
            }
        }
        .position(x: x, y: y)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
                withAnimation(.easeInOut(duration: twinkleDuration).repeatForever(autoreverses: true)) {
                    twinkling = true
                }
            }
        }
    }
}

// MARK: - Realistic Clouds Layer

struct CloudsLayer: View {
    let density: Int
    let speed: Double
    let timeOfDay: TimeOfDay

    private var cloudHighlight: Color {
        switch timeOfDay {
        case .sunrise:
            return Color(red: 0.92, green: 0.80, blue: 0.75)
        case .sunset:
            return Color(red: 0.88, green: 0.70, blue: 0.62)
        case .morning, .midday:
            return Color(red: 0.82, green: 0.85, blue: 0.88)  // γκριζόλευκο αντί pure white
        case .night:
            return Color(red: 0.42, green: 0.46, blue: 0.58)
        }
    }

    private var cloudShadow: Color {
        switch timeOfDay {
        case .sunrise:
            return Color(red: 0.65, green: 0.48, blue: 0.52).opacity(0.90)
        case .sunset:
            return Color(red: 0.48, green: 0.26, blue: 0.40).opacity(0.90)
        case .morning, .midday:
            return Color(red: 0.58, green: 0.64, blue: 0.72).opacity(0.90)  // πιο σκούρο γκρι
        case .night:
            return Color(red: 0.12, green: 0.15, blue: 0.26).opacity(0.95)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<density, id: \.self) { i in
                    RealisticCloud(
                        startX: Double.random(in: -300...geo.size.width),
                        y: Double.random(in: geo.size.height * 0.02...geo.size.height * 0.45),
                        scale: Double.random(in: 0.7...1.5),
                        screenWidth: geo.size.width,
                        duration: Double.random(in: 25...45) / speed,
                        delay: Double(i) * 3,
                        highlight: cloudHighlight,
                        shadow: cloudShadow
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct RealisticCloud: View {
    let startX: Double
    let y: Double
    let scale: Double
    let screenWidth: Double
    let duration: Double
    let delay: Double
    let highlight: Color
    let shadow: Color

    @State private var moving = false

    var body: some View {
        VolumetricCloudShape(highlight: highlight, shadow: shadow)
            .scaleEffect(scale)
            .offset(
                x: moving ? screenWidth + 350 : startX,
                y: y
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        moving = true
                    }
                }
            }
    }
}

/// Volumetric cloud από overlapping blurred circles — iOS Weather style
struct VolumetricCloudShape: View {
    let highlight: Color
    let shadow: Color

    var body: some View {
        ZStack {
            // ── Shadow base — πλατύ, σκούρο, κάτω από το σύννεφο
            Ellipse()
                .fill(shadow.opacity(0.55))
                .frame(width: 260, height: 55)
                .blur(radius: 22)
                .offset(x: 0, y: 52)

            // ── Back layer puffs (πιο σκούρα για βάθος)
            Circle()
                .fill(highlight.opacity(0.65))
                .frame(width: 110, height: 110)
                .blur(radius: 20)
                .offset(x: -70, y: 18)

            Circle()
                .fill(highlight.opacity(0.65))
                .frame(width: 95, height: 95)
                .blur(radius: 18)
                .offset(x: 75, y: 22)

            // ── Mid layer — κύριος όγκος
            Circle()
                .fill(highlight)
                .frame(width: 150, height: 150)
                .blur(radius: 14)
                .offset(x: -18, y: 5)

            Circle()
                .fill(highlight)
                .frame(width: 130, height: 130)
                .blur(radius: 12)
                .offset(x: 55, y: 8)

            Circle()
                .fill(highlight)
                .frame(width: 115, height: 115)
                .blur(radius: 12)
                .offset(x: -90, y: 12)

            // ── Top highlights — ελαφρύτερα puffs για 3D αίσθηση
            Circle()
                .fill(highlight.opacity(0.95))
                .frame(width: 85, height: 85)
                .blur(radius: 9)
                .offset(x: -22, y: -38)

            Circle()
                .fill(highlight.opacity(0.88))
                .frame(width: 68, height: 68)
                .blur(radius: 8)
                .offset(x: 38, y: -32)

            Circle()
                .fill(highlight.opacity(0.75))
                .frame(width: 52, height: 52)
                .blur(radius: 7)
                .offset(x: -68, y: -20)
        }
        .frame(width: 320, height: 180)
    }
}

// MARK: - Wind Layer

struct WindLayer: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<35, id: \.self) { i in
                    WindStreak(
                        y: Double.random(in: 0...geo.size.height * 0.75),
                        screenWidth: geo.size.width,
                        length: Double.random(in: 50...160),
                        thickness: Double.random(in: 1.0...2.5),
                        opacity: Double.random(in: 0.12...0.40),
                        duration: Double.random(in: 0.3...0.7),
                        delay: Double.random(in: 0...1.5)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct WindStreak: View {
    let y: Double
    let screenWidth: Double
    let length: Double
    let thickness: Double
    let opacity: Double
    let duration: Double
    let delay: Double

    @State private var moving = false

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(opacity),
                        Color.white.opacity(opacity * 0.6),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: length, height: thickness)
            .offset(
                x: moving ? screenWidth + length : -length,
                y: y
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        moving = true
                    }
                }
            }
    }
}

// MARK: - Lightning Layer με branching

struct LightningLayer: View {
    @State private var flashOpacity: Double = 0
    @State private var boltOpacity: Double = 0
    @State private var boltSeed: Int = 0

    var body: some View {
        ZStack {
            // Sky flash
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Lightning bolt
            GeometryReader { geo in
                LightningBolt(seed: boltSeed)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white, Color(red: 0.85, green: 0.90, blue: 1.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: .white, radius: 8)
                    .shadow(color: Color(red: 0.7, green: 0.85, blue: 1.0), radius: 15)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(boltOpacity)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onAppear {
            scheduleNextStrike()
        }
    }

    private func scheduleNextStrike() {
        let nextDelay = Double.random(in: 7...18)
        DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
            performStrike()
        }
    }

    private func performStrike() {
        boltSeed = Int.random(in: 0...1000)

        // Quick bolt visible
        withAnimation(.easeOut(duration: 0.06)) {
            boltOpacity = 1.0
            flashOpacity = 0.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeIn(duration: 0.25)) {
                boltOpacity = 0
                flashOpacity = 0
            }
        }
        // Aftershock flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.05)) {
                flashOpacity = 0.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeIn(duration: 0.35)) {
                    flashOpacity = 0
                }
            }
        }

        scheduleNextStrike()
    }
}

struct LightningBolt: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var generator = SeededRandomGenerator(seed: UInt64(seed))

        let startX = rect.width * (0.3 + Double.random(in: 0...0.4, using: &generator))
        var currentX = startX
        var currentY: CGFloat = 0
        let endY = rect.height * 0.55

        path.move(to: CGPoint(x: currentX, y: currentY))

        // Main bolt — zigzag down
        let segments = 8
        for i in 1...segments {
            let progress = CGFloat(i) / CGFloat(segments)
            let nextY = endY * progress
            let zigzag = CGFloat(Double.random(in: -25...25, using: &generator))
            currentX += zigzag
            currentY = nextY
            path.addLine(to: CGPoint(x: currentX, y: currentY))

            // Add branching at certain segments
            if i == 3 || i == 5 {
                let branchX = currentX + CGFloat(Double.random(in: -50...50, using: &generator))
                let branchY = currentY + CGFloat(Double.random(in: 25...60, using: &generator))
                path.move(to: CGPoint(x: currentX, y: currentY))
                path.addLine(to: CGPoint(x: branchX, y: branchY))
                path.move(to: CGPoint(x: currentX, y: currentY))
            }
        }

        return path
    }
}

// Simple seeded random generator για consistent bolts
struct SeededRandomGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

