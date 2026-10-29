//
//  TimerView.swift
//  Iro Project
//
//  Created by RaneemAhmad on 11/05/1448 AH.
//

//
//  TimerView.swift
//  Focus Timer — SwiftUI (iPad / iOS 17+، وLiquid Glass على iOS 26 مع Xcode 26)
//

//
//  TimerView.swift
//  Focus Timer — SwiftUI (iPad / iOS 17+، وLiquid Glass على iOS 26 مع Xcode 26)
//

import SwiftUI
import Combine
import AVFoundation
import AudioToolbox
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Colors

extension Color {
    static let focusOrange = Color(red: 0.96, green: 0.45, blue: 0.05)
    static let glowBlue = Color(red: 0.40, green: 0.64, blue: 0.98)
    static let glowYellow = Color(red: 0.98, green: 0.95, blue: 0.50)
    static let glowGreen = Color(red: 0.50, green: 0.84, blue: 0.76)
    static let glowPeach = Color(red: 1.00, green: 0.74, blue: 0.46)
    static let glowLilac = Color(red: 0.68, green: 0.72, blue: 0.98)
}

// MARK: - Haptics

@MainActor
enum Haptics {
    static func tick() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}

// MARK: - Glass helper

struct GlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular.tint(tint), in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(shape.fill(.ultraThinMaterial))
            .background(shape.fill(tint ?? Color.clear))
            .overlay(shape.stroke(Color.white.opacity(0.55), lineWidth: 0.8))
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func glass<S: Shape>(_ shape: S, tint: Color? = nil) -> some View {
        modifier(GlassModifier(shape: shape, tint: tint))
    }
}

struct SheetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
        } else {
            content.presentationBackground(.ultraThinMaterial)
        }
    }
}

// MARK: - Model

enum TimerPhase {
    case idle
    case focus
    case rest
}

struct TimerSegment {
    let phase: TimerPhase
    let seconds: Int
}

@MainActor
final class FocusTimerModel: ObservableObject {

    // الإعدادات
    @Published var focusMinutes: Int = 45
    @Published var breakMinutes: Int = 10

    // الحالة
    @Published var phase: TimerPhase = .idle
    @Published var remaining: Int = 0
    @Published var segmentTotal: Int = 1
    @Published var isRunning: Bool = false
    @Published var justFinished: Bool = false
    @Published var session: Int = 1
    @Published var focusDone: Bool = false   // تشيك التركيز
    @Published var breakDone: Bool = false   // تشيك البريك

    @Published var totalSessions: Int = 10   // مجموع الجلسات (يختاره المستخدم)

    private var segments: [TimerSegment] = []
    private var segmentIndex: Int = 0
    private var endDate: Date?
    private var ticker: Timer?
    private var player: AVAudioPlayer?

    // MARK: Texts

    var title: String {
        switch phase {
        case .idle:
            return justFinished ? "Session complete" : "it's Rio time let's begin....."
        case .focus:
            return "Focus started"
        case .rest:
            return "Break started"
        }
    }

    var subtitle: String {
        switch phase {
        case .idle:
            return justFinished ? "Great work, take a moment." : "Stay focus and trust the process."
        case .focus:
            return "Stay focus and trust the process."
        case .rest:
            return "Relax, breathe and recharge."
        }
    }

    var timeString: String {
        let minutes: Int = remaining / 60
        let seconds: Int = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        if segmentTotal <= 0 { return 0 }
        return 1.0 - Double(remaining) / Double(segmentTotal)
    }

    // كم تشيك انجز من اثنين (التركيز + البريك)
    var completedCount: Int {
        return (focusDone ? 1 : 0) + (breakDone ? 1 : 0)
    }

    // الوقت الكلي لإنهاء كل الجلسات (التركيز + البريك لكل جلسة)
    var totalMinutes: Int {
        return totalSessions * (focusMinutes + breakMinutes)
    }

    var totalTimeString: String {
        return FocusTimerModel.formatTime(minutes: totalMinutes)
    }

