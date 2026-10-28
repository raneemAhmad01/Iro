//
//  PetalDriftGame.swift
//  Iro Project
//

import SwiftUI
import UIKit

/// Petal Drift: tap the falling lights to grow a garden. Calm, with no way to lose.
/// A session lasts `PetalDriftWorld.sessionLength` of play, then the game ends with a "time to rest" card.
/// Stop pauses and shows the start card again; X calls `onClose` so the host page can go back.
struct PetalDriftGameView: View {
    var onClose: () -> Void = {}

    @State private var world = PetalDriftWorld()
    @State private var total = UserDefaults.standard.integer(forKey: PetalDriftWorld.totalKey)
    @State private var soundOn = UserDefaults.standard.object(forKey: PetalDriftWorld.soundKey) as? Bool ?? true
    @State private var showCard = true
    @State private var hasStarted = false
    @State private var finished = false
    @State private var sessionBlooms = 0
    @State private var toast: String?
    @State private var toastID = 0
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    private static let messages = [
        "Your garden is waking up",
        "So peaceful here",
        "A butterfly came to visit",
        "Everything is blooming",
        "Breathe in, breathe out",
        "What a lovely garden",
    ]

    var body: some View {
        ZStack {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    world.update(now: timeline.date, size: size)
                    world.draw(in: &context, size: size)
                }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { tap(at: $0.location) })
            .blur(radius: showCard ? 6 : 0)

            VStack(spacing: 12) {
                hud
                if let toast {
                    Text(toast)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(PD.ink)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(.white.opacity(0.7), in: Capsule())
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .id(toastID)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if showCard {
                card.transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .background(PD.rgb(253, 227, 236).ignoresSafeArea())
        .task {
            // ends the session once the play time runs out
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                if !finished && world.remaining <= 0 { finish() }
            }
        }
        .onDisappear { world.stop(); world.sounds.shutdown() }
    }

    // MARK: - Pieces

    private var hud: some View {
        HStack(spacing: 10) {
            pill { Text("🌸 \(total)") }
            pill {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Label(Self.clock(world.remaining), systemImage: "hourglass")
                }
            }
            .accessibilityLabel("Time left")
            Spacer()
            HStack(spacing: 10) {
                roundButton(soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                            label: soundOn ? "Mute sound" : "Turn sound on", action: toggleSound)
                    .opacity(soundOn ? 1 : 0.6)
                roundButton("stop.fill", label: "Stop game", action: stop)
                    .opacity(finished ? 0.4 : 1)
                roundButton("xmark", label: "Close game", action: close)
            }
        }
    }

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.system(.headline, design: .rounded).monospacedDigit())
            .foregroundStyle(PD.ink)
            .padding(.horizontal, 14).frame(height: 44)
            .background(.white.opacity(0.6), in: Capsule())
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private var card: some View {
        VStack(spacing: 12) {
            Text(finished ? "🌙" : "🌷 🌸 🌼").font(.title2)
            Text(finished ? "Time to rest" : "Petal Drift")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(PD.ink)
            Text(finished
                 ? "\(sessionBlooms == 0 ? "Your garden is resting too." : "You grew \(sessionBlooms) \(sessionBlooms == 1 ? "flower" : "flowers") today.")\nTake one slow breath before you go."
                 : "Little lights are falling from the sky.\nTap them to grow a garden.\nThere's no rush, and nothing to lose.")
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundStyle(PD.ink.opacity(0.7))
            Button(action: finished ? close : begin) {
                Text(finished ? "Done" : hasStarted ? "Continue" : "Begin")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36).padding(.vertical, 14)
                    .background(LinearGradient(colors: [PD.rgb(247, 161, 201), PD.rgb(201, 167, 255)],
                                               startPoint: .leading, endPoint: .trailing), in: Capsule())
                    .shadow(color: PD.rgb(201, 167, 255).opacity(0.5), radius: 12, y: 6)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(maxWidth: 340)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: PD.rgb(200, 150, 190).opacity(0.25), radius: 30, y: 12)
        .padding(24)
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PD.ink)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.6), in: Circle())
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .accessibilityLabel(label)
    }

    private static func clock(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Actions

    private func begin() {
        guard !finished else { return }
        world.start()
        hasStarted = true
        withAnimation(.easeInOut(duration: 0.6)) { showCard = false }
    }

    private func stop() {
        guard world.running else { return }
        world.stop()
        withAnimation(.easeInOut(duration: 0.6)) { showCard = true }
    }

    /// Time is up: the lights dissolve, a bird sings goodbye and the "time to rest" card appears.
    private func finish() {
        finished = true
        world.stop()
        world.sounds.chirp()
        withAnimation(.easeInOut(duration: 1.2)) { showCard = true }
    }

    private func close() {
        world.stop()
        onClose()
    }

    private func toggleSound() {
        soundOn.toggle()
        UserDefaults.standard.set(soundOn, forKey: PetalDriftWorld.soundKey)
        world.sounds.start()
        world.sounds.setSoundOn(soundOn)
    }

    private func tap(at point: CGPoint) {
        guard !showCard, world.tap(at: point) else { return }
        total += 1
        sessionBlooms += 1
        UserDefaults.standard.set(total, forKey: PetalDriftWorld.totalKey)
        haptic.impactOccurred(intensity: 0.5)
        if total % 10 == 0 {
            world.spawnButterfly()
            world.sounds.chirp()
            world.sounds.chirp(delay: 0.5)
            showToast(Self.messages[(total / 10 - 1) % Self.messages.count])
        }
    }

    private func showToast(_ message: String) {
        toastID += 1
        let id = toastID
        withAnimation(.easeOut(duration: 0.4)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            if toastID == id { withAnimation(.easeIn(duration: 0.6)) { toast = nil } }
        }
    }
}

