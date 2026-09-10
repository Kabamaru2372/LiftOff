//
//  AmbientSoundEngine.swift
//  Picksy
//
//  Mindfulness soundscapes — ΟΛΟΙ οι ήχοι συντίθενται σε πραγματικό χρόνο με
//  AVAudioEngine (κανένα audio asset, κανένα licensing, 0 MB στο binary).
//
//  Plays in the BACKGROUND (UIBackgroundModes: audio) με Now Playing info και
//  lock-screen play/pause, όπως απαιτεί η Apple για background-audio apps.
//  Διακοπές (κλήσεις κ.λπ.) γίνονται handle — pause στο interruption, resume
//  όταν τελειώσει αν έπαιζε πριν.
//

import AVFoundation
import MediaPlayer
import Observation
import UIKit

// MARK: - Sound catalogue

enum AmbientSound: String, CaseIterable, Identifiable {
    case rain
    case ocean
    case birds
    case pink
    case white

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .rain:  return "cloud.rain.fill"
        case .ocean: return "water.waves"
        case .birds: return "bird.fill"
        case .pink:  return "waveform"
        case .white: return "wind"
        }
    }

    func displayName(language: String) -> String {
        switch self {
        case .rain:
            switch language {
            case "Ελληνικά": return "Βροχή"
            case "Deutsch":  return "Regen"
            default:         return "Rain"
            }
        case .ocean:
            switch language {
            case "Ελληνικά": return "Ωκεανός"
            case "Deutsch":  return "Ozean"
            default:         return "Ocean"
            }
        case .birds:
            switch language {
            case "Ελληνικά": return "Πουλιά στη φύση"
            case "Deutsch":  return "Vögel in der Natur"
            default:         return "Birds in nature"
            }
        case .pink:
            switch language {
            case "Ελληνικά": return "Απαλός θόρυβος"
            case "Deutsch":  return "Sanftes Rauschen"
            default:         return "Soft noise"
            }
        case .white:
            switch language {
            case "Ελληνικά": return "Λευκός θόρυβος"
            case "Deutsch":  return "Weißes Rauschen"
            default:         return "White noise"
            }
        }
    }
}

// MARK: - Engine

@Observable
final class AmbientSoundEngine {

    static let shared = AmbientSoundEngine()

    private(set) var isPlaying = false

    /// Επιλεγμένος ήχος — persisted. Αν αλλάξει ενώ παίζει, μεταβαίνει live.
    var sound: AmbientSound {
        didSet {
            UserDefaults.standard.set(sound.rawValue, forKey: "ambientSoundChoice")
            if isPlaying {
                renderState.switchTo(sound)
                updateNowPlaying()
            }
        }
    }

    /// «Ανάλογα με τον καιρό»: όταν είναι ΟΝ, ο ήχος επιλέγεται αυτόματα από
    /// τις τρέχουσες καιρικές συνθήκες (η NudgeView κάνει το mapping και
    /// ενημερώνει το `sound` — ο engine απλώς θυμάται την προτίμηση).
    var weatherMode: Bool {
        didSet { UserDefaults.standard.set(weatherMode, forKey: "ambientWeatherMode") }
    }

