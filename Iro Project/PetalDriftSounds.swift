//
//  PetalDriftSounds.swift
//  Iro Project
//

import AVFoundation

/// Petal Drift's nature sounds, synthesized live: water drops, rustling leaves,
/// a gentle breeze and little birds. No music or instruments.
nonisolated final class PetalDriftSounds: @unchecked Sendable {
    static let volume: Float = 0.7

    private let sampleRate = 44_100.0
    private var engine: AVAudioEngine?

    // Shared with the audio thread, guarded by `lock`
    private let lock = NSLock()
    private var voices: [Voice] = []
    private var masterTarget: Float
    private var breezeTarget: Float = 0

    // Audio-thread state
    private var master: Float
    private var breezeLevel: Float = 0
    private var breezeBrown: Float = 0
    private var breezeLow: Float = 0
    private var lfoPhase: Float = 0
    private var seed: UInt32 = 0x9E37_79B9

    init(soundOn: Bool) {
        masterTarget = soundOn ? Self.volume : 0
        master = masterTarget
    }

    deinit { engine?.stop() }

    // MARK: - Controls (call from the main thread)

    /// Starts the audio engine; safe to call more than once.
    func start() {
        guard engine == nil else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let engine = AVAudioEngine()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let out = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            if let self {
                self.render(into: out, count: Int(frameCount))
            } else {
                out.update(repeating: 0, count: Int(frameCount))
            }
            return noErr
        }
        engine.attach(node)
        do {
            try engine.connectNode(node, to: engine.mainMixerNode, format: format)
            try engine.start()
            self.engine = engine
        } catch {
            // No audio available (e.g. in some previews); the game still plays silently
        }
    }

    func shutdown() {
        engine?.stop()
        engine = nil
    }

    func setSoundOn(_ on: Bool) {
        lock.lock(); masterTarget = on ? Self.volume : 0; lock.unlock()
    }

    func startBreeze() {
        lock.lock(); breezeTarget = 1; lock.unlock()
    }

    func stopBreeze() {
        lock.lock(); breezeTarget = 0; lock.unlock()
    }

    /// Soft water-drop "bloop" when a light is caught.
    func bloop(pitch: Float, delay: Double = 0, volume: Float = 0.32) {
        add(Voice(kind: .tone, delay: samples(delay), length: samples(0.16), attack: samples(0.008),
                  volume: volume, f0: 240 * pitch, f1: 600 * pitch, sweep: samples(0.08)))
    }

    /// Leafy rustle, like a flower pushing up through the grass.
    func rustle(delay: Double = 0, volume: Float = 0.5, duration: Double = 0.6, frequency: Float = 2400) {
        add(Voice(kind: .rustle, delay: samples(delay), length: samples(duration), attack: samples(duration * 0.25),
                  volume: volume, f0: frequency * 0.6, f1: frequency, sweep: samples(duration)))
    }

    /// A little bird: a few quick upward tweets.
    func chirp(delay: Double = 0) {
        let base = Float.random(in: 2600...4000)
        for i in 0..<Int.random(in: 2...4) {
            let when = delay + Double(i) * Double.random(in: 0.09...0.13)
            add(Voice(kind: .tone, delay: samples(when), length: samples(0.07), attack: samples(0.01),
                      volume: 0.05, f0: base, f1: base * 1.45, sweep: samples(0.05)))
        }
    }

    // MARK: - Synthesis

    private struct Voice {
        enum Kind { case tone, rustle }
        let kind: Kind
        var delay: Int
        let length: Int
        let attack: Int
        let volume: Float
        let f0: Float
        let f1: Float
        let sweep: Int
        var t = 0
        var phase: Float = 0
        var decay: Float = 1
        var brown: Float = 0
        // band-pass filter state for rustles
        var b0: Float = 0, a1: Float = 0, a2: Float = 0
        var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0

        var done: Bool { t >= length }
    }

    private func samples(_ seconds: Double) -> Int { max(1, Int(seconds * sampleRate)) }

    private func add(_ voice: Voice) {
        lock.lock()
        if voices.count < 48 { voices.append(voice) }
        lock.unlock()
    }

    private func noise() -> Float {
        seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    private func render(into out: UnsafeMutablePointer<Float>, count: Int) {
        lock.lock(); defer { lock.unlock() }
        let sr = Float(sampleRate)

        for i in 0..<count {
            var s: Float = 0
            for v in voices.indices where !voices[v].done {
                s += next(&voices[v], sr: sr)
            }

            // gentle breeze: brown noise through a slowly moving low-pass filter
            if breezeLevel < breezeTarget {
                breezeLevel = min(breezeTarget, breezeLevel + 1 / (3 * sr))
            } else {
                breezeLevel += (breezeTarget - breezeLevel) / (0.4 * sr)
            }
            if breezeLevel > 0.0001 {
                lfoPhase += 2 * .pi * 0.07 / sr
                if lfoPhase > 2 * .pi { lfoPhase -= 2 * .pi }
                let lfo = sin(lfoPhase)
                breezeBrown = (breezeBrown + 0.02 * noise()) / 1.02
                let cutoff = 420 + 180 * lfo
                breezeLow += (1 - exp(-2 * .pi * cutoff / sr)) * (breezeBrown * 3.5 - breezeLow)
                s += breezeLow * breezeLevel * (0.14 + 0.06 * lfo)
            }

            master += (masterTarget - master) / (0.1 * sr)
            out[i] = s * master
        }
        voices.removeAll { $0.done }
    }

    private func next(_ v: inout Voice, sr: Float) -> Float {
        if v.delay > 0 { v.delay -= 1; return 0 }
        defer { v.t += 1 }

        // envelope: quick linear attack, then an exponential fade to silence
        let env: Float
        if v.t < v.attack {
            env = v.volume * Float(v.t) / Float(v.attack)
        } else {
            if v.t == v.attack { v.decay = 1 }
            v.decay *= pow(0.0001, 1 / Float(max(1, v.length - v.attack)))
            env = v.volume * v.decay
        }
        let progress = min(1, Float(v.t) / Float(v.sweep))

        switch v.kind {
        case .tone:
            let f = v.f0 * pow(v.f1 / v.f0, progress)
            v.phase += 2 * .pi * f / sr
            if v.phase > 2 * .pi { v.phase -= 2 * .pi }
            return sin(v.phase) * env

        case .rustle:
            if v.t % 64 == 0 {
                let f = v.f0 + (v.f1 - v.f0) * progress
                let w = 2 * .pi * f / sr
                let alpha = sin(w) / (2 * 0.7)
                let a0 = 1 + alpha
                v.b0 = alpha / a0
                v.a1 = -2 * cos(w) / a0
                v.a2 = (1 - alpha) / a0
            }
            v.brown = (v.brown + 0.02 * noise()) / 1.02
            let x = v.brown * 3.5
            let y = v.b0 * x - v.b0 * v.x2 - v.a1 * v.y1 - v.a2 * v.y2
            v.x2 = v.x1; v.x1 = x
            v.y2 = v.y1; v.y1 = y
            return y * env
        }
    }
}