// MARK: - Colors

private enum PD {
    static let ink = rgb(91, 74, 107)

    static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255).opacity(a)
    }

    typealias RGB = (r: Double, g: Double, b: Double)

    // Soft pastel palette; each color makes a slightly different water-drop sound
    static let palette: [(rgb: RGB, pitch: Float)] = [
        ((255, 158, 199), 0.85), // pink
        ((255, 199, 138), 0.92), // peach
        ((255, 226, 122), 1.00), // butter
        ((155, 227, 180), 1.08), // mint
        ((159, 211, 255), 1.16), // sky
        ((201, 167, 255), 1.25), // lilac
    ]

    // Sky keyframes (top, bottom) that slowly blend into each other
    static let skies: [(RGB, RGB)] = [
        ((255, 214, 231), (255, 239, 220)), // blush morning
        ((205, 232, 255), (255, 236, 245)), // soft day
        ((214, 200, 255), (255, 214, 226)), // lavender dusk
        ((176, 214, 230), (232, 222, 255)), // misty teal
    ]

    static func color(_ c: RGB, _ a: Double = 1) -> Color { rgb(c.r, c.g, c.b, a) }

    static func mix(_ a: RGB, _ b: RGB, _ t: Double) -> Color {
        rgb(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }
}

// MARK: - World

/// Everything moving on screen. Updated and drawn once per frame by the Canvas.
final class PetalDriftWorld {
    static let totalKey = "petaldrift.total"
    static let soundKey = "petaldrift.sound"
    /// How long one session of play lasts: a short, calm break of 3 minutes.
    static let sessionLength: TimeInterval = 3 * 60
    private static let skySeconds = 40.0
    private static let maxFlowers = 45

    let sounds: PetalDriftSounds
    private(set) var running = false
    /// Seconds actually played; pausing with Stop doesn't use up the session.
    private(set) var playTime = 0.0
    var remaining: Double { max(0, Self.sessionLength - playTime) }