    /// Καιρός → soundscape. Προτεραιότητες: βροχή/καταιγίδα πρώτα, μετά ζέστη
    /// (≥27°C → θάλασσα), μετά ήλιος → πουλιά. Τη νύχτα (ή με βαριά συννεφιά)
    /// πέφτουμε στο απαλό noise — τιτιβίσματα στις 3 τα ξημερώματα ξενίζουν.
    static func soundForWeather(condition: WeatherCondition,
                                tempC: Double?,
                                isNight: Bool) -> AmbientSound {
        switch condition {
        case .rainy, .thunderstorm: return .rain
        case .snow:                 return .pink
        case .hot:                  return .ocean
        default: break
        }
        if let t = tempC, t >= 27 { return .ocean }
        if isNight { return .pink }
        switch condition {
        case .sunny, .partlyCloudy: return .birds
        default:                    return .pink   // cloudy/foggy/windy/cold/unknown
        }
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let renderState = RenderState()
    private var interruptedWhilePlaying = false

    /// Όλες οι κλήσεις προς AVAudioSession/AVAudioEngine γίνονται εδώ — η
    /// (απ)ενεργοποίηση του session μπορεί να μπλοκάρει δεκάδες ms και το iOS
    /// προειδοποιεί ρητά να μην τρέχει στο main thread (UI hitch στο play).
    private let audioQueue = DispatchQueue(label: "picksy.ambient.audio",
                                           qos: .userInitiated)

    private init() {
        let saved = UserDefaults.standard.string(forKey: "ambientSoundChoice")
        sound = AmbientSound(rawValue: saved ?? "") ?? .rain
        weatherMode = UserDefaults.standard.bool(forKey: "ambientWeatherMode")
        renderState.switchTo(sound)
        setupRemoteCommands()
        observeInterruptions()
    }

    // MARK: Public controls

    func toggle() {
        isPlaying ? stop() : start()
    }

    func start() {
        guard !isPlaying else { return }
        // Optimistic: το UI (εικονίδιο ηχείου) αντιδρά αμέσως· το πραγματικό
        // στήσιμο γίνεται στο audioQueue και ο ήχος μπαίνει με fade ούτως ή άλλως.
        isPlaying = true
        renderState.switchTo(sound)
        renderState.targetGain = 1.0          // fade-in happens in the render loop

        audioQueue.async { [weak self] in
            guard let self else { return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)

                if self.sourceNode == nil { self.attachSource() }
                try self.engine.start()

                DispatchQueue.main.async {
                    self.updateNowPlaying()
                    // "Be present" mode: όσο παίζει ambience στο προσκήνιο, η
                    // οθόνη δεν σβήνει — η ζωντανή σκηνή μένει ορατή.
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            } catch {
                // Audio is a nicety — never crash the mindfulness app over it.
                print("⚠️ AmbientSoundEngine start failed: \(error.localizedDescription)")
                DispatchQueue.main.async { self.isPlaying = false }
            }
        }
    }

    func stop() {
        guard isPlaying else { return }
        // Quick fade-out in the render loop, then tear down on the audio queue.
        renderState.targetGain = 0.0
        isPlaying = false
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        audioQueue.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, !self.isPlaying else { return }
            self.engine.pause()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            DispatchQueue.main.async {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }
        }
    }

    // MARK: Engine plumbing

    private func attachSource() {
        let format = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)
        let state = renderState
        state.sampleRate = sampleRate

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            state.render(frames: Int(frameCount), buffers: ablPointer)
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.85
        sourceNode = node
    }

    // MARK: Now Playing / lock-screen controls

    // Apple documents MPRemoteCommandCenter handlers as callable on an
    // arbitrary queue, not guaranteed main-thread — lock screen / Control
    // Center / headset controls all route through here. start()/stop()/
    // toggle() mutate the @Observable `isPlaying` directly with no isolation
    // of their own, so without an explicit hop to main here, a handler firing
    // off-main would mutate SwiftUI-observed state off the main actor.
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.start() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.stop() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.toggle() }
            return .success
        }
    }

    private func updateNowPlaying() {
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: sound.displayName(language: language),
            MPMediaItemPropertyArtist: "Picksy",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
    }

    // MARK: Interruptions (calls, Siri, other audio)

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let info = note.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
            else { return }

            switch type {
            case .began:
                self.interruptedWhilePlaying = self.isPlaying
                if self.isPlaying { self.stop() }
            case .ended:
                let optsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let opts = AVAudioSession.InterruptionOptions(rawValue: optsRaw)
                if self.interruptedWhilePlaying && opts.contains(.shouldResume) {
                    self.start()
                }
                self.interruptedWhilePlaying = false
            @unknown default:
                break
            }
        }
    }
}

// MARK: - DSP render state (runs on the realtime audio thread)

/// Όλο το DSP state σε ένα final class που διαβάζει ΜΟΝΟ το render callback
/// (συν atomic-ish flags που γράφει ο main — απλά Float/Int, αποδεκτό για
/// ambience: το χειρότερο race είναι ένα sample με μισό-παλιό gain).
private final class RenderState {

    var sampleRate: Float = 48_000
    var targetGain: Float = 0          // main thread sets; render eases toward it
    private var gain: Float = 0        // smoothed master gain (fade in/out)

    private var mode: AmbientSound = .rain