    // تنسيق الدقائق إلى ساعات ودقائق (مثل 2h 45m)
    static func formatTime(minutes total: Int) -> String {
        let hours: Int = total / 60
        let minutes: Int = total % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var presetName: String {
        if focusMinutes == 25 && breakMinutes == 5 { return "Pomodoro" }
        if focusMinutes == 45 && breakMinutes == 10 { return "Study Cycle" }
        return "Custom"
    }

    // MARK: Schedule
    // الجلسة = وقت التركيز ثم البريك

    private func buildSegments() -> [TimerSegment] {
        let focus = TimerSegment(phase: .focus, seconds: focusMinutes * 60)
        let rest = TimerSegment(phase: .rest, seconds: breakMinutes * 60)
        return [focus, rest]
    }

    // MARK: Controls

    func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func start() {
        justFinished = false
        if phase == .idle {
            focusDone = false
            breakDone = false
            segments = buildSegments()
            segmentIndex = 0
            beginSegment()
        } else {
            endDate = Date().addingTimeInterval(TimeInterval(remaining))
        }
        isRunning = true
        startTicker()
    }

    func pause() {
        if let endDate = endDate {
            remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        }
        isRunning = false
        stopTicker()
    }

    func reset() {
        stopTicker()
        isRunning = false
        phase = .idle
        remaining = 0
        segmentTotal = 1
        endDate = nil
        justFinished = false
        focusDone = false
        breakDone = false
    }

    func apply(focus: Int, rest: Int, sessions: Int) {
        focusMinutes = focus
        breakMinutes = rest
        totalSessions = max(1, sessions)
        session = min(session, totalSessions)
        reset()
    }

    // MARK: Internals

    private func beginSegment() {
        let segment: TimerSegment = segments[segmentIndex]
        phase = segment.phase
        remaining = segment.seconds
        segmentTotal = segment.seconds
        endDate = Date().addingTimeInterval(TimeInterval(segment.seconds))
        if segment.phase == .rest {
            playBell()
        }
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let model = self else { return }
            Task { @MainActor in
                model.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard isRunning, let endDate = endDate else { return }
        let left: Int = Int(ceil(endDate.timeIntervalSinceNow))
        if left > 0 {
            if left != remaining {
                remaining = left
            }
        } else {
            advance()
        }
    }

    private func markCompleted(_ finished: TimerPhase) {
        switch finished {
        case .focus:
            focusDone = true
        case .rest:
            breakDone = true
        case .idle:
            break
        }
    }

    private func advance() {
        markCompleted(segments[segmentIndex].phase)
        segmentIndex += 1
        if segmentIndex < segments.count {
            beginSegment()
        } else {
            finishSession()
        }
    }

    private func finishSession() {
        stopTicker()
        isRunning = false
        phase = .idle
        remaining = 0
        endDate = nil
        justFinished = true
        if session < totalSessions {
            session += 1
        } else {
            session = 1
        }
        playBell()
    }

    // MARK: Sound
    // إذا حطيت ملف bell.mp3 أو bell.wav داخل المشروع (مع Target Membership) يستخدمه،
    // وإذا ما لقاه يستخدم النغمة المولّدة (ثلاث نغمات صاعدة هادئة).

    private func playBell() {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? audioSession.setActive(true)
        #endif

        var newPlayer: AVAudioPlayer? = nil

        var url: URL? = Bundle.main.url(forResource: "bell", withExtension: "mp3")
        if url == nil {
            url = Bundle.main.url(forResource: "bell", withExtension: "wav")
        }
        if let url = url {
            newPlayer = try? AVAudioPlayer(contentsOf: url)
        }
        if newPlayer == nil {
            newPlayer = try? AVAudioPlayer(data: FocusTimerModel.chimeWavData)
        }

        if let newPlayer = newPlayer {
            player = newPlayer
            newPlayer.volume = 1.0
            newPlayer.prepareToPlay()
            newPlayer.play()
        }

        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    // نغمة هادئة: ثلاث نغمات صاعدة (صول، سي، مي) مع تلاشي ناعم
    private static let chimeWavData: Data = {
        let sampleRate: Double = 44100
        let duration: Double = 3.2
        let frameCount: Int = Int(sampleRate * duration)

        let frequencies: [Double] = [783.99, 987.77, 1318.51]
        let starts: [Double] = [0.0, 0.24, 0.48]
        let twoPi: Double = 2.0 * Double.pi

        var samples = [Int16](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let t: Double = Double(i) / sampleRate
            var value: Double = 0
            for n in 0..<frequencies.count {
                let local: Double = t - starts[n]
                if local >= 0 {
                    let f: Double = frequencies[n]
                    let attack: Double = min(1.0, local / 0.004)
                    let envelope: Double = exp(-2.2 * local) * attack
                    let fundamental: Double = sin(twoPi * f * local)
                    let overtone: Double = 0.30 * sin(twoPi * 2.0 * f * local) * exp(-3.0 * local)
                    let shimmer: Double = 0.10 * sin(twoPi * 3.0 * f * local) * exp(-5.0 * local)
                    value += (fundamental + overtone + shimmer) * envelope
                }
            }
            value = value * 0.24
            let clipped: Double = max(-1.0, min(1.0, value))
            samples[i] = Int16(clipped * 32767.0)
        }

        let dataSize: UInt32 = UInt32(frameCount * 2)
        var bytes = [UInt8]()

        func put32(_ v: UInt32) {
            bytes.append(UInt8(v & 0xFF))
            bytes.append(UInt8((v >> 8) & 0xFF))
            bytes.append(UInt8((v >> 16) & 0xFF))
            bytes.append(UInt8((v >> 24) & 0xFF))
        }
        func put16(_ v: UInt16) {
            bytes.append(UInt8(v & 0xFF))
            bytes.append(UInt8((v >> 8) & 0xFF))
        }

        bytes.append(contentsOf: Array("RIFF".utf8))
        put32(36 + dataSize)
        bytes.append(contentsOf: Array("WAVE".utf8))
        bytes.append(contentsOf: Array("fmt ".utf8))
        put32(16)
        put16(1)                         // PCM
        put16(1)                         // mono
        put32(UInt32(sampleRate))
        put32(UInt32(sampleRate) * 2)
        put16(2)
        put16(16)
        bytes.append(contentsOf: Array("data".utf8))
        put32(dataSize)

        for sample in samples {
            put16(UInt16(bitPattern: sample))
        }
        return Data(bytes)
    }()
}

// MARK: - Glowing glass background

struct GlowBlob: View {
    let color: Color
    let size: CGFloat
    let opacity: Double
    let opacityEnd: Double
    let start: CGSize
    let end: CGSize
    let scaleStart: CGFloat
    let scaleEnd: CGFloat
    let moved: Bool

    var body: some View {
        let offsetX: CGFloat = moved ? end.width : start.width
        let offsetY: CGFloat = moved ? end.height : start.height
        let scale: CGFloat = moved ? scaleEnd : scaleStart
        let currentOpacity: Double = moved ? opacityEnd : opacity

        return Circle()
            .fill(color.opacity(currentOpacity))
            .frame(width: size, height: size)
            .blur(radius: 80)
            .scaleEffect(scale)
            .offset(x: offsetX, y: offsetY)
    }
}

struct GlowBackground: View {
    let active: Bool
    @State private var drift: Bool = false

    var body: some View {
        Color(white: 0.93)
            .overlay { blobs }
            .overlay { halo }
            .overlay { Rectangle().fill(.ultraThinMaterial).opacity(0.28) }
            .clipped()
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
    }

    // هالة مضيئة في وسط الشاشة (خلف التايمر) تنبض بهدوء
    private var halo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color.glowYellow.opacity(0.60),
                        Color.glowYellow.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 340
                )
            )
            .frame(width: 720, height: 720)
            .scaleEffect(drift ? 1.18 : 0.86)
            .opacity(active ? 1.0 : 0.70)
            .animation(.easeInOut(duration: 0.8), value: active)
    }

