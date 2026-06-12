//
//  WeatherBackground.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.04.2026
//
//  Level 3 animated background — realistic visuals με:
//  - Bezier curves για organic mountain shapes
//  - Multi-layer parallax depth (4 layers)
//  - Lottie animations για sun, moon, rain, snow, thunderstorm, fog, clouds
//  - Aurora borealis για clear cold nights
//  - Smooth atmospheric gradients

import SwiftUI
#if canImport(Lottie)
import Lottie
#endif

// MARK: - Time Slot

enum TimeOfDay {
    case sunrise
    case morning
    case midday
    case sunset
    case night

    /// Υπολογίζει το TimeOfDay χρησιμοποιώντας πραγματικά δεδομένα ηλιανατολής/δύσης.
    /// Αν δεν υπάρχουν (nil), χρησιμοποιεί fallback με ώρα ρολογιού.
    static func from(date: Date = Date(), sunrise: Date? = nil, sunset: Date? = nil) -> TimeOfDay {

        // Solar path — χρησιμοποιεί πραγματικές ώρες ηλιανατολής/δύσης.
        // Guard: sunrise must be from the same calendar day as `date` — stale weather data
        // from a previous day would have yesterday's sunset already passed, causing false .night.
        let cal = Calendar.current
        if let sr = sunrise, let ss = sunset, sr < ss,
           cal.isDate(sr, inSameDayAs: date) || cal.isDate(ss, inSameDayAs: date) {
            let now = date.timeIntervalSinceReferenceDate
            let srT  = sr.timeIntervalSinceReferenceDate
            let ssT  = ss.timeIntervalSinceReferenceDate
            let dayLength = ssT - srT

            // Νύχτα: πριν 30λ πριν ανατολή ή μετά 30λ μετά δύση
            if now < srT - 1800 || now > ssT + 1800 { return .night }

            // Sunrise: από 30λ πριν ανατολή έως 45λ μετά
            if now < srT + 2700 { return .sunrise }

            // Sunset: από 90λ πριν δύση έως 30λ μετά
            if now >= ssT - 5400 { return .sunset }

            // Morning → Midday στο 45% της ημέρας (solar noon ≈ 50%)
            if now < srT + dayLength * 0.45 { return .morning }

            return .midday
        }

        // Fallback: ώρα ρολογιού (χρησιμοποιείται πριν έρθουν τα weather data)
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<8:   return .sunrise
        case 8..<12:  return .morning
        case 12..<17: return .midday
        case 17..<21: return .sunset
        default:      return .night
        }
    }

    /// Atmospheric gradient — πιο φυσικά χρώματα με sky tones
    var gradientColors: [Color] {
        switch self {
        case .sunrise:
            return [
                Color(red: 0.98, green: 0.55, blue: 0.35),  // deep coral horizon
                Color(red: 1.00, green: 0.72, blue: 0.55),  // peach
                Color(red: 0.95, green: 0.78, blue: 0.85),  // soft pink
                Color(red: 0.65, green: 0.78, blue: 0.92),  // hazy blue
                Color(red: 0.50, green: 0.70, blue: 0.90)   // upper sky
            ]
        case .morning:
            return [
                Color(red: 0.95, green: 0.97, blue: 1.0),   // soft white horizon
                Color(red: 0.75, green: 0.88, blue: 1.0),
                Color(red: 0.55, green: 0.78, blue: 0.98),
                Color(red: 0.40, green: 0.70, blue: 0.95)   // deeper blue top
            ]
        case .midday:
            return [
                Color(red: 0.65, green: 0.85, blue: 0.98),
                Color(red: 0.40, green: 0.70, blue: 0.95),
                Color(red: 0.25, green: 0.55, blue: 0.90),
                Color(red: 0.15, green: 0.42, blue: 0.82)   // deep sky blue top
            ]
        case .sunset:
            return [
                Color(red: 0.98, green: 0.50, blue: 0.30),  // fiery orange
                Color(red: 0.95, green: 0.40, blue: 0.45),  // pinkish red
                Color(red: 0.65, green: 0.30, blue: 0.55),  // magenta
                Color(red: 0.30, green: 0.20, blue: 0.50),  // deep purple
                Color(red: 0.10, green: 0.10, blue: 0.30)   // night creeping in
            ]
        case .night:
            return [
                Color(red: 0.05, green: 0.08, blue: 0.18),  // horizon glow
                Color(red: 0.03, green: 0.05, blue: 0.15),
                Color(red: 0.01, green: 0.02, blue: 0.08),  // deep space
                Color.black
            ]
        }
    }

    /// Far mountains (ομιχλώδη βουνά πίσω)
    var farMountainColor: Color {
        switch self {
        case .sunrise: return Color(red: 0.55, green: 0.45, blue: 0.55).opacity(0.55)
        case .morning: return Color(red: 0.55, green: 0.65, blue: 0.78).opacity(0.45)
        case .midday:  return Color(red: 0.50, green: 0.65, blue: 0.80).opacity(0.40)
        case .sunset:  return Color(red: 0.40, green: 0.30, blue: 0.45).opacity(0.65)
        case .night:   return Color(red: 0.08, green: 0.10, blue: 0.18).opacity(0.85)
        }
    }

    /// Mid mountains
    var midMountainColor: Color {
        switch self {
        case .sunrise: return Color(red: 0.30, green: 0.22, blue: 0.35).opacity(0.80)
        case .morning: return Color(red: 0.40, green: 0.50, blue: 0.62).opacity(0.65)
        case .midday:  return Color(red: 0.38, green: 0.52, blue: 0.65).opacity(0.60)
        case .sunset:  return Color(red: 0.20, green: 0.13, blue: 0.28).opacity(0.85)
        case .night:   return Color(red: 0.04, green: 0.06, blue: 0.12).opacity(0.92)
        }
    }

    /// Near hills με δέντρα
    var nearHillColor: Color {
        switch self {
        case .sunrise: return Color(red: 0.12, green: 0.10, blue: 0.18).opacity(0.92)
        case .morning: return Color(red: 0.18, green: 0.30, blue: 0.22).opacity(0.85)
        case .midday:  return Color(red: 0.22, green: 0.38, blue: 0.28).opacity(0.80)
        case .sunset:  return Color(red: 0.08, green: 0.06, blue: 0.18).opacity(0.95)
        case .night:   return Color(red: 0.01, green: 0.02, blue: 0.05).opacity(0.98)
        }
    }

    /// Foreground τα πιο σκούρα
    var foregroundColor: Color {
        switch self {
        case .sunrise: return Color.black.opacity(0.85)
        case .morning: return Color(red: 0.10, green: 0.18, blue: 0.12).opacity(0.85)
        case .midday:  return Color(red: 0.12, green: 0.22, blue: 0.15).opacity(0.85)
        case .sunset:  return Color.black.opacity(0.95)
        case .night:   return Color.black
        }
    }

    var showSun: Bool {
        switch self {
        case .sunrise, .morning, .midday, .sunset: return true
        case .night: return false
        }
    }

    var showMoon: Bool {
        return self == .night
    }

    var showStars: Bool {
        return self == .night
    }

    /// Aurora εμφανίζεται μόνο τη νύχτα όταν είναι clear
    var showAurora: Bool {
        return self == .night
    }

    /// Horizontal position ήλιου — κινείται κατά τη διάρκεια της μέρας
    var celestialX: Double {
        switch self {
        case .sunrise: return 0.20
        case .morning: return 0.50
        case .midday:  return 0.75
        case .sunset:  return 0.85
        case .night:   return TimeOfDay.moonCelestialPosition().x
        }
    }

    /// Vertical position ήλιου — πάνω στον ουρανό
    var celestialY: Double {
        switch self {
        case .sunrise: return 0.45
        case .morning: return 0.25
        case .midday:  return 0.20
        case .sunset:  return 0.45
        case .night:   return TimeOfDay.moonCelestialPosition().y
        }
    }

    /// Θέση φεγγαριού βάσει ώρας — τόξο από δεξιά (21:00) προς αριστερά (06:00)
    static func moonCelestialPosition(for date: Date = Date()) -> (x: Double, y: Double) {
        let cal = Calendar.current
        let hour   = Double(cal.component(.hour,   from: date))
        let minute = Double(cal.component(.minute, from: date))
        let totalMinutes = hour * 60 + minute

        // Νύχτα: 21:00 → 06:00 (9 ώρες = 540 λεπτά)
        let nightStart = 21.0 * 60   // 1260
        let nightDuration = 9.0 * 60 // 540

        let progress: Double
        if totalMinutes >= nightStart {
            progress = (totalMinutes - nightStart) / nightDuration
        } else {
            progress = (totalMinutes + (24 * 60 - nightStart)) / nightDuration
        }
        let p = max(0, min(1, progress))

        // x: ανατέλλει δεξιά (0.82) → δύει αριστερά (0.12)
        let x = 0.82 - p * 0.70
        // y: τόξο — χαμηλά στις άκρες, ψηλά στα μεσάνυχτα
        let y = 0.42 - sin(p * .pi) * 0.28

        return (x: x, y: y)
    }
}