    // Noise generator state (ανά κανάλι για φυσικό stereo πλάτος)
    private var rng = SystemRandomNumberGenerator()
    private var lp1: [Float] = [0, 0]       // 1-pole LP — rain body / ocean foam / soft stage 1
    private var lp2: [Float] = [0, 0]       // soft-noise stage 2
    private var brown: [Float] = [0, 0]     // deep water rumble
    private var dropEnv: Float = 0          // rain patter burst envelope
    private var gust: Float = 0.9           // rain density (slow random drift)
    private var gustTarget: Float = 0.9
    private var gustCounter: Int = 0
    private var wavePh1: Float = 0          // ocean swell phases (two periods,
    private var wavePh2: Float = 1.0        //  ~13 s + ~20 s, never in sync)

    private var rustlePh: Float = 0         // αεράκι στα φύλλα (αργό LFO)

    // Birdsong state (μία «φωνή», mono στο κέντρο)
    private var chirpDur: Float = 0         // διάρκεια ενεργού τιτιβίσματος (0 = ανενεργό)
    private var chirpT: Float = 0           // χρόνος μέσα στο τιτίβισμα
    private var chirpPhase: Float = 0
    private var chirpF0: Float = 2_800      // συχνότητα αρχής/τέλους του sweep
    private var chirpF1: Float = 2_400
    private var chirpGap: Int = 24_000      // samples μέχρι το επόμενο τιτίβισμα
    private var chirpsLeft: Int = 0         // πόσα απομένουν στην τρέχουσα φράση
    private var phraseGain: Float = 0.15    // κοντινό ή μακρινό πουλί

    func switchTo(_ sound: AmbientSound) {
        mode = sound
    }

    private func white() -> Float {
        Float(UInt32.random(in: 0...UInt32.max, using: &rng)) / Float(UInt32.max) * 2 - 1
    }