    private var blobs: some View {
        ZStack {
            GlowBlob(color: .glowBlue, size: 660, opacity: 0.55, opacityEnd: 0.85,
                     start: CGSize(width: 20, height: -190),
                     end: CGSize(width: 150, height: -260),
                     scaleStart: 0.92, scaleEnd: 1.12, moved: drift)

            GlowBlob(color: .glowYellow, size: 480, opacity: 0.60, opacityEnd: 0.90,
                     start: CGSize(width: 30, height: 40),
                     end: CGSize(width: -30, height: 100),
                     scaleStart: 1.10, scaleEnd: 0.94, moved: drift)

            GlowBlob(color: .glowGreen, size: 440, opacity: 0.45, opacityEnd: 0.75,
                     start: CGSize(width: -180, height: 220),
                     end: CGSize(width: -280, height: 140),
                     scaleStart: 0.90, scaleEnd: 1.08, moved: drift)

            GlowBlob(color: .glowPeach, size: 400, opacity: 0.30, opacityEnd: 0.60,
                     start: CGSize(width: -380, height: 100),
                     end: CGSize(width: -450, height: 10),
                     scaleStart: 1.08, scaleEnd: 0.92, moved: drift)

            GlowBlob(color: .glowLilac, size: 480, opacity: 0.40, opacityEnd: 0.70,
                     start: CGSize(width: 430, height: 250),
                     end: CGSize(width: 350, height: 330),
                     scaleStart: 0.92, scaleEnd: 1.08, moved: drift)
        }
    }
}

