import AVFoundation
import CoreHaptics
import SwiftUI
import UIKit

/// The app's sound and touch feedback. Sounds are short synthesized chiptune-style blips (no audio
/// files), the same notes as the Android app. They follow the silent switch.
@MainActor
final class Feedback: ObservableObject {
    @Published var soundOn: Bool = UserDefaults.standard.object(forKey: "sound") as? Bool ?? true {
        didSet { UserDefaults.standard.set(soundOn, forKey: "sound") }
    }

    private var cache: [String: Data] = [:]
    private var playing: [AVAudioPlayer] = []

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        generators.values.forEach { $0.prepare() }
    }

    // MARK: Moments

    /// Navigation and small taps.
    func tap() { impact(.rigid, 0.8); play("tap", [N(84, 18, gain: 0.5)]) }

    /// Checking or unchecking a chore.
    func tick(_ on: Bool) {
        impact(on ? .heavy : .rigid, on ? 1 : 0.8)
        if on { play("on", [N(76, 35), N(83, 60)]) } else { play("off", [N(76, 30), N(69, 50, gain: 0.7)]) }
    }

    /// "Suggest a card": a quick run up the scale.
    func fill() {
        pattern([(0, 0.6), (47, 0.75), (94, 0.9), (141, 1)])
        play("fill", [N(72, 40), N(76, 40), N(79, 40), N(83, 40), N(84, 110)])
    }

    /// The card just reached a full day's worth.
    func ready() { pattern([(0, 0.9), (110, 1)]); play("ready", [N(79, 60), N(86, 140)]) }

    func lockIn() { impact(.heavy, 1); play("lock", [N(60, 70, wave: 1), N(67, 70, wave: 1), N(72, 160, wave: 1)]) }

    func submit() {
        pattern([(0, 0.7), (70, 0.85), (140, 1)])
        play("submit", [N(72, 80), N(76, 80), N(79, 80), N(84, 240)])
    }

    /// A dare placed: a sly little two-step.
    func dare() {
        pattern([(0, 0.8), (80, 1)])
        play("dare", [N(70, 60, wave: 0.6), N(0, 30), N(77, 50, wave: 0.6), N(82, 140, wave: 0.6)])
    }

    /// Yesterday's dares landed: sparkle.
    func dareLanded() {
        pattern([(0, 0.8), (60, 0.9), (120, 1)])
        play("landed", [N(88, 45), N(91, 45), N(95, 45), N(100, 220, gain: 0.8)])
    }

    /// Parent approved a chore: a coin-like two-note chime.
    func approve() { notify(.success); play("approve", [N(83, 60), N(88, 220)]) }

    func reject() {
        notify(.warning)
        play("reject", [N(57, 110, end: 52, wave: 1, gain: 0.8), N(50, 180, end: 45, wave: 1, gain: 0.8)])
    }

    /// Something isn't allowed (chore doesn't fit, wrong code).
    func error() {
        notify(.error)
        play("error", [N(48, 90, wave: 1, gain: 0.8), N(0, 30), N(48, 120, wave: 1, gain: 0.8)])
    }

    func unlock() { impact(.heavy, 1); play("unlock", [N(67, 50), N(74, 50), N(79, 50), N(86, 180)]) }

    /// A new version shipped: the big one.
    func levelUp() {
        pattern([(0, 0.7), (80, 0.8), (160, 0.9), (240, 1), (360, 1), (420, 1)])
        play("level", [N(72, 90, wave: 0.6), N(72, 90, wave: 0.6), N(72, 90, wave: 0.6), N(79, 180, wave: 0.6),
                       N(77, 90, wave: 0.6), N(79, 90, wave: 0.6), N(84, 420, wave: 0.6), N(96, 300, gain: 0.5)])
    }

    // MARK: Puzzle

    /// Picking up a block.
    func puzzleSelect() { impact(.rigid, 0.55); play("pz-sel", [N(88, 22, gain: 0.45), N(95, 30, gain: 0.35)]) }

    /// Two blocks collide and vanish: a sharp crack with a little weight behind it.
    func puzzleMatch() {
        if !rich([Self.hit(0, 1, 1), Self.hit(0.012, 0.6, 0.15)]) { impact(.heavy, 1) }
        play("pz-hit", [N(98, 22, end: 74, wave: 1, gain: 0.55), N(62, 70, end: 41, wave: 0.8, gain: 0.7)])
    }

    /// That block can't be reached from here.
    func puzzleMiss() {
        pattern([(0, 0.45), (62, 0.45)])
        play("pz-miss", [N(52, 50, wave: 1, gain: 0.6), N(0, 20), N(47, 70, wave: 1, gain: 0.6)])
    }

    /// The board is clear — the big one, in three beats timed to the screen: the impact, `freeze`
    /// seconds of dead stillness while the frame is frozen, then a surge that quickens into a slam.
    func puzzleLevelUp(freeze: TimeInterval) {
        let f = freeze
        var events = [Self.hit(0, 1, 1), Self.rumble(0, 0.07, 1, 0.15),
                      Self.hit(f, 1, 0.9), Self.rumble(f, 0.62, 1, 0.3)]
        // Ticks that come faster and harder, like a charge building.
        for (i, t) in [0.10, 0.18, 0.25, 0.31, 0.36, 0.40, 0.43].enumerated() {
            events.append(Self.hit(f + t, Float(0.7 + 0.05 * Double(i)), 0.6))
        }
        events += [Self.hit(f + 0.5, 1, 0.25), Self.rumble(f + 0.5, 0.3, 1, 0.05)]
        // The surge swells, holds through the slam, then dies away.
        let swell = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 0.4), .init(relativeTime: 0.35, value: 1),
            .init(relativeTime: 0.52, value: 1), .init(relativeTime: 0.8, value: 0),
        ], relativeTime: f)
        let edge = CHHapticParameterCurve(parameterID: .hapticSharpnessControl, controlPoints: [
            .init(relativeTime: 0, value: -0.2), .init(relativeTime: 0.35, value: 0.4), .init(relativeTime: 0.5, value: 0),
        ], relativeTime: f)
        if !rich(events, curves: [swell, edge]) {
            let ms = Int(f * 1000)
            pattern([(0, 1), (ms, 0.7), (ms + 100, 0.75), (ms + 180, 0.8), (ms + 250, 0.85), (ms + 310, 0.9),
                     (ms + 360, 0.95), (ms + 400, 1), (ms + 430, 1), (ms + 500, 1)])
            DispatchQueue.main.asyncAfter(deadline: .now() + f + 0.5) { [weak self] in
                MainActor.assumeIsolated { self?.impact(.heavy, 1) }
            }
        }
        let rest = max(0, Int(f * 1000) - 110)
        play("pz-level-\(rest)", [
            N(40, 110, end: 26, wave: 1, gain: 0.9), N(0, rest),
            N(36, 90, end: 48, wave: 1, gain: 0.8),
            N(60, 55, wave: 0.6), N(64, 55, wave: 0.6), N(67, 55, wave: 0.6), N(72, 55, wave: 0.6),
            N(76, 55, wave: 0.6), N(79, 55, wave: 0.6), N(84, 340, wave: 0.6),
            N(96, 60, gain: 0.45), N(103, 260, gain: 0.4),
        ])
    }

    // MARK: Haptics

    /// Core Haptics, for the puzzle's moments: sharper, heavier and more precisely timed than the
    /// stock generators. Nil on hardware without it (an iPad), where the generators stand in.
    private lazy var hapticEngine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine = try? CHHapticEngine() else { return nil }
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak engine] in try? engine?.start() }
        return engine
    }()

    /// Plays a Core Haptics pattern. False when this device can't, so the caller can fall back.
    private func rich(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve] = []) -> Bool {
        guard let engine = hapticEngine,
              let pattern = try? CHHapticPattern(events: events, parameterCurves: curves),
              (try? engine.start()) != nil,
              let player = try? engine.makePlayer(with: pattern) else { return false }
        return (try? player.start(atTime: CHHapticTimeImmediate)) != nil
    }

    /// A single tap: strength and sharpness 0…1, `t` seconds into the pattern.
    private static func hit(_ t: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: t)
    }

    /// A held buzz.
    private static func rumble(_ t: TimeInterval, _ duration: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: t, duration: duration)
    }

    // Firm and strong by design: "rigid" is the crisp, hard-edged tap and "heavy" the full thud,
    // both played near full strength. The generators are kept and re-armed after every use, because
    // one made on the spot fires before the Taptic Engine is awake and lands soft and late.
    private let generators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [
        .rigid: UIImpactFeedbackGenerator(style: .rigid),
        .heavy: UIImpactFeedbackGenerator(style: .heavy),
    ]
    private let notifier = UINotificationFeedbackGenerator()

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, _ intensity: CGFloat) {
        guard let generator = generators[style] else { return }
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
    }

    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notifier.notificationOccurred(type)
        notifier.prepare()
    }

    /// A run of taps: (delay in ms from the start, strength 0…1).
    private func pattern(_ taps: [(Int, CGFloat)]) {
        for (ms, strength) in taps {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms)) { [weak self] in
                MainActor.assumeIsolated { self?.impact(.rigid, strength) }
            }
        }
    }

    // MARK: Synth

    /// One note. `midi` 0 is a rest. `end` glides the pitch. `wave` blends sine (0) to square (1).
    private struct N {
        let midi: Int, ms: Int, end: Int, wave: Double, gain: Double
        init(_ midi: Int, _ ms: Int, end: Int? = nil, wave: Double = 0.3, gain: Double = 1) {
            self.midi = midi; self.ms = ms; self.end = end ?? midi; self.wave = wave; self.gain = gain
        }
    }

    private static let sampleRate = 44100
    private static let master = 0.32

    private func play(_ key: String, _ notes: @autoclosure () -> [N]) {
        guard soundOn else { return }
        let wav = cache[key] ?? Self.wav(Self.synth(notes()))
        cache[key] = wav
        guard let p = try? AVAudioPlayer(data: wav) else { return }
        playing.removeAll { !$0.isPlaying }
        playing.append(p)
        p.play()
    }

    private static func synth(_ notes: [N]) -> [Int16] {
        var out: [Int16] = []
        for n in notes {
            let len = sampleRate * n.ms / 1000
            guard n.midi != 0 else { out += [Int16](repeating: 0, count: len); continue }
            let f0 = 440 * pow(2, Double(n.midi - 69) / 12), f1 = 440 * pow(2, Double(n.end - 69) / 12)
            let attack = max(1, Double(sampleRate) * 0.003), release = max(1, Double(sampleRate) * 0.006)
            var phase = 0.0
            for i in 0..<len {
                let t = Double(i) / Double(len)
                phase += 2 * .pi * (f0 + (f1 - f0) * t) / Double(sampleRate)
                let s = sin(phase)
                let shaped = s * (1 - n.wave) + (s >= 0 ? 1 : -1) * n.wave * 0.6
                let env = min(1, Double(i) / attack) * exp(-3 * t) * min(1, Double(len - i) / release)
                out.append(Int16(shaped * env * n.gain * master * Double(Int16.max)))
            }
        }
        return out
    }

    /// Wraps 16-bit mono PCM in a WAV header so AVAudioPlayer can play it from memory.
    private static func wav(_ pcm: [Int16]) -> Data {
        var d = Data()
        func u32(_ v: Int) { withUnsafeBytes(of: UInt32(v).littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: Int) { withUnsafeBytes(of: UInt16(v).littleEndian) { d.append(contentsOf: $0) } }
        let bytes = pcm.count * 2
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes); d.append(contentsOf: Array("WAVEfmt ".utf8))
        u32(16); u16(1); u16(1); u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(bytes)
        pcm.withUnsafeBufferPointer { d.append(UnsafeBufferPointer(start: UnsafeRawPointer($0.baseAddress!).assumingMemoryBound(to: UInt8.self), count: bytes)) }
        return d
    }
}