    private struct Orb { var x, y, r, vy, phase, sway: Double; var idx: Int; var dead = false; var fade = 1.0 }
    private struct Flower { var x: Double; var idx: Int; var h, size: Double; var petals: Int; var lean: Double
                            var grow = 0.0; var phase: Double; var fade = 1.0; var fading = false }
    private struct Sparkle { var x, y, vx, vy, r: Double; var color: PD.RGB; var life = 1.0 }
    private struct Butterfly { var x, y, dir, t, phase: Double; var idx: Int }
    private struct Dust { var x, y, r, p: Double }
    private struct Cloud { var x, y, s, v: Double }

    private var orbs: [Orb] = []
    private var flowers: [Flower] = []
    private var sparkles: [Sparkle] = []
    private var butterflies: [Butterfly] = []
    private var dust: [Dust] = []
    private var clouds: [Cloud] = []

    private var W = 0.0, H = 0.0
    private var time = 0.0
    private var lastDate: Date?
    private var spawnTimer = 1.0
    private var lastColor = -1, streak = 0

    init() {
        let on = UserDefaults.standard.object(forKey: Self.soundKey) as? Bool ?? true
        sounds = PetalDriftSounds(soundOn: on)
    }

    // capped so lights and flowers stay a cozy size on tablets
    private var scale: Double { max(0.8, min(1.5, min(W, H) / 400)) }
    private func groundY(_ x: Double) -> Double { H * 0.84 + sin(x * 0.006) * 14 + sin(x * 0.015 + 1.3) * 6 }

    // MARK: Controls

    func start() {
        sounds.start()
        running = true
        spawnTimer = 0.3
        sounds.startBreeze()
        sounds.rustle(volume: 0.35, duration: 1.2, frequency: 1200) // a soft whoosh of air
        sounds.chirp(delay: 0.6)
    }

    func stop() {
        guard running else { return }
        running = false
        for o in orbs { burst(o.x, o.y, PD.palette[o.idx].rgb, count: 6) } // lights dissolve into sparkles
        orbs = []
        sounds.stopBreeze()
    }

    /// Returns true when a light was caught and a flower grew.
    func tap(at point: CGPoint) -> Bool {
        guard running else { return false }
        let x = point.x, y = point.y
        var hit: Int?
        var best = Double.infinity
        for (i, o) in orbs.enumerated() where !o.dead {
            let d = hypot(o.x - x, o.y - y)
            if d < o.r * 2.4 && d < best { best = d; hit = i }
        }
        guard let i = hit else {
            // a tiny shimmer even on a miss, so every tap feels nice
            burst(x, y, (255, 255, 255), count: 5)
            sounds.rustle(volume: 0.12, duration: 0.18, frequency: 3200)
            return false
        }
        orbs[i].dead = true
        let o = orbs[i], c = PD.palette[o.idx]
        streak = o.idx == lastColor ? streak + 1 : 0
        lastColor = o.idx
        burst(o.x, o.y, c.rgb, count: 18)
        sounds.bloop(pitch: c.pitch)
        if streak >= 2 {
            sounds.bloop(pitch: c.pitch * 1.2, delay: 0.11, volume: 0.22)
            sounds.bloop(pitch: c.pitch * 1.4, delay: 0.22, volume: 0.16)
        }
        sounds.rustle(delay: 0.15)
        addFlower(x: max(16, min(W - 16, o.x)), idx: o.idx, big: streak >= 2)
        return true
    }

    func spawnButterfly() {
        let fromLeft = Bool.random()
        butterflies.append(Butterfly(x: fromLeft ? -30 : W + 30, y: H * .random(in: 0.35...0.65),
                                     dir: fromLeft ? 1 : -1, t: 0, phase: .random(in: 0...10),
                                     idx: .random(in: 0..<PD.palette.count)))
    }

    // MARK: Spawning