// MARK: - Main Weather Background

struct WeatherBackground: View {
    let timeOfDay: TimeOfDay
    let condition: WeatherCondition
    let isDimmed: Bool

    private var lowPowerMode: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var animationSpeed: Double {
        if condition == .windy { return isDimmed ? 1.5 : 3.0 }
        return isDimmed ? 0.5 : 1.0
    }

    /// Aurora εμφανίζεται όταν είναι νύχτα και όχι rainy/cloudy/snow
    private var shouldShowAurora: Bool {
        timeOfDay.showAurora &&
        (condition == .sunny || condition == .partlyCloudy ||
         condition == .cold || condition == .unknown) &&
        !lowPowerMode
    }

    /// Weather conditions όπου ο ήλιος κρύβεται
    private var heavyWeather: Bool {
        condition == .rainy || condition == .thunderstorm ||
        condition == .snow  || condition == .cloudy       ||
        condition == .foggy
    }

    var body: some View {
        ZStack {
            // Layer 1: Atmospheric sky — animated MeshGradient that slowly
            // "breathes" (control points drift), giving the sky a living,
            // organic feel. Falls back to a static mesh in Low Power Mode.
            AnimatedSkyMesh(timeOfDay: timeOfDay, lowPower: lowPowerMode)
                .ignoresSafeArea()

            // Layer 2: Aurora (νύχτα με καλό καιρό)
            if shouldShowAurora {
                AuroraView()
                    .opacity(isDimmed ? 0.4 : 0.7)
                    .blendMode(.screen)
            }

            // Layer 3: Stars
            if timeOfDay.showStars && !lowPowerMode {
                StarsLayer(speed: animationSpeed)
                    .opacity(isDimmed ? 0.5 : 1.0)
            }

            // Layer 4: Sun ή Moon
            GeometryReader { geo in
                ZStack {
                    // Ήλιος — κρύβεται όταν βρέχει/χιονίζει/κεραυνοί
                    if timeOfDay.showSun && !heavyWeather {
                        #if canImport(Lottie)
                        LottieView {
                            try await DotLottieFile.named("sunny")
                        }
                        .playing(loopMode: .loop)
                        .frame(width: 220, height: 220)
                        .position(
                            x: geo.size.width * timeOfDay.celestialX,
                            y: geo.size.height * timeOfDay.celestialY
                        )
                        #else
                        RealisticSun(timeOfDay: timeOfDay)
                            .frame(width: 180, height: 180)
                            .position(
                                x: geo.size.width * timeOfDay.celestialX,
                                y: geo.size.height * timeOfDay.celestialY
                            )
                        #endif
                    }

                    // Φεγγάρι — παραμένει ορατό ακόμα και με βροχή
                    if timeOfDay.showMoon {
                        #if canImport(Lottie)
                        LottieView {
                            try await DotLottieFile.named("Moon_and_stars")
                        }
                        .playing(loopMode: .loop)
                        .frame(width: 220, height: 220)
                        .position(
                            x: geo.size.width * timeOfDay.celestialX,
                            y: geo.size.height * timeOfDay.celestialY
                        )
                        #else
                        RealisticMoon()
                            .frame(width: 90, height: 90)
                            .position(
                                x: geo.size.width * timeOfDay.celestialX,
                                y: geo.size.height * timeOfDay.celestialY
                            )
                        #endif
                    }
                }
            }
            .ignoresSafeArea()

            // Layer 4.5: Ambient sky life — birds gliding across by day,
            // shooting stars streaking by night (clear weather only).
            // Drawn BEHIND the mountains so they vanish behind peaks.
            if !lowPowerMode {
                AmbientLifeLayer(mode: .sky, timeOfDay: timeOfDay, condition: condition)
                    .opacity(isDimmed ? 0.6 : 1.0)
            }

            // Layer 5: Atmospheric haze για depth
            atmosphericHaze

            // Layer 6: Clouds
            if shouldShowClouds && !lowPowerMode {
                CloudsLayer(density: cloudDensity, speed: animationSpeed, timeOfDay: timeOfDay)
                    .opacity(isDimmed ? 0.6 : 1.0)
            }

            // Layer 7: Far mountains (πιο μακριά, ομιχλώδη)
            FarMountainsShape()
                .fill(timeOfDay.farMountainColor)
                .ignoresSafeArea()

            // Layer 8: Mid mountains
            MidMountainsShape()
                .fill(timeOfDay.midMountainColor)
                .ignoresSafeArea()

            // Layer 9: Near hills με δέντρα
            NearHillsShape()
                .fill(timeOfDay.nearHillColor)
                .ignoresSafeArea()

            // Layer 10: Foreground με detailed trees
            ForegroundLayer(color: timeOfDay.foregroundColor)

            // Layer 10.5: Fireflies drifting over the dark hills on clear
            // nights — drawn IN FRONT of the foreground for a magical depth cue.
            if !lowPowerMode {
                AmbientLifeLayer(mode: .ground, timeOfDay: timeOfDay, condition: condition)
                    .opacity(isDimmed ? 0.6 : 1.0)
            }

            // Layer 11: Weather particles
            if !lowPowerMode {
                weatherParticles
            }

            // Layer 12: Fog overlay (πάνω μέρος της οθόνης)
            if condition == .foggy {
                #if canImport(Lottie)
                GeometryReader { geo in
                    LottieView {
                        try await DotLottieFile.named("Fog_Smoke")
                    }
                    .playing(loopMode: .loop)
                    .frame(width: geo.size.width, height: 250)
                    .position(
                        x: geo.size.width * 0.5,
                        y: geo.size.height * 0.20
                    )
                }
                .opacity(isDimmed ? 0.7 : 1.0)
                .ignoresSafeArea()
                #else
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.white.opacity(0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                #endif
            }

            // Layer 13: Dim overlay για το nudge screen
            if isDimmed {
                Color.black.opacity(0.25).ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 1.5), value: timeOfDay)
        .animation(.easeInOut(duration: 1.0), value: condition)
    }

    // MARK: - Helpers

    private var atmosphericHaze: some View {
        LinearGradient(
            colors: [
                Color.clear,
                timeOfDay.gradientColors.last?.opacity(0.3) ?? .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var shouldShowClouds: Bool {
        switch condition {
        case .partlyCloudy, .cloudy, .rainy, .snow, .windy: return true
        default: return false
        }
    }

    private var cloudDensity: Int {
        switch condition {
        case .partlyCloudy: return 3
        case .cloudy:       return 6
        case .rainy:        return 7
        case .snow:         return 5
        case .windy:        return 4
        default:            return 0
        }
    }

    @ViewBuilder
    private var weatherParticles: some View {
        switch condition {
        case .rainy:
            #if canImport(Lottie)
            LottieView {
                try await DotLottieFile.named("Rain")
            }
            .playing(loopMode: .loop)
            .opacity(isDimmed ? 0.7 : 1.0)
            .ignoresSafeArea()
            #else
            RainLayer(intensity: .medium, speed: animationSpeed)
                .opacity(isDimmed ? 0.7 : 1.0)
            #endif
        case .thunderstorm:
            #if canImport(Lottie)
            GeometryReader { geo in
                LottieView {
                    try await DotLottieFile.named("Thunderstorm")
                }
                .playing(loopMode: .loop)
                .frame(width: 280, height: 280)
                .position(
                    x: geo.size.width * timeOfDay.celestialX,
                    y: geo.size.height * timeOfDay.celestialY
                )
            }
            .opacity(isDimmed ? 0.7 : 1.0)
            .ignoresSafeArea()
            #else
            ZStack {
                RainLayer(intensity: .heavy, speed: animationSpeed)
                LightningLayer()
            }
            .opacity(isDimmed ? 0.7 : 1.0)
            #endif
        case .snow:
            #if canImport(Lottie)
            LottieView {
                try await DotLottieFile.named("Snow_Off_white")
            }
            .playing(loopMode: .loop)
            .opacity(isDimmed ? 0.7 : 1.0)
            .ignoresSafeArea()
            #else
            SnowLayer(speed: animationSpeed)
                .opacity(isDimmed ? 0.7 : 1.0)
            #endif
        case .windy:
            WindLayer()
                .opacity(isDimmed ? 0.6 : 1.0)
        default:
            EmptyView()
        }
    }
}

// MARK: - Realistic Sun με light rays (fallback)

struct RealisticSun: View {
    let timeOfDay: TimeOfDay

    @State private var rayRotation: Double = 0
    @State private var pulse: Bool = false

    private var sunCoreColors: [Color] {
        switch timeOfDay {
        case .sunrise, .sunset:
            return [
                Color(red: 1.0, green: 0.92, blue: 0.65),
                Color(red: 1.0, green: 0.65, blue: 0.30),
                Color(red: 0.95, green: 0.40, blue: 0.20).opacity(0.0)
            ]
        case .morning, .midday:
            return [
                Color(red: 1.0, green: 1.0, blue: 0.92),
                Color(red: 1.0, green: 0.95, blue: 0.65),
                Color(red: 1.0, green: 0.85, blue: 0.40).opacity(0.0)
            ]
        default:
            return [.yellow, .orange.opacity(0.0)]
        }
    }

    private var rayColor: Color {
        switch timeOfDay {
        case .sunrise, .sunset: return Color(red: 1.0, green: 0.75, blue: 0.45)
        default: return Color(red: 1.0, green: 0.95, blue: 0.65)
        }
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    sunCoreColors.first?.opacity(0.4) ?? .yellow,
                    Color.clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 110
            )
            .scaleEffect(pulse ? 1.08 : 1.0)
            .blendMode(.screen)

            ZStack {
                ForEach(0..<8) { i in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    rayColor.opacity(0.0),
                                    rayColor.opacity(0.35),
                                    rayColor.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 8, height: 160)
                        .rotationEffect(.degrees(Double(i) * 45))
                        .blur(radius: 2)
                }
            }
            .rotationEffect(.degrees(rayRotation))
            .blendMode(.screen)
            .opacity(0.7)

            RadialGradient(
                colors: sunCoreColors,
                center: .center,
                startRadius: 8,
                endRadius: 70
            )
            .frame(width: 130, height: 130)
            .blendMode(.screen)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, sunCoreColors.first ?? .yellow],
                        center: .center,
                        startRadius: 2,
                        endRadius: 30
                    )
                )
                .frame(width: 55, height: 55)
                .shadow(color: sunCoreColors.first ?? .yellow, radius: 25)
        }
        .onAppear {
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                rayRotation = 360
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Realistic Moon (fallback)

struct RealisticMoon: View {
    @State private var glow: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.85, green: 0.88, blue: 0.95).opacity(0.35),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .scaleEffect(glow ? 1.1 : 1.0)
                .blendMode(.screen)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.98, green: 0.97, blue: 0.93),
                            Color(red: 0.92, green: 0.91, blue: 0.86),
                            Color(red: 0.78, green: 0.78, blue: 0.78)
                        ],
                        center: .topLeading,
                        startRadius: 5,
                        endRadius: 70
                    )
                )
                .frame(width: 70, height: 70)
                .shadow(color: Color(red: 0.85, green: 0.88, blue: 0.95).opacity(0.4), radius: 12)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)

            craterGroup
                .frame(width: 70, height: 70)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private var craterGroup: some View {
        ZStack {
            crater(size: 11, x: -10, y: -7, depth: 0.35)
            crater(size: 8, x: 12, y: 9, depth: 0.40)
            crater(size: 6, x: 5, y: -13, depth: 0.30)
            crater(size: 5, x: -16, y: 8, depth: 0.32)
            crater(size: 4, x: 18, y: -3, depth: 0.28)
            crater(size: 3, x: 0, y: 14, depth: 0.25)
            crater(size: 3, x: -8, y: 18, depth: 0.22)
        }
    }

    private func crater(size: CGFloat, x: CGFloat, y: CGFloat, depth: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.55, green: 0.55, blue: 0.58).opacity(depth),
                        Color(red: 0.78, green: 0.78, blue: 0.80).opacity(depth * 0.4)
                    ],
                    center: .topLeading,
                    startRadius: 1,
                    endRadius: size
                )
            )
            .frame(width: size, height: size)
            .offset(x: x, y: y)
    }
}

