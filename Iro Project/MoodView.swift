import SwiftUI

// MARK: - Tabs
enum AppTab: String, CaseIterable, Identifiable {
    case timer  = "Timer"
    case mood   = "Mood"
    case streak = "Streak"

    var id: String { rawValue }
}

// MARK: - Mood Model
enum Mood: String, CaseIterable, Identifiable {
    case distraction = "Distraction"
    case stress      = "Stress"
    case boredom     = "Boredom"
    case anxious     = "Anxious"
    case indolence   = "Indolence"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .distraction: return Color(red: 0.66, green: 0.71, blue: 0.98)
        case .stress:      return Color(red: 0.52, green: 0.72, blue: 0.93)
        case .boredom:     return Color(red: 0.98, green: 0.86, blue: 0.48)
        case .anxious:     return Color(red: 0.73, green: 0.79, blue: 0.42)
        case .indolence:   return Color(red: 0.96, green: 0.57, blue: 0.30)
        }
    }

    var cheek: Color {
        switch self {
        case .distraction: return Color(red: 1.00, green: 0.55, blue: 0.80)
        case .stress:      return Color(red: 0.75, green: 0.85, blue: 1.00)
        case .boredom:     return Color(red: 1.00, green: 0.78, blue: 0.35)
        case .anxious:     return Color(red: 0.85, green: 0.92, blue: 0.55)
        case .indolence:   return Color(red: 1.00, green: 0.50, blue: 0.35)
        }
    }

    /// ألوان السائل المتحرك داخل الزجاج
    var glowColors: [Color] {
        switch self {
        case .distraction:
            return [Color(red: 0.66, green: 0.71, blue: 0.98),
                    Color(red: 1.00, green: 0.55, blue: 0.80),
                    Color(red: 0.55, green: 0.88, blue: 0.98),
                    Color(red: 0.80, green: 0.65, blue: 1.00)]
        case .stress:
            return [Color(red: 0.52, green: 0.72, blue: 0.93),
                    Color(red: 0.75, green: 0.85, blue: 1.00),
                    Color(red: 0.45, green: 0.85, blue: 0.85),
                    Color(red: 0.45, green: 0.55, blue: 0.95)]
        case .boredom:
            return [Color(red: 0.98, green: 0.86, blue: 0.48),
                    Color(red: 1.00, green: 0.78, blue: 0.35),
                    Color(red: 1.00, green: 0.70, blue: 0.60),
                    Color(red: 0.95, green: 0.95, blue: 0.60)]
        case .anxious:
            return [Color(red: 0.73, green: 0.79, blue: 0.42),
                    Color(red: 0.85, green: 0.92, blue: 0.55),
                    Color(red: 0.55, green: 0.85, blue: 0.60),
                    Color(red: 0.95, green: 0.95, blue: 0.55)]
        case .indolence:
            return [Color(red: 0.96, green: 0.57, blue: 0.30),
                    Color(red: 1.00, green: 0.50, blue: 0.35),
                    Color(red: 1.00, green: 0.70, blue: 0.65),
                    Color(red: 1.00, green: 0.80, blue: 0.45)]
        }
    }

    var blobPoints: [CGPoint] {
        switch self {
        case .distraction:
            return Mood.pts([(0.50, 0.02), (0.85, 0.15), (0.98, 0.52), (0.82, 0.90),
                             (0.48, 0.98), (0.14, 0.86), (0.02, 0.50), (0.16, 0.16)])
        case .stress:
            return Mood.pts([(0.45, 0.00), (0.86, 0.10), (1.00, 0.50), (0.88, 0.92),
                             (0.52, 1.00), (0.12, 0.90), (0.00, 0.52), (0.12, 0.12)])
        case .boredom:
            return Mood.pts([(0.55, 0.00), (0.90, 0.18), (1.00, 0.55), (0.84, 0.92),
                             (0.46, 1.00), (0.10, 0.86), (0.00, 0.46), (0.18, 0.12)])
        case .anxious:
            return Mood.pts([(0.40, 0.00), (0.80, 0.08), (1.00, 0.45), (0.92, 0.90),
                             (0.56, 1.00), (0.16, 0.92), (0.00, 0.55), (0.08, 0.15)])
        case .indolence:
            return Mood.pts([(0.48, 0.00), (0.88, 0.14), (1.00, 0.55), (0.84, 0.94),
                             (0.46, 1.00), (0.10, 0.84), (0.00, 0.46), (0.14, 0.14)])
        }
    }

    private static func pts(_ values: [(CGFloat, CGFloat)]) -> [CGPoint] {
        values.map { CGPoint(x: $0.0, y: $0.1) }
    }
}