    private func spawnOrb() {
        let s = scale
        orbs.append(Orb(x: 30 + .random(in: 0...1) * max(0, W - 60), y: -30,
                        r: .random(in: 13...20) * s,
                        vy: .random(in: 40...70) * max(0.8, H / 700),
                        phase: .random(in: 0...(2 * .pi)), sway: .random(in: 14...32),
                        idx: .random(in: 0..<PD.palette.count)))
    }

    private func addFlower(x: Double, idx: Int, big: Bool) {
        let s = scale
        flowers.append(Flower(x: x, idx: idx,
                              h: .random(in: 50...110) * s * (big ? 1.25 : 1),
                              size: .random(in: 10...15) * s * (big ? 1.3 : 1),
                              petals: .random(in: 5...7), lean: .random(in: -0.2...0.2),
                              phase: .random(in: 0...(2 * .pi))))
        // oldest flower fades away gently to make room
        let alive = flowers.indices.filter { !flowers[$0].fading }
        if alive.count > Self.maxFlowers { flowers[alive[0]].fading = true }
    }

    private func burst(_ x: Double, _ y: Double, _ color: PD.RGB, count: Int) {
        for _ in 0..<count {
            let a = Double.random(in: 0...(2 * .pi)), sp = Double.random(in: 30...120)
            sparkles.append(Sparkle(x: x, y: y, vx: cos(a) * sp, vy: sin(a) * sp - 20,
                                    r: .random(in: 1.5...4), color: color))
        }
    }

    // MARK: Update

    func update(now: Date, size: CGSize) {
        if size.width != W || size.height != H {
            W = size.width; H = size.height
            dust = (0..<Int((W * H / 14000).rounded())).map { _ in
                Dust(x: .random(in: 0...max(1, W)), y: .random(in: 0...max(1, H * 0.8)),
                     r: .random(in: 0.4...2), p: .random(in: 0...(2 * .pi)))
            }
            if clouds.isEmpty {
                clouds = (0..<4).map { i in
                    Cloud(x: .random(in: 0...max(1, W)), y: H * (0.08 + Double(i) * 0.09),
                          s: .random(in: 0.6...1.2), v: .random(in: 4...10))
                }
            }
        }
        let dt = lastDate.map { min(0.05, max(0, now.timeIntervalSince($0))) } ?? 0
        lastDate = now
        time += dt

        for i in clouds.indices {
            clouds[i].x += clouds[i].v * dt
            if clouds[i].x - 120 * clouds[i].s > W { clouds[i].x = -120 * clouds[i].s }
        }

        if running {
            playTime += dt
            spawnTimer -= dt
            if spawnTimer <= 0 { spawnOrb(); spawnTimer = .random(in: 0.9...1.8) }
            if Double.random(in: 0...1) < dt / 9 { sounds.chirp() } // a bird somewhere, every so often
        }

        for i in flowers.indices {
            flowers[i].grow = min(1, flowers[i].grow + dt * 0.9)
            if flowers[i].fading { flowers[i].fade = max(0, flowers[i].fade - dt * 0.4) }
        }
        flowers.removeAll { $0.fade <= 0 }

        for i in orbs.indices {
            orbs[i].y += orbs[i].vy * dt
            orbs[i].x += cos(time * 0.8 + orbs[i].phase) * orbs[i].sway * dt
            if orbs[i].y > groundY(orbs[i].x) - orbs[i].r { orbs[i].fade -= dt * 1.5 } // melt into the grass
        }
        orbs.removeAll { $0.dead || $0.fade <= 0 }

        for i in butterflies.indices {
            butterflies[i].t += dt
            butterflies[i].x += butterflies[i].dir * 55 * dt
            butterflies[i].y += sin(butterflies[i].t * 2.2) * 30 * dt
        }
        butterflies.removeAll { $0.x < -60 || $0.x > W + 60 }

        for i in sparkles.indices {
            sparkles[i].x += sparkles[i].vx * dt
            sparkles[i].y += sparkles[i].vy * dt
            sparkles[i].vx *= 0.96
            sparkles[i].vy = sparkles[i].vy * 0.96 + 10 * dt
            sparkles[i].life -= dt * 1.2
        }
        sparkles.removeAll { $0.life <= 0 }
    }