// MARK: - Top tabs

enum TimerTab: String, CaseIterable, Identifiable {
    case timer = "Timer"
    case mood = "Mood"
    case streak = "Streak"

    var id: String { rawValue }
}

struct TopTabs: View {
    @Binding var selection: TimerTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimerTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .glass(Capsule())
    }

    private func tabButton(_ tab: TimerTab) -> some View {
        let isSelected: Bool = (selection == tab)
        return Button {
            withAnimation(.snappy) {
                selection = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isSelected ? Color.blue : Color.primary)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(isSelected ? Color.black.opacity(0.07) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timer dial

struct TimerDial: View {
    @ObservedObject var model: FocusTimerModel
    @State private var breathe: Bool = false
    @State private var glow: Bool = false

    var body: some View {
        ZStack {
            // توهج ينبض خلف الدائرة الزجاجية
            Circle()
                .fill(Color.glowYellow)
                .frame(width: 340, height: 340)
                .blur(radius: 55)
                .opacity(glow ? 0.95 : 0.45)
                .scaleEffect(glow ? 1.30 : 1.02)

            Color.clear
                .frame(width: 360, height: 360)
                .glass(Circle(), tint: Color.glowYellow.opacity(0.35))

            if model.phase != .idle {
                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(Color.focusOrange.opacity(0.85),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 336, height: 336)
                    .animation(.linear(duration: 0.3), value: model.progress)
            }

            Text(model.timeString)
                .font(.system(size: 84, weight: .medium))
                .monospacedDigit()
        }
        .scaleEffect(breathe ? 1.025 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .onChange(of: model.isRunning) { _, running in
            if running {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    breathe = false
                }
            }
        }
    }
}

// MARK: - Focus session card

struct FocusSessionCard: View {
    @ObservedObject var model: FocusTimerModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text("Focus Session")
                    .font(.system(size: 24, weight: .semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text("Total time . \(model.totalTimeString)")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)

            HStack(spacing: 26) {
                CheckItem(title: "Focus", done: model.focusDone)
                CheckItem(title: "Break", done: model.breakDone)
            }
            .padding(.vertical, 6)

            Text("Session \(model.session) of \(model.totalSessions)")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)

            dots
        }
        .padding(24)
        .frame(width: 330)
        .glass(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }

    private var dots: some View {
        HStack(spacing: 10) {
            ForEach(1...model.totalSessions, id: \.self) { index in
                Circle()
                    .fill(index <= model.session ? Color.primary : Color.secondary.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Hold-to-repeat button (ضغطة مطولة تتسارع)

struct HoldStepButton: View {
    let systemName: String
    let onStep: () -> Void

    @State private var isPressed: Bool = false
    @State private var holdTask: Task<Void, Never>? = nil

    var body: some View {
        Image(systemName: systemName)
            .frame(width: 56, height: 42)
            .contentShape(Rectangle())
            .opacity(isPressed ? 0.45 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginPress() }
                    .onEnded { _ in endPress() }
            )
            .onDisappear { endPress() }
    }

    private func step() {
        Haptics.tick()
        onStep()
    }

    private func beginPress() {
        if isPressed { return }
        isPressed = true
        step()

        holdTask = Task { @MainActor in
            // انتظار قصير قبل ما يبدأ التكرار
            try? await Task.sleep(nanoseconds: 380_000_000)
            var delay: Double = 0.14
            while !Task.isCancelled {
                step()
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                // كل خطوة أسرع من اللي قبلها
                delay = max(0.02, delay * 0.90)
            }
        }
    }

    private func endPress() {
        isPressed = false
        holdTask?.cancel()
        holdTask = nil
    }
}

// MARK: - Edit sheet

struct SettingRow: View {
    let title: String
    let value: String
    let onMinus: () -> Void
    let onPlus: () -> Void
    var caption: String? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 22))
                if let caption = caption {
                    Text(caption)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.15), value: caption)
                }
            }
            .frame(width: 170, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 22, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: value)
            Spacer()
            stepper
        }
        .frame(height: 72)
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            HoldStepButton(systemName: "minus", onStep: onMinus)

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1, height: 20)

            HoldStepButton(systemName: "plus", onStep: onPlus)
        }
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(Color.primary)
        .glass(Capsule())
    }
}