// MARK: - Aurora View

struct AuroraView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AuroraRibbon(
                    color1: Color(red: 0.20, green: 0.95, blue: 0.65),
                    color2: Color(red: 0.10, green: 0.70, blue: 0.50),
                    yOffset: geo.size.height * 0.25,
                    phase: phase,
                    amplitude: 35
                )
                .frame(height: 200)

                AuroraRibbon(
                    color1: Color(red: 0.65, green: 0.35, blue: 0.95),
                    color2: Color(red: 0.40, green: 0.20, blue: 0.75),
                    yOffset: geo.size.height * 0.32,
                    phase: phase + 1.5,
                    amplitude: 30
                )
                .frame(height: 180)
                .opacity(0.7)

                AuroraRibbon(
                    color1: Color(red: 0.25, green: 0.85, blue: 0.95),
                    color2: Color(red: 0.15, green: 0.55, blue: 0.85),
                    yOffset: geo.size.height * 0.18,
                    phase: phase + 3.0,
                    amplitude: 25
                )
                .frame(height: 160)
                .opacity(0.6)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

struct AuroraRibbon: View {
    let color1: Color
    let color2: Color
    let yOffset: CGFloat
    let phase: CGFloat
    let amplitude: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                let steps = 60

                path.move(to: CGPoint(x: 0, y: h * 0.5))
                for i in 0...steps {
                    let x = w * CGFloat(i) / CGFloat(steps)
                    let y = h * 0.5 + sin(CGFloat(i) / 8.0 + phase) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        color1.opacity(0.6),
                        color2.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blur(radius: 20)
        }
        .position(x: UIScreen.main.bounds.width / 2, y: yOffset)
    }
}