// MARK: - BlobShape
struct BlobShape: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        let pts = points.map {
            CGPoint(x: rect.minX + $0.x * rect.width,
                    y: rect.minY + $0.y * rect.height)
        }
        let n = pts.count
        var path = Path()
        guard n > 3 else { return path }

        path.move(to: pts[0])
        for i in 0..<n {
            let p0 = pts[(i - 1 + n) % n]
            let p1 = pts[i]
            let p2 = pts[(i + 1) % n]
            let p3 = pts[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                             y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                             y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - AnimatedLiquid (الألوان المتحركة داخل الزجاج)
struct AnimatedLiquid: View {
    let colors: [Color]
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                (colors.first ?? Color.blue).opacity(0.55)

                ForEach(0..<colors.count, id: \.self) { i in
                    orb(index: i, time: t)
                }
            }
        }
    }

    private func orb(index: Int, time: TimeInterval) -> some View {
        let i = CGFloat(index)
        let t = CGFloat(time)
        let speed: CGFloat = 0.45 + i * 0.17
        let phase: CGFloat = i * 1.7
        let dx: CGFloat = cos(t * speed + phase) * size.width * 0.28
        let dy: CGFloat = sin(t * speed * 1.3 + phase) * size.height * 0.28
        let d: CGFloat = size.width * (0.55 + 0.08 * i)

        return Circle()
            .fill(colors[index])
            .frame(width: d, height: d)
            .offset(x: dx, y: dy)
            .blur(radius: 22)
    }
}

// MARK: - GlassBlob (الجسم الزجاجي)
struct GlassBlob: View {
    let mood: Mood
    let size: CGSize

    var body: some View {
        let w = size.width
        let h = size.height
        let bw = w * 0.68
        let bh = h * 0.68
        let shape = BlobShape(points: mood.blobPoints)

        ZStack {
            // ظل ملوّن ناعم تحت الزجاجة
            shape
                .fill(mood.color.opacity(0.35))
                .frame(width: bw, height: bh)
                .blur(radius: 18)
                .offset(y: h * 0.06)

            // السائل المتحرك داخل الزجاج
            AnimatedLiquid(colors: mood.glowColors,
                           size: CGSize(width: bw, height: bh))
                .frame(width: bw, height: bh)
                .clipShape(shape)

            // طبقة الزجاج (شفافة مع لمعان)
            shape
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.40),
                                 Color.white.opacity(0.04),
                                 Color.white.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: bw, height: bh)

            // توهج داخلي على الحافة
            shape
                .stroke(Color.white.opacity(0.55), lineWidth: 8)
                .frame(width: bw, height: bh)
                .blur(radius: 6)
                .clipShape(shape)

            // حدّ الزجاج
            shape
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95),
                                 Color.white.opacity(0.10),
                                 Color.white.opacity(0.60)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .frame(width: bw, height: bh)

            // انعكاس كبير فوق يسار
            Ellipse()
                .fill(Color.white.opacity(0.65))
                .frame(width: bw * 0.30, height: bh * 0.12)
                .rotationEffect(.degrees(-28))
                .blur(radius: 5)
                .offset(x: -bw * 0.20, y: -bh * 0.33)

            // لمعة صغيرة
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: bw * 0.045, height: bw * 0.045)
                .offset(x: -bw * 0.03, y: -bh * 0.37)

            // انعكاس خفيف تحت يمين
            Ellipse()
                .fill(Color.white.opacity(0.28))
                .frame(width: bw * 0.26, height: bh * 0.07)
                .rotationEffect(.degrees(-20))
                .blur(radius: 4)
                .offset(x: bw * 0.18, y: bh * 0.34)
        }
        .frame(width: w, height: h)
    }
}

// MARK: - MoodFace
struct MoodFace: View {
    let mood: Mood

    private let ink = Color(white: 0.30).opacity(0.85)

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                GlassBlob(mood: mood, size: geo.size)

                Circle()
                    .fill(mood.cheek.opacity(0.50))
                    .frame(width: w * 0.10, height: w * 0.10)
                    .blur(radius: 4)
                    .position(x: w * 0.33, y: h * 0.58)

                Circle()
                    .fill(mood.cheek.opacity(0.50))
                    .frame(width: w * 0.10, height: w * 0.10)
                    .blur(radius: 4)
                    .position(x: w * 0.67, y: h * 0.58)

                features(w: w, h: h)
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: Features
    @ViewBuilder
    private func features(w: CGFloat, h: CGFloat) -> some View {
        switch mood {
        case .distraction: distractionFace(w: w, h: h)
        case .stress:      stressFace(w: w, h: h)
        case .boredom:     boredomFace(w: w, h: h)
        case .anxious:     anxiousFace(w: w, h: h)
        case .indolence:   indolenceFace(w: w, h: h)
        }
    }