struct PresetPill: View {
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                Text(detail)
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .glass(RoundedRectangle(cornerRadius: 40, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EditSheet: View {
    @ObservedObject var model: FocusTimerModel
    @Environment(\.dismiss) private var dismiss

    @State private var focus: Int
    @State private var rest: Int
    @State private var sessions: Int

    init(model: FocusTimerModel) {
        self.model = model
        _focus = State(initialValue: model.focusMinutes)
        _rest = State(initialValue: model.breakMinutes)
        _sessions = State(initialValue: model.totalSessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            header

            Text("Edit Stady time")
                .font(.system(size: 28, weight: .semibold))
                .padding(.leading, 12)

            rows

            Text("Suggestions")
                .font(.system(size: 28, weight: .semibold))
                .padding(.leading, 12)

            suggestions

            Spacer(minLength: 0)
        }
        .padding(28)
        .presentationDetents([.height(720), .large])
        .presentationDragIndicator(.visible)
        .modifier(SheetBackgroundModifier())
    }

    // MARK: Steps (كل الأرقام، خطوة = 1)

    private func decreaseFocus() {
        focus = max(1, focus - 1)
    }

    private func increaseFocus() {
        focus = min(240, focus + 1)
    }

    private func decreaseRest() {
        rest = max(1, rest - 1)
    }

    private func increaseRest() {
        rest = min(60, rest + 1)
    }

    private func decreaseSessions() {
        sessions = max(1, sessions - 1)
    }

    private func increaseSessions() {
        sessions = min(10, sessions + 1)
    }

    // MARK: Parts

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .frame(width: 54, height: 54)
                    .glass(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                model.apply(focus: focus, rest: rest, sessions: sessions)
                dismiss()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.focusOrange))
            }
            .buttonStyle(.plain)
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            SettingRow(
                title: "Study Time",
                value: "\(focus) Min",
                onMinus: { decreaseFocus() },
                onPlus: { increaseFocus() }
            )

            Divider()

            SettingRow(
                title: "Break Time",
                value: "\(rest) Min",
                onMinus: { decreaseRest() },
                onPlus: { increaseRest() }
            )

            Divider()

            SettingRow(
                title: "Sessions",
                value: "\(sessions)",
                onMinus: { decreaseSessions() },
                onPlus: { increaseSessions() },
                caption: "Total time . \(FocusTimerModel.formatTime(minutes: sessions * (focus + rest)))"
            )

        }
        .padding(.horizontal, 30)
        .glass(RoundedRectangle(cornerRadius: 40, style: .continuous))
    }

    private var suggestions: some View {
        HStack(spacing: 18) {
            PresetPill(title: "Pomodoro Technique", detail: "25/5", action: {
                withAnimation(.snappy) {
                    focus = 25
                    rest = 5
                }
            })

            PresetPill(title: "Study Cycle", detail: "45/10", action: {
                withAnimation(.snappy) {
                    focus = 45
                    rest = 10
                }
            })
        }
    }
}

// MARK: - Control icon (أيقونة برتقالية بدون إطار ولا لمعة)