// MARK: - Mountain Shapes (Bezier curves)

struct FarMountainsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let baseY = h * 0.62

        path.move(to: CGPoint(x: 0, y: baseY))

        path.addCurve(
            to: CGPoint(x: w * 0.25, y: baseY - h * 0.10),
            control1: CGPoint(x: w * 0.08, y: baseY - h * 0.04),
            control2: CGPoint(x: w * 0.15, y: baseY - h * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: baseY - h * 0.05),
            control1: CGPoint(x: w * 0.32, y: baseY - h * 0.08),
            control2: CGPoint(x: w * 0.40, y: baseY - h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.78, y: baseY - h * 0.12),
            control1: CGPoint(x: w * 0.60, y: baseY - h * 0.08),
            control2: CGPoint(x: w * 0.68, y: baseY - h * 0.14)
        )
        path.addCurve(
            to: CGPoint(x: w, y: baseY - h * 0.08),
            control1: CGPoint(x: w * 0.85, y: baseY - h * 0.10),
            control2: CGPoint(x: w * 0.92, y: baseY - h * 0.06)
        )

        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        return path
    }
}

struct MidMountainsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let baseY = h * 0.72

        path.move(to: CGPoint(x: 0, y: baseY))

        path.addCurve(
            to: CGPoint(x: w * 0.18, y: baseY - h * 0.12),
            control1: CGPoint(x: w * 0.05, y: baseY - h * 0.04),
            control2: CGPoint(x: w * 0.10, y: baseY - h * 0.14)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.38, y: baseY - h * 0.08),
            control1: CGPoint(x: w * 0.25, y: baseY - h * 0.10),
            control2: CGPoint(x: w * 0.32, y: baseY - h * 0.04)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: baseY - h * 0.18),
            control1: CGPoint(x: w * 0.43, y: baseY - h * 0.12),
            control2: CGPoint(x: w * 0.48, y: baseY - h * 0.20)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.78, y: baseY - h * 0.10),
            control1: CGPoint(x: w * 0.62, y: baseY - h * 0.16),
            control2: CGPoint(x: w * 0.70, y: baseY - h * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: w, y: baseY - h * 0.14),
            control1: CGPoint(x: w * 0.86, y: baseY - h * 0.14),
            control2: CGPoint(x: w * 0.94, y: baseY - h * 0.18)
        )

        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        return path
    }
}