    private func distractionFace(w: CGFloat, h: CGFloat) -> some View {
        let questionColor = Color(red: 0.35, green: 0.45, blue: 0.88)

        return ZStack {
            dotEyes(w: w, h: h, y: 0.52)

            Ellipse()
                .fill(ink)
                .frame(width: w * 0.04, height: w * 0.03)
                .position(x: w * 0.51, y: h * 0.62)

            Text("?")
                .font(.system(size: w * 0.30, weight: .light, design: .rounded))
                .foregroundStyle(questionColor)
                .rotationEffect(.degrees(-12))
                .position(x: w * 0.22, y: h * 0.32)

            Text("?")
                .font(.system(size: w * 0.14, weight: .light, design: .rounded))
                .foregroundStyle(questionColor.opacity(0.8))
                .rotationEffect(.degrees(8))
                .position(x: w * 0.40, y: h * 0.22)
        }
    }

    private func stressFace(w: CGFloat, h: CGFloat) -> some View {
        let eyeXs: [CGFloat] = [0.38, 0.62]

        return ZStack {
            // شرارة
            Path { p in
                let c = CGPoint(x: w * 0.17, y: h * 0.24)
                for i in 0..<8 {
                    let a: CGFloat = CGFloat(i) * .pi / 4
                    let r1: CGFloat = w * 0.025
                    let r2: CGFloat = (i % 2 == 0) ? w * 0.085 : w * 0.050
                    p.move(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
                    p.addLine(to: CGPoint(x: c.x + cos(a) * r2, y: c.y + sin(a) * r2))
                }
            }
            .stroke(Color(red: 0.20, green: 0.40, blue: 0.80),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // العيون
            Path { p in
                for x in eyeXs {
                    p.move(to: CGPoint(x: w * (x - 0.05), y: h * 0.50))
                    p.addQuadCurve(to: CGPoint(x: w * (x + 0.05), y: h * 0.50),
                                   control: CGPoint(x: w * x, y: h * 0.46))
                }
            }
            .stroke(ink, style: stroke)

            // الفم المتعرج
            Path { p in
                let startX: CGFloat = w * 0.43
                let endX: CGFloat = w * 0.57
                let y: CGFloat = h * 0.63
                let steps = 4
                let step: CGFloat = (endX - startX) / CGFloat(steps)

                p.move(to: CGPoint(x: startX, y: y))
                for i in 0..<steps {
                    let x0: CGFloat = startX + step * CGFloat(i)
                    let up: CGFloat = (i % 2 == 0) ? -h * 0.025 : h * 0.025
                    p.addQuadCurve(to: CGPoint(x: x0 + step, y: y),
                                   control: CGPoint(x: x0 + step / 2, y: y + up))
                }
            }
            .stroke(ink, style: stroke)
        }
    }

    private func boredomFace(w: CGFloat, h: CGFloat) -> some View {
        let eyeXs: [CGFloat] = [0.38, 0.62]

        return ZStack {
            // عيون 😑 (خطين أفقيين مستقيمين)
            Path { p in
                for x in eyeXs {
                    p.move(to: CGPoint(x: w * (x - 0.055), y: h * 0.50))
                    p.addLine(to: CGPoint(x: w * (x + 0.055), y: h * 0.50))
                }
            }
            .stroke(ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // فم مستقيم
            Path { p in
                p.move(to: CGPoint(x: w * 0.46, y: h * 0.63))
                p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.63))
            }
            .stroke(ink, style: stroke)
        }
    }

    private func anxiousFace(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // الخربشة
            Path { p in
                let c = CGPoint(x: w * 0.23, y: h * 0.25)
                let radius: CGFloat = w * 0.10
                let count = 160

                for i in 0...count {
                    let t: CGFloat = CGFloat(i) / CGFloat(count)
                    let angle: CGFloat = t * .pi * 9
                    let wave: CGFloat = sin(t * .pi * 7 + 1.0)
                    let r: CGFloat = radius * (0.55 + 0.45 * wave)
                    let px: CGFloat = c.x + cos(angle) * r * 1.1
                    let py: CGFloat = c.y + sin(angle * 1.1) * r
                    let pt = CGPoint(x: px, y: py)

                    if i == 0 {
                        p.move(to: pt)
                    } else {
                        p.addLine(to: pt)
                    }
                }
            }
            .stroke(Color(red: 0.55, green: 0.62, blue: 0.25).opacity(0.85),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

            dotEyes(w: w, h: h, y: 0.54)

            Path { p in
                p.move(to: CGPoint(x: w * 0.34, y: h * 0.46))
                p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.43))
                p.move(to: CGPoint(x: w * 0.66, y: h * 0.46))
                p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.43))
            }
            .stroke(ink.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            Path { p in
                p.move(to: CGPoint(x: w * 0.44, y: h * 0.66))
                p.addQuadCurve(to: CGPoint(x: w * 0.56, y: h * 0.66),
                               control: CGPoint(x: w * 0.50, y: h * 0.61))
            }
            .stroke(ink, style: stroke)
        }
    }

    private func indolenceFace(w: CGFloat, h: CGFloat) -> some View {
        let eyeXs: [CGFloat] = [0.40, 0.62]

        return ZStack {
            zShape(x: w * 0.10, y: h * 0.20, size: w * 0.11)
            zShape(x: w * 0.20, y: h * 0.08, size: w * 0.075)

            Path { p in
                for x in eyeXs {
                    p.move(to: CGPoint(x: w * (x - 0.045), y: h * 0.50))
                    p.addQuadCurve(to: CGPoint(x: w * (x + 0.045), y: h * 0.50),
                                   control: CGPoint(x: w * x, y: h * 0.545))
                }
            }
            .stroke(ink, style: stroke)

            Ellipse()
                .fill(Color.white.opacity(0.95))
                .frame(width: w * 0.12, height: h * 0.08)
                .overlay(Ellipse().stroke(ink.opacity(0.35), lineWidth: 1))
                .position(x: w * 0.47, y: h * 0.64)
        }
    }

    // MARK: Helpers
    private func dotEyes(w: CGFloat, h: CGFloat, y: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(ink)
                .frame(width: w * 0.035, height: w * 0.05)
                .position(x: w * 0.40, y: h * y)

            Ellipse()
                .fill(ink)
                .frame(width: w * 0.035, height: w * 0.05)
                .position(x: w * 0.62, y: h * y)
        }
    }

    private func zShape(x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x + size, y: y))
            p.addLine(to: CGPoint(x: x, y: y + size))
            p.addLine(to: CGPoint(x: x + size, y: y + size))
        }
        .stroke(Color(red: 0.80, green: 0.38, blue: 0.18),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - MoodButton
struct MoodButton: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                MoodFace(mood: mood)
                    .frame(width: 210, height: 210)

                Text(mood.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(isSelected ? mood.color.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(isSelected ? mood.color.opacity(0.7) : Color.clear,
                            lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - TopTabBar
struct TopTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selection = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selection == tab ? Color.blue : Color.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background {
                            if selection == tab {
                                Capsule()
                                    .fill(Color.gray.opacity(0.18))
                                    .matchedGeometryEffect(id: "selectedPill", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

// MARK: - MoodPage
struct MoodPage: View {
    @State private var selectedMood: Mood? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Mood")
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 80)
                .padding(.leading, 70)

            VStack(alignment: .leading, spacing: 8) {
                Text("How are you feeling today?")
                    .font(.system(size: 40, weight: .semibold))

                Text("Choose the feeling that closest matches your state right now.")
                    .font(.system(size: 25, weight: .light))
            }
            .padding(.leading, 60)
            .padding(.top, 40)

            Spacer()

            VStack(spacing: 30) {
                HStack(spacing: 60) {
                    moodButton(.distraction)
                    moodButton(.stress)
                    moodButton(.boredom)
                }
                HStack(spacing: 60) {
                    moodButton(.anxious)
                    moodButton(.indolence)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }

    private func moodButton(_ mood: Mood) -> some View {
        MoodButton(mood: mood, isSelected: selectedMood == mood) {
            selectedMood = mood
        }
    }
}

// MARK: - AppBackground
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color.white

            RadialGradient(
                colors: [
                    Color(red: 0.75, green: 0.82, blue: 1.0).opacity(0.85),
                    Color(red: 0.90, green: 0.94, blue: 1.0).opacity(0.5),
                    Color.white.opacity(0)
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 820
            )

            RadialGradient(
                colors: [
                    Color(red: 0.88, green: 0.94, blue: 0.76).opacity(1.0),
                    Color.white.opacity(0)
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 180
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - MoodView
struct MoodView: View {
    @State private var selectedTab: AppTab = .mood

    var body: some View {
        ZStack {
            AppBackground()

            Group {
                switch selectedTab {
                case .timer:
                    Text("Timer").font(.largeTitle.bold())
                case .mood:
                    MoodPage()
                case .streak:
                    Text("Streak").font(.largeTitle.bold())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .top) {
            TopTabBar(selection: $selectedTab)
                .padding(.top, 20)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    MoodView()
}