struct GlassIcon: View {
    let systemName: String
    let size: CGFloat
    let weight: Font.Weight

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(Color.focusOrange)
    }
}

// أنيميشن الضغط: الزر ينكمش ثم يرجع بنطّة خفيفة
struct PressBounceStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.80 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

// MARK: - Check item (تشيك الإنجاز داخل كرت Focus Session)

struct CheckItem: View {
    let title: String
    let done: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.focusOrange)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.secondary.opacity(0.55))
                        .transition(.opacity)
                }
            }
            .frame(width: 28, height: 28)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: done)

            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(done ? Color.primary : Color.secondary)
        }
    }
}

// MARK: - Main screen

struct TimerView: View {
    @StateObject private var model = FocusTimerModel()
    @State private var tab: TimerTab = .timer
    @State private var showCard: Bool = true
    @State private var showEdit: Bool = false
    @State private var resetTurns: Double = 0

    var body: some View {
        ZStack {
            GlowBackground(active: model.isRunning)
            pageContent
        }
        .overlay(alignment: .top) { tabsOverlay }
        .overlay(alignment: .topTrailing) { sideOverlay }
        .sheet(isPresented: $showEdit) {
            EditSheet(model: model)
        }
        .onChange(of: model.phase) { _, newPhase in
            if newPhase == .focus { showCard = true }
        }
        .onChange(of: model.focusDone) { _, done in
            if done { showCard = true }
        }
        .onChange(of: model.breakDone) { _, done in
            if done { showCard = true }
        }
    }

    // MARK: Pages

    @ViewBuilder
    private var pageContent: some View {
        if tab == .timer {
            timerPage
        } else if tab == .mood {
            placeholder("Mood")
        } else {
            placeholder("Streak")
        }
    }

    // التايمر في نص الشاشة بالضبط، والأزرار تحته
    private var timerPage: some View {
        ZStack {
            headerTexts

            TimerDial(model: model)

            controls
                .offset(y: 245)
        }
    }

    private var headerTexts: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 114)

            VStack(alignment: .leading, spacing: 10) {
                Text(model.title)
                    .font(.system(size: 46, weight: .semibold))
                Text(model.subtitle)
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
            }
            .id(model.title)
            .transition(.opacity)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 60)
        .padding(.top, 80)
        .animation(.easeInOut(duration: 0.35), value: model.title)
    }

    // أزرار بدون إطار: أيقونات قزاز مع أنيميشن بسيط
    private var controls: some View {
        HStack(spacing: 48) {
            Button {
                withAnimation(.easeInOut(duration: 0.5)) {
                    resetTurns -= 360
                }
                model.reset()
            } label: {
                GlassIcon(systemName: "arrow.counterclockwise", size: 28, weight: .medium)
                    .rotationEffect(.degrees(resetTurns))
                    .padding(8)
                    .contentShape(Rectangle())
            }

            Button {
                model.toggle()
            } label: {
                ZStack {
                    GlassIcon(systemName: model.isRunning ? "pause.fill" : "play.fill",
                              size: 56, weight: .regular)
                        .id(model.isRunning)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: model.isRunning)
                .padding(8)
                .contentShape(Rectangle())
            }

            Button {
                showEdit = true
            } label: {
                GlassIcon(systemName: "slider.horizontal.3", size: 28, weight: .medium)
                    .padding(8)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(PressBounceStyle())
    }

    private func placeholder(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 44, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    // MARK: Overlays

    private var tabsOverlay: some View {
        TopTabs(selection: $tab)
            .padding(.top, 20)
    }

    // الزر اللي فوق يمين: يظهر ويخفي كرت Focus Session
    private var gridButton: some View {
        Button {
            showCard.toggle()
        } label: {
            Image(systemName: "circle.grid.2x2")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(width: 64, height: 64)
                .glass(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sideOverlay: some View {
        if tab == .timer {
            VStack(alignment: .trailing, spacing: 28) {
                gridButton
                if showCard {
                    FocusSessionCard(model: model, onClose: { showCard = false })
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.trailing, 28)
            .padding(.top, 80)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showCard)
        }
    }
}

#Preview {
    TimerView()
}