    func render(frames: Int, buffers: UnsafeMutableAudioBufferListPointer) {
        let chans = min(buffers.count, 2)
        var outs: [UnsafeMutablePointer<Float>?] = []
        for b in 0..<buffers.count {
            outs.append(buffers[b].mData?.assumingMemoryBound(to: Float.self))
        }
        guard chans > 0 else { return }

        let fadeStep: Float = 1.0 / (0.7 * sampleRate)   // ~0.7 s fade

        for frame in 0..<frames {
            // Smooth master gain toward the target (fade in/out)
            if gain < targetGain { gain = min(gain + fadeStep, targetGain) }
            else if gain > targetGain { gain = max(gain - fadeStep, targetGain) }

            for ch in 0..<chans {
                var sample: Float = 0
                let w = white()

                switch mode {
                case .white:
                    sample = w * 0.16

                case .pink:
                    // "Απαλός θόρυβος" = βαθύ, πνιχτό hush σαν ανεμιστήρα/καμπίνα
                    // αεροπλάνου: white μέσα από ΔΥΟ διαδοχικά lowpass (~400 Hz).
                    lp1[ch] += 0.05 * (w - lp1[ch])
                    lp2[ch] += 0.05 * (lp1[ch] - lp2[ch])
                    sample = lp2[ch] * 2.1

                case .ocean:
                    // Δύο ασύγχρονα κύματα (~13 s & ~20 s)· κάθε κορύφωση φέρνει
                    // ΦΩΤΕΙΝΟ αφρό (hiss) πάνω από το μόνιμο βαθύ βουητό — το
                    // αναγνωρίσιμο «σκάσιμο-σβήσιμο» του κύματος.
                    brown[ch] += 0.015 * (w - brown[ch])
                    lp1[ch]   += 0.22  * (w - lp1[ch])          // foam wash
                    if ch == 0 {
                        wavePh1 += (2 * .pi * 0.078) / sampleRate
                        wavePh2 += (2 * .pi * 0.049) / sampleRate
                        if wavePh1 > 2 * .pi { wavePh1 -= 2 * .pi }
                        if wavePh2 > 2 * .pi { wavePh2 -= 2 * .pi }
                    }
                    let s1 = max(0, sin(wavePh1))
                    let s2 = max(0, sin(wavePh2 + 1.1))
                    // sin³ → αργό φούσκωμα, αιχμηρή κορυφή, αργό σβήσιμο
                    let wash = s1 * s1 * s1 * 0.85 + s2 * s2 * s2 * 0.55
                    sample = brown[ch] * (0.9 + 2.4 * wash)
                           + lp1[ch] * wash * 0.50

                case .birds:
                    // Μόνο πουλιά + ΕΛΑΦΡΥ θρόισμα φύλλων (το παλιό noise bed
                    // αφαιρέθηκε). Θρόισμα = band-passed white που «ανασαίνει»
                    // πολύ αργά σαν αεράκι — σχεδόν σιωπή ανάμεσα στις πνοές.
                    lp1[ch] += 0.30  * (w - lp1[ch])      // φωτεινό όριο
                    lp2[ch] += 0.045 * (w - lp2[ch])      // βαθύ όριο
                    let leaves = lp1[ch] - lp2[ch]        // ~400 Hz – 3 kHz
                    if ch == 0 {
                        rustlePh += (2 * .pi * 0.06) / sampleRate
                        if rustlePh > 2 * .pi { rustlePh -= 2 * .pi }
                    }
                    let gustS = sin(rustlePh + 0.6 * sin(rustlePh * 2.3))
                    let breeze = 0.15 + 0.85 * max(0, gustS) * max(0, gustS)
                    sample = leaves * 0.07 * breeze

                    if ch == 0 {
                        if chirpGap > 0 {
                            chirpGap -= 1
                        } else if chirpDur <= 0 {
                            // Νέο τιτίβισμα: 80–220 ms, 2.2–3.8 kHz, πάνω ή κάτω
                            chirpDur = 0.08 + 0.14 * (white() * 0.5 + 0.5)
                            chirpT = 0
                            chirpPhase = 0
                            chirpF0 = 2_200 + 1_600 * (white() * 0.5 + 0.5)
                            chirpF1 = chirpF0 * (0.72 + 0.60 * (white() * 0.5 + 0.5))
                            if chirpsLeft <= 0 {
                                chirpsLeft = 2 + Int((white() * 0.5 + 0.5) * 3.99)
                                phraseGain = white() > 0.2 ? 0.15 : 0.06
                            }
                        }
                        if chirpDur > 0 {
                            chirpT += 1 / sampleRate
                            let tt = min(chirpT / chirpDur, 1)
                            let f = chirpF0 + (chirpF1 - chirpF0) * tt
                                  + 90 * sin(chirpT * 2 * .pi * 42)   // βιμπράτο
                            chirpPhase += (2 * .pi * f) / sampleRate
                            if chirpT >= chirpDur {
                                chirpDur = 0
                                chirpsLeft -= 1
                                chirpGap = chirpsLeft > 0
                                    ? Int(sampleRate * (0.07 + 0.13 * (white() * 0.5 + 0.5)))
                                    : Int(sampleRate * (1.6 + 3.4 * (white() * 0.5 + 0.5)))
                            }
                        }
                    }
                    if chirpDur > 0 {
                        let tt = min(chirpT / chirpDur, 1)
                        let env = sin(.pi * tt)
                        sample += sin(chirpPhase) * env * env * phraseGain
                    }

                case .rain:
                    // Η βροχή είναι ΦΩΤΕΙΝΟ, ψιλό σφύριγμα — high-passed white
                    // (το παλιό lowpass ακουγόταν σαν μπάσο μουρμουρητό).
                    lp1[ch] += 0.06 * (w - lp1[ch])
                    let hiss = w - lp1[ch]                      // > ~500 Hz

                    if ch == 0 {
                        // Ριπές: η πυκνότητα της βροχής ανασαίνει κάθε ~1.5 s
                        gustCounter += 1
                        if gustCounter >= Int(sampleRate * 1.5) {
                            gustCounter = 0
                            gustTarget = 0.72 + 0.38 * (white() * 0.5 + 0.5)
                        }
                        gust += (gustTarget - gust) * (1.2 / sampleRate)

                        // Πάτερ: αραιές ριπές ΘΟΡΥΒΟΥ 4 ms (σταγόνες σε
                        // επιφάνειες) — όχι ημιτονοειδή «μπιπ».
                        if dropEnv <= 0.01, white() > 0.99985 {  // ≈ 3-4/s
                            dropEnv = 0.9
                        }
                        dropEnv *= 1 - 230 / sampleRate          // τ ≈ 4 ms
                    }

                    sample = hiss * 0.30 * gust
                           + lp1[ch] * 0.05
                           + w * dropEnv * 0.22
                }

                // Safety clamp — κανένα mode δεν επιτρέπεται να ψαλιδίσει
                outs[ch]?[frame] = max(-0.85, min(0.85, sample)) * gain
            }
            // Mono fallback safety: copy ch0 to any extra buffers
            if buffers.count > chans, let src = outs[0]?[frame] {
                for extra in chans..<buffers.count {
                    outs[extra]?[frame] = src
                }
            }
        }
    }
}