    // MARK: Drawing

    private func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private func ellipse(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, angle: Double = 0) -> Path {
        Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
            .applying(CGAffineTransform(translationX: x, y: y).rotated(by: angle))
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let full = Path(CGRect(origin: .zero, size: size))

        // sky
        let k = (time / Self.skySeconds).truncatingRemainder(dividingBy: Double(PD.skies.count))
        let i = Int(k), t = (1 - cos((k - Double(i)) * .pi)) / 2
        let a = PD.skies[i], b = PD.skies[(i + 1) % PD.skies.count]
        context.fill(full, with: .linearGradient(Gradient(colors: [PD.mix(a.0, b.0, t), PD.mix(a.1, b.1, t)]),
                                                 startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))

        // soft sun glow
        let sun = CGPoint(x: W * 0.78, y: H * 0.2)
        context.fill(full, with: .radialGradient(Gradient(stops: [
            .init(color: PD.rgb(255, 250, 235, 0.85), location: 0),
            .init(color: PD.rgb(255, 240, 220, 0.35), location: 0.25),
            .init(color: PD.rgb(255, 240, 220, 0), location: 1),
        ]), center: sun, startRadius: 0, endRadius: min(W, H) * 0.35))

        // clouds
        for c in clouds {
            let s = c.s * scale * 1.2
            var p = ellipse(c.x, c.y, 50 * s, 16 * s)
            p.addPath(ellipse(c.x - 26 * s, c.y + 4 * s, 28 * s, 12 * s))
            p.addPath(ellipse(c.x + 18 * s, c.y - 10 * s, 30 * s, 16 * s))
            context.fill(p, with: .color(.white.opacity(0.55)))
        }

        // floating dust
        for d in dust {
            let alpha = 0.25 + 0.35 * sin(time * 1.3 + d.p)
            context.fill(circle(d.x + sin(time * 0.3 + d.p) * 6, d.y + cos(time * 0.2 + d.p) * 4, d.r),
                         with: .color(.white.opacity(max(0, alpha))))
        }

        // hills
        var back = Path()
        back.move(to: CGPoint(x: 0, y: H))
        for x in stride(from: 0.0, through: W + 8, by: 8) {
            back.addLine(to: CGPoint(x: x, y: H * 0.76 + sin(x * 0.004 + 2) * 22))
        }
        back.addLine(to: CGPoint(x: W + 8, y: H))
        context.fill(back, with: .color(PD.rgb(190, 228, 196, 0.8)))

        var front = Path()
        front.move(to: CGPoint(x: 0, y: H))
        for x in stride(from: 0.0, through: W + 6, by: 6) { front.addLine(to: CGPoint(x: x, y: groundY(x))) }
        front.addLine(to: CGPoint(x: W + 6, y: H))
        context.fill(front, with: .linearGradient(Gradient(colors: [PD.rgb(179, 226, 176), PD.rgb(147, 207, 156)]),
                                                  startPoint: CGPoint(x: 0, y: H * 0.8), endPoint: CGPoint(x: 0, y: H)))

        for f in flowers { drawFlower(f, in: &context) }
        for o in orbs where !o.dead { drawOrb(o, in: &context) }
        for b in butterflies { drawButterfly(b, in: context) }
        for p in sparkles {
            context.fill(circle(p.x, p.y, p.r * p.life + 0.3), with: .color(PD.color(p.color, max(0, p.life))))
        }
    }