struct NearHillsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let baseY = h * 0.85

        path.move(to: CGPoint(x: 0, y: baseY))

        path.addCurve(
            to: CGPoint(x: w * 0.30, y: baseY - h * 0.05),
            control1: CGPoint(x: w * 0.10, y: baseY - h * 0.02),
            control2: CGPoint(x: w * 0.20, y: baseY - h * 0.07)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: baseY - h * 0.02),
            control1: CGPoint(x: w * 0.40, y: baseY - h * 0.03),
            control2: CGPoint(x: w * 0.48, y: baseY)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.82, y: baseY - h * 0.06),
            control1: CGPoint(x: w * 0.65, y: baseY - h * 0.04),
            control2: CGPoint(x: w * 0.74, y: baseY - h * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: w, y: baseY - h * 0.04),
            control1: CGPoint(x: w * 0.90, y: baseY - h * 0.04),
            control2: CGPoint(x: w * 0.96, y: baseY - h * 0.02)
        )

        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        return path
    }
}

// MARK: - Foreground Layer με detailed trees

struct ForegroundLayer: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.92))
                    path.addCurve(
                        to: CGPoint(x: w * 0.5, y: h * 0.88),
                        control1: CGPoint(x: w * 0.25, y: h * 0.85),
                        control2: CGPoint(x: w * 0.35, y: h * 0.86)
                    )
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.93),
                        control1: CGPoint(x: w * 0.65, y: h * 0.90),
                        control2: CGPoint(x: w * 0.85, y: h * 0.88)
                    )
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(color)

                ForEach(0..<10) { i in
                    let xPos = w * (Double(i) / 10.0 + 0.04)
                    let scale = i % 2 == 0 ? 1.0 : 0.85
                    let yOffset = i % 3 == 0 ? -3.0 : 0.0

                    DetailedPineTree()
                        .fill(color)
                        .frame(width: 32 * scale, height: 60 * scale)
                        .position(x: xPos, y: h * 0.88 + yOffset)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Animated Sky Mesh

/// The sky as a 3×3 MeshGradient whose interior control points drift slowly
/// (lissajous-style), so the colour bands morph organically — the sky feels
/// alive instead of a frozen gradient. Colours come straight from the existing
/// `TimeOfDay.gradientColors` palette, so the overall look (and the smooth
/// cross-fade on time/weather change) is preserved.
///
/// Battery: 12 fps is plenty for motion this slow; in Low Power Mode the mesh
/// renders once, statically (still prettier than a flat LinearGradient).
struct AnimatedSkyMesh: View {
    let timeOfDay: TimeOfDay
    let lowPower: Bool

    var body: some View {
        if lowPower {
            mesh(at: 0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                mesh(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func mesh(at t: TimeInterval) -> some View {
        // Sample the palette into 4 anchor tones (works for 4- and 5-colour
        // palettes alike): a = top, b/m = middle bands, d = bottom.
        let c = timeOfDay.gradientColors
        let a = c[0]
        let b = c[min(1, c.count - 1)]
        let m = c[c.count / 2]
        let d = c[c.count - 1]

        // Interior points drift on slow, incommensurate frequencies so the
        // motion never visibly repeats. Edge points stay ON their edge
        // (MeshGradient requirement); corners stay pinned.
        let cx  = Float(0.5 + 0.07 * sin(t * 0.050))
        let cy  = Float(0.5 + 0.06 * sin(t * 0.083 + 0.7))
        let top = Float(0.5 + 0.06 * sin(t * 0.070 + 2.1))
        let bot = Float(0.5 + 0.05 * sin(t * 0.061 + 4.0))
        let lft = Float(0.5 + 0.04 * sin(t * 0.110 + 1.0))
        let rgt = Float(0.5 + 0.04 * cos(t * 0.090))

        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0],   [top, 0], [1, 0],
                [0, lft], [cx, cy], [1, rgt],
                [0, 1],   [bot, 1], [1, 1]
            ],
            colors: [
                a, b, a,
                b, m, b,
                d, d, d
            ]
        )
    }
}

// MARK: - Ambient Life Layer (birds / shooting stars / fireflies)

/// Pure-Canvas ambient creatures, all deterministic functions of time — no
/// state, no timers to leak, ~20 fps. Two placements:
///   • `.sky`    — birds gliding across by day, shooting stars by night
///                 (hosted behind the mountain layers)
///   • `.ground` — fireflies blinking and drifting over the dark hills at
///                 night (hosted in front of the foreground)
/// Only renders in clear-ish weather; heavy weather hides it entirely.
struct AmbientLifeLayer: View {
    enum Mode { case sky, ground }

    let mode: Mode
    let timeOfDay: TimeOfDay
    let condition: WeatherCondition

    private var isNight: Bool { timeOfDay == .night }

    private var clearish: Bool {
        condition == .sunny || condition == .partlyCloudy ||
        condition == .cold  || condition == .unknown
    }

    private var active: Bool {
        guard clearish else { return false }
        switch mode {
        case .sky:    return true          // birds by day, meteors by night
        case .ground: return isNight       // fireflies only at night
        }
    }

    var body: some View {
        if active {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    switch mode {
                    case .sky:
                        if isNight { drawShootingStar(ctx, size, t) }
                        else       { drawBirds(ctx, size, t) }
                    case .ground:
                        drawFireflies(ctx, size, t)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // Classic deterministic hash → [0, 1) — stable "randomness" per cycle.
    private func hash(_ n: Double) -> Double {
        let x = sin(n * 12.9898) * 43758.5453
        return x - x.rounded(.down)
    }

    // ── Fireflies ─────────────────────────────────────────────────────────
    // 9 warm dots over the hills (lower third), each on its own lissajous
    // drift + slow blink. Drawn as 3 concentric fills (cheap fake glow).
    private func drawFireflies(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let color = Color(red: 0.85, green: 1.0, blue: 0.55)
        for i in 0..<9 {
            let fi = Double(i)
            let x0 = (fi * 0.618 + 0.07).truncatingRemainder(dividingBy: 1.0)
            let y0 = 0.66 + 0.26 * hash(fi + 31)
            let x = (x0 + 0.028 * sin(t * 0.31 + fi * 2.1)) * size.width
            let y = (y0 + 0.020 * sin(t * 0.23 + fi * 1.3)) * size.height
            // Blink: squared half-sine → mostly dim, periodic soft flashes
            let blink = max(0, sin(t * 0.9 + fi * 2.7))
            let glow = blink * blink
            guard glow > 0.02 else { continue }

            for (radius, alpha) in [(6.0, 0.10), (3.0, 0.28), (1.3, 0.95)] {
                let rect = CGRect(x: x - radius, y: y - radius,
                                  width: radius * 2, height: radius * 2)
                ctx.fill(Path(ellipseIn: rect),
                         with: .color(color.opacity(alpha * glow)))
            }
        }
    }

    // ── Shooting star ─────────────────────────────────────────────────────
    // One meteor every ~17 s: bright head + gradient tail streaking down-right
    // for ~0.8 s, start point hashed from the cycle index.
    private func drawShootingStar(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let period = 17.0
        let cycle = (t / period).rounded(.down)
        let phase = t - cycle * period
        let life = 0.8
        guard phase < life else { return }

        let p = phase / life                          // 0 → 1 over the streak
        let startX = (0.10 + 0.55 * hash(cycle)) * size.width
        let startY = (0.06 + 0.18 * hash(cycle + 7)) * size.height
        let dir = CGVector(dx: 0.912, dy: 0.410)      // ~24° downwards
        let travel = 260.0

        let head = CGPoint(x: startX + dir.dx * travel * p,
                           y: startY + dir.dy * travel * p)
        let tailLen = 78.0 * (1.0 - 0.35 * p)
        let tail = CGPoint(x: head.x - dir.dx * tailLen,
                           y: head.y - dir.dy * tailLen)
        let fade = sin(p * .pi)                       // ease in & out

        var path = Path()
        path.move(to: tail)
        path.addLine(to: head)
        ctx.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [.clear, .white.opacity(0.85 * fade)]),
                startPoint: tail, endPoint: head
            ),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
        )
        let r = 2.2
        ctx.fill(Path(ellipseIn: CGRect(x: head.x - r, y: head.y - r,
                                        width: r * 2, height: r * 2)),
                 with: .color(.white.opacity(fade)))
    }

    // ── Birds ─────────────────────────────────────────────────────────────
    // 3 distant silhouettes crossing left→right on staggered ~26 s loops,
    // wings flapping via a quad-curve "∿" that bends with sin(t).
    private func drawBirds(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let silhouette = timeOfDay == .sunset
            ? Color.black.opacity(0.55)
            : Color(red: 0.12, green: 0.18, blue: 0.26).opacity(0.50)

        for i in 0..<3 {
            let fi = Double(i)
            let period = 26.0
            let p = ((t + fi * 9.3) / period).truncatingRemainder(dividingBy: 1.0)
            let x = (-0.10 + 1.20 * p) * size.width
            let y = (0.14 + 0.07 * fi + 0.018 * sin(t * 0.7 + fi * 2)) * size.height
            let s = 7.0 - fi * 1.2                    // farther birds smaller
            let flap = sin(t * 9 + fi * 2.4)          // wing beat
            let wingTipY = y + flap * s * 0.45
            let wingPeak = y - s * 0.85 * max(0.25, flap)

            var path = Path()
            path.move(to: CGPoint(x: x - s, y: wingTipY))
            path.addQuadCurve(to: CGPoint(x: x, y: y),
                              control: CGPoint(x: x - s * 0.5, y: wingPeak))
            path.addQuadCurve(to: CGPoint(x: x + s, y: wingTipY),
                              control: CGPoint(x: x + s * 0.5, y: wingPeak))
            ctx.stroke(path, with: .color(silhouette),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }
}

// MARK: - Detailed Pine Tree

struct DetailedPineTree: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.addRect(CGRect(x: w * 0.45, y: h * 0.85, width: w * 0.10, height: h * 0.15))

        let topY = h * 0.0
        let level1Y = h * 0.32
        let level2Y = h * 0.55
        let level3Y = h * 0.78

        path.move(to: CGPoint(x: w * 0.5, y: topY))
        path.addCurve(
            to: CGPoint(x: w * 0.18, y: level1Y),
            control1: CGPoint(x: w * 0.40, y: h * 0.10),
            control2: CGPoint(x: w * 0.25, y: level1Y - 5)
        )
        path.addLine(to: CGPoint(x: w * 0.32, y: level1Y))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: topY),
            control1: CGPoint(x: w * 0.45, y: h * 0.20),
            control2: CGPoint(x: w * 0.55, y: h * 0.10)
        )

        path.move(to: CGPoint(x: w * 0.5, y: level1Y - 3))
        path.addCurve(
            to: CGPoint(x: w * 0.10, y: level2Y),
            control1: CGPoint(x: w * 0.35, y: level2Y - 15),
            control2: CGPoint(x: w * 0.18, y: level2Y - 5)
        )
        path.addLine(to: CGPoint(x: w * 0.30, y: level2Y))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: level1Y - 3),
            control1: CGPoint(x: w * 0.45, y: level2Y - 5),
            control2: CGPoint(x: w * 0.55, y: level1Y - 3)
        )

        path.move(to: CGPoint(x: w * 0.5, y: topY))
        path.addCurve(
            to: CGPoint(x: w * 0.82, y: level1Y),
            control1: CGPoint(x: w * 0.60, y: h * 0.10),
            control2: CGPoint(x: w * 0.75, y: level1Y - 5)
        )
        path.addLine(to: CGPoint(x: w * 0.68, y: level1Y))
        path.move(to: CGPoint(x: w * 0.5, y: level1Y - 3))
        path.addCurve(
            to: CGPoint(x: w * 0.90, y: level2Y),
            control1: CGPoint(x: w * 0.65, y: level2Y - 15),
            control2: CGPoint(x: w * 0.82, y: level2Y - 5)
        )
        path.addLine(to: CGPoint(x: w * 0.70, y: level2Y))

        path.move(to: CGPoint(x: w * 0.5, y: level2Y - 3))
        path.addCurve(
            to: CGPoint(x: 0, y: level3Y),
            control1: CGPoint(x: w * 0.30, y: level3Y - 15),
            control2: CGPoint(x: w * 0.10, y: level3Y - 5)
        )
        path.addLine(to: CGPoint(x: w * 0.30, y: level3Y))
        path.addLine(to: CGPoint(x: w * 0.30, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.70, y: level3Y))
        path.addLine(to: CGPoint(x: w, y: level3Y))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: level2Y - 3),
            control1: CGPoint(x: w * 0.90, y: level3Y - 5),
            control2: CGPoint(x: w * 0.70, y: level3Y - 15)
        )

        return path
    }
}

