//
//  FunnySFX.swift
//  Picksy
//
//  Καρτουνίστικα ηχητικά σχόλια (opt-in toggle στο μενού ήχου της Nudge):
//    • Ξεπέρασες τον στόχο σου → sad trombone «Φα-α-α-αααα» 🎺
//    • 8+ σηκώματα μέσα σε μία ώρα → slide-whistle «ουφφφφ» 😮‍💨
//
//  Όλα συντίθενται on-the-fly σε PCM buffer — κανένα asset, κανένα licensing.
//  Δικό του μικρό AVAudioEngine ανά αναπαραγωγή: δεν αγγίζει το audio session,
//  οπότε δεν ενοχλεί το AmbientSoundEngine αν παίζει ταυτόχρονα soundscape.
//

import AVFoundation

final class FunnySFX {

    static let shared = FunnySFX()
    private init() {}

    /// Toggle — persisted. Το UI το δένει με @AppStorage("funnySoundsOn").
    var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "funnySoundsOn") }
        set { UserDefaults.standard.set(newValue, forKey: "funnySoundsOn") }
    }

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var recentPickups: [Date] = []
    private var lastOufAt = Date.distantPast
    private var lastTromboneDay = ""

    /// Καλείται σε κάθε pickup όσο η εφαρμογή είναι ανοιχτή (NudgeView).
    /// Αποφασίζει αν η στιγμή αξίζει ηχητικό σχόλιο.
    func pickupRecorded(todayPickups: Int, goal: Int) {
        guard enabled else { return }
        let now = Date()
        recentPickups.append(now)
        recentPickups.removeAll { now.timeIntervalSince($0) > 3600 }

        // Στόχος ξεπεράστηκε ΜΟΛΙΣ τώρα (και μόνο μία φορά τη μέρα)
        if goal > 0, todayPickups == goal + 1, lastTromboneDay != dayKey() {
            lastTromboneDay = dayKey()
            play(buffer: makeSadTrombone())
            return
        }

        // Πολλά σηκώματα σε μία ώρα → «ουφφφ» (max μία φορά την ώρα)
        if recentPickups.count >= 8, now.timeIntervalSince(lastOufAt) > 3600 {
            lastOufAt = now
            play(buffer: makeSlideDown())
        }
    }

    private func dayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Duel sounds (ξεχωριστό toggle από τους «αστείους ήχους»)

    /// On/off από το ηχειάκι πάνω στο duel banner — default OFF.
    var duelSoundsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "duelSoundsOn") }
        set { UserDefaults.standard.set(newValue, forKey: "duelSoundsOn") }
    }

    /// Καλείται όταν εμφανίζεται το αποτέλεσμα μονομαχίας.
    func duelFinished(won: Bool) {
        guard duelSoundsEnabled else { return }
        play(buffer: won ? makeVictory() : makeDefeat())
    }

    // MARK: - DEV previews (Settings → DEV ONLY)

    /// Άμεση αναπαραγωγή για δοκιμή — αγνοεί το toggle και τα throttles.
    func previewTrombone() { play(buffer: makeSadTrombone()) }
    func previewOuf()      { play(buffer: makeSlideDown()) }
    func previewVictory()  { play(buffer: makeVictory()) }
    func previewDefeat()   { play(buffer: makeDefeat()) }

    // MARK: - Playback (μικρός αυτόνομος engine ανά εφέ)

    private func play(buffer: AVAudioPCMBuffer) {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        do { try engine.start() } catch { return }
        self.engine = engine
        self.player = player

        player.scheduleBuffer(buffer) { [weak self] in
            DispatchQueue.main.async {
                self?.engine?.stop()
                self?.engine = nil
                self?.player = nil
            }
        }
        player.play()
    }

    // MARK: - Synthesis

    private static let sr: Double = 44_100

    private func makeBuffer(seconds: Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Self.sr,
                                         channels: 1) else { return nil }
        let frames = AVAudioFrameCount(seconds * Self.sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format,
                                         frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        return buf
    }

    /// Sad trombone: τέσσερις φθόγγοι που κατηφορίζουν (Bb-A-Ab-G), ο
    /// τελευταίος μακρύς με βαρύ βιμπράτο — το κλασικό «wah-wah-wah-waaah».
    private func makeSadTrombone() -> AVAudioPCMBuffer {
        let notes: [(f: Double, d: Double)] = [
            (233.08, 0.30), (220.00, 0.30), (207.65, 0.30), (196.00, 1.05)
        ]
        let gap = 0.06
        let total = notes.reduce(0) { $0 + $1.d } + gap * Double(notes.count - 1) + 0.1
        guard let buf = makeBuffer(seconds: total) else { return AVAudioPCMBuffer() }
        let out = buf.floatChannelData![0]

        var cursor = 0.0
        var lowpass: Double = 0
        for (i, note) in notes.enumerated() {
            let isLast = i == notes.count - 1
            let startFrame = Int(cursor * Self.sr)
            let noteFrames = Int(note.d * Self.sr)
            var phase = 0.0
            for n in 0..<noteFrames {
                let t = Double(n) / Self.sr
                // Βιμπράτο: ελαφρύ στους πρώτους, βαθύ και αργό στον τελευταίο
                let vib = isLast ? 1 + 0.045 * sin(2 * .pi * 5.2 * t)
                                 : 1 + 0.010 * sin(2 * .pi * 6.0 * t)
                phase += 2 * .pi * note.f * vib / Self.sr
                // «Χάλκινο» σώμα: πριονωτό κύμα περασμένο από lowpass
                let saw = 2 * (phase / (2 * .pi)).truncatingRemainder(dividingBy: 1) - 1
                lowpass += 0.25 * (saw - lowpass)
                // Φάκελος: γρήγορο attack, ουρά στο τέλος του τελευταίου
                let attack = min(t / 0.02, 1)
                let release = isLast
                    ? max(0, 1 - max(0, t - (note.d - 0.45)) / 0.45)
                    : max(0, 1 - max(0, t - (note.d - 0.05)) / 0.05)
                out[startFrame + n] = Float(lowpass * 0.42 * attack * release)
            }
            cursor += note.d + gap
        }
        return buf
    }

    /// Ήχος νίκης: 8-bit victory fanfare — ανοδικό αρπέζ ντο μείζονας
    /// «τα-τα-τα-ΤΑΑΑ!», με την τελευταία νότα να ανθίζει σε ΣΥΓΧΟΡΔΙΑ
    /// (C6+G5+E5) με βιμπράτο. Ίδια retro αισθητική με τον ήχο ήττας —
    /// ζευγάρι από το ίδιο «παιχνίδι».
    private func makeVictory() -> AVAudioPCMBuffer {
        let notes: [(f: Double, d: Double)] = [
            (523.25, 0.13), (659.25, 0.13), (783.99, 0.13), (1046.50, 0.85)
        ]
        let gap = 0.03
        let total = notes.reduce(0) { $0 + $1.d } + gap * Double(notes.count - 1) + 0.1
        guard let buf = makeBuffer(seconds: total) else { return AVAudioPCMBuffer() }
        let out = buf.floatChannelData![0]

        var cursor = 0.0
        var lp: Double = 0
        for (i, note) in notes.enumerated() {
            let isLast = i == notes.count - 1
            let startFrame = Int(cursor * Self.sr)
            let noteFrames = Int(note.d * Self.sr)
            var phase = 0.0
            var phase2 = 0.0    // πέμπτη κάτω (G5) — μόνο στο φινάλε
            var phase3 = 0.0    // τρίτη (E5) — μόνο στο φινάλε
            for n in 0..<noteFrames {
                let t = Double(n) / Self.sr
                let vib = isLast ? 1 + 0.012 * sin(2 * .pi * 6.0 * t) : 1
                phase += 2 * .pi * note.f * vib / Self.sr

                func square(_ p: Double) -> Double {
                    (p / (2 * .pi)).truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : -1
                }
                var v = square(phase)
                if isLast {
                    // Η κορώνα ανθίζει σε πλήρη μείζονα συγχορδία
                    phase2 += 2 * .pi * 783.99 * vib / Self.sr
                    phase3 += 2 * .pi * 659.25 * vib / Self.sr
                    v = v * 0.6 + square(phase2) * 0.30 + square(phase3) * 0.24
                }
                lp += 0.18 * (v - lp)
                let attack = min(t / 0.012, 1)
                let release = isLast
                    ? max(0, 1 - max(0, t - (note.d - 0.45)) / 0.45)
                    : max(0, 1 - max(0, t - (note.d - 0.03)) / 0.03)
                out[startFrame + n] = Float(lp * 0.26 * attack * release)
            }
            cursor += note.d + gap
        }
        return buf
    }

    /// Ήχος ήττας: 8-bit «game over» — τέσσερις νότες που κατηφορίζουν σε
    /// τετραγωνικό κύμα, η τελευταία βαθιά με βιμπράτο και αργό σβήσιμο. 📉
    private func makeDefeat() -> AVAudioPCMBuffer {
        let notes: [(f: Double, d: Double)] = [
            (392.00, 0.18), (329.63, 0.18), (261.63, 0.18), (196.00, 0.95)
        ]
        let gap = 0.04
        let total = notes.reduce(0) { $0 + $1.d } + gap * Double(notes.count - 1) + 0.1
        guard let buf = makeBuffer(seconds: total) else { return AVAudioPCMBuffer() }
        let out = buf.floatChannelData![0]

        var cursor = 0.0
        var lp: Double = 0
        for (i, note) in notes.enumerated() {
            let isLast = i == notes.count - 1
            let startFrame = Int(cursor * Self.sr)
            let noteFrames = Int(note.d * Self.sr)
            var phase = 0.0
            for n in 0..<noteFrames {
                let t = Double(n) / Self.sr
                let vib = isLast ? 1 + 0.02 * sin(2 * .pi * 4.5 * t) : 1
                phase += 2 * .pi * note.f * vib / Self.sr
                // Τετραγωνικό κύμα + ελαφρύ lowpass για να μην «τρυπάει»
                let square: Double = (phase / (2 * .pi)).truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : -1
                lp += 0.18 * (square - lp)
                let attack = min(t / 0.015, 1)
                let release = isLast
                    ? max(0, 1 - max(0, t - (note.d - 0.5)) / 0.5)
                    : max(0, 1 - max(0, t - (note.d - 0.04)) / 0.04)
                out[startFrame + n] = Float(lp * 0.24 * attack * release)
            }
            cursor += note.d + gap
        }
        return buf
    }

    /// Slide-whistle προς τα κάτω: γλίστρημα 1300 → 260 Hz με «ανάσα» — το
    /// ηχητικό ισοδύναμο ενός «ουφφφφφ» 😮‍💨
    private func makeSlideDown() -> AVAudioPCMBuffer {
        let dur = 0.95
        guard let buf = makeBuffer(seconds: dur + 0.05) else { return AVAudioPCMBuffer() }
        let out = buf.floatChannelData![0]
        let frames = Int(dur * Self.sr)
        var phase = 0.0
        var breath: Double = 0
        for n in 0..<frames {
            let t = Double(n) / Self.sr
            let p = t / dur
            // Εκθετικό γλίστρημα — ακούγεται φυσικό για slide whistle
            let f = 1300 * pow(260 / 1300, p)
            phase += 2 * .pi * f / Self.sr
            // Λίγη «ανάσα» από φιλτραρισμένο θόρυβο για ρεαλισμό
            breath += 0.15 * (Double.random(in: -1...1) - breath)
            let attack = min(t / 0.03, 1)
            let release = max(0, 1 - max(0, t - (dur - 0.30)) / 0.30)
            out[n] = Float((sin(phase) * 0.30 + breath * 0.05) * attack * release)
        }
        return buf
    }
}