    private func drawOrb(_ o: Orb, in context: inout GraphicsContext) {
        let c = PD.palette[o.idx].rgb
        let fade = max(0, o.fade)
        let r = o.r * (1 + sin(time * 3 + o.phase) * 0.08)
        context.fill(circle(o.x, o.y, r * 2.6), with: .radialGradient(
            Gradient(colors: [PD.color(c, 0.55 * fade), PD.color(c, 0)]),
            center: CGPoint(x: o.x, y: o.y), startRadius: 0, endRadius: r * 2.6))
        context.fill(circle(o.x, o.y, r), with: .color(PD.color(c, fade)))
        context.fill(circle(o.x - r * 0.3, o.y - r * 0.3, r * 0.32), with: .color(.white.opacity(0.75 * fade)))
    }

    private func drawFlower(_ f: Flower, in context: inout GraphicsContext) {
        let ease = { (t: Double) in 1 - pow(1 - min(1, t), 3) }
        let c = PD.palette[f.idx].rgb
        let g = ease(f.grow)
        let baseY = groundY(f.x) + 4
        let sway = sin(time * 1.1 + f.phase) * 4 * scale + f.lean * f.h
        let topX = f.x + sway * g, topY = baseY - f.h * g

        var stem = Path()
        stem.move(to: CGPoint(x: f.x, y: baseY))
        stem.addQuadCurve(to: CGPoint(x: topX, y: topY), control: CGPoint(x: f.x - sway * 0.3, y: baseY - f.h * g * 0.5))
        context.stroke(stem, with: .color(PD.rgb(111, 181, 138, f.fade)),
                       style: StrokeStyle(lineWidth: max(2, 2.6 * scale), lineCap: .round))

        // a leaf
        if g > 0.4 {
            let ly = baseY - f.h * g * 0.4, lx = f.x - sway * 0.15
            let ls = f.size * 0.8 * min(1, (g - 0.4) / 0.4)
            context.fill(ellipse(lx + ls * 0.6, ly, ls, ls * 0.4, angle: -0.5), with: .color(PD.rgb(134, 201, 154, f.fade)))
        }

        // petals open after the stem has grown
        let open = ease(max(0, (f.grow - 0.5) / 0.5))
        guard open > 0 else { return }
        let ps = f.size * open
        var petals = Path()
        for i in 0..<f.petals {
            let a = Double(i) / Double(f.petals) * 2 * .pi + time * 0.15 + f.phase
            petals.addPath(ellipse(topX + cos(a) * ps * 0.75, topY + sin(a) * ps * 0.75, ps * 0.75, ps * 0.45, angle: a))
        }
        context.fill(petals, with: .color(PD.color(c, f.fade)))
        context.fill(circle(topX, topY, ps * 0.42), with: .color(PD.rgb(255, 246, 201, f.fade)))
        context.fill(circle(topX + ps * 0.08, topY + ps * 0.08, ps * 0.22), with: .color(PD.rgb(255, 190, 120, 0.6 * f.fade)))
    }

    private func drawButterfly(_ b: Butterfly, in context: GraphicsContext) {
        let s = scale * 1.1
        let flap = abs(sin(time * 9 + b.phase))
        var ctx = context
        ctx.translateBy(x: b.x, y: b.y)
        ctx.scaleBy(x: b.dir, y: 1)
        for side in [-1.0, 1.0] {
            var wing = ctx
            wing.scaleBy(x: 1, y: 0.3 + flap * 0.7)
            var p = ellipse(-3 * s, side * 8 * s, 9 * s, 7 * s, angle: side * 0.4)
            p.addPath(ellipse(5 * s, side * 6 * s, 6 * s, 5 * s, angle: -side * 0.3))
            wing.fill(p, with: .color(PD.color(PD.palette[b.idx].rgb, 0.9)))
        }
        ctx.fill(ellipse(0, 0, 7 * s, 2 * s), with: .color(PD.rgb(122, 100, 136)))
    }
}

#Preview {
    PetalDriftGameView()
}
