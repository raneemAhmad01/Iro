import SwiftUI

// MARK: - Adding this game to your app
//
// 1. Drag the whole `MemoryGame` folder into your Xcode project ("Copy items if needed", add to your app target).
//    It includes its own pictures (MemoryGameImages.xcassets). Needs iOS 17 or later, nothing else.
// 2. On the page where your button is:
//
//        @State private var showGame = false
//
//        Button("Play") { showGame = true }
//            .fullScreenCover(isPresented: $showGame) {
//                MemoryGameView { result in
//                    // optional: save a score, give a reward…
//                    print(result.level, result.moves, result.seconds)
//                }
//            }
//
//    The game opens on the level screen (Easy / Medium). The ✕ button closes it and returns to your page.
//    It also works when pushed inside a NavigationStack.
// 3. Everything else lives inside the `MemoryGame` namespace, so it won't clash with names in your app.

/// The memory matching mini game: pick Easy (8 cards) or Medium (16 cards), then find the pairs.
struct MemoryGameView: View {
    /// Called each time the player finds every pair.
    var onComplete: ((MemoryGame.Result) -> Void)? = nil
    /// Hide the ✕ button if your app provides its own way back.
    var showsCloseButton = true

    @Environment(\.dismiss) private var dismiss
    @State private var game: MemoryGame.Game?

    var body: some View {
        let close: (() -> Void)? = showsCloseButton ? { dismiss() } : nil
        ZStack {
            MemoryGame.TableBackground().ignoresSafeArea()
            if let game {
                MemoryGame.Board(game: game, onLevels: { self.game = nil }, onClose: close)
                    .id(ObjectIdentifier(game))
                    .transition(.opacity)
                    .onChange(of: game.isWon) { _, won in
                        if won {
                            onComplete?(MemoryGame.Result(level: game.level, moves: game.moves, seconds: game.finishTime ?? 0))
                        }
                    }
            } else {
                MemoryGame.LevelPicker(onPick: { game = MemoryGame.Game(level: $0) }, onClose: close)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: game.map(ObjectIdentifier.init))
        .statusBarHidden()
        .navigationBarBackButtonHidden(showsCloseButton)
    }
}

/// Namespace for everything the game uses internally.
enum MemoryGame {
    struct Result {
        let level: Level
        let moves: Int
        let seconds: TimeInterval
    }

    static func hex(_ value: UInt32, _ opacity: Double = 1) -> Color {
        Color(.sRGB,
              red: Double((value >> 16) & 0xFF) / 255,
              green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255,
              opacity: opacity)
    }

    static func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Level picker

extension MemoryGame {
    struct LevelPicker: View {
        let onPick: (Level) -> Void
        let onClose: (() -> Void)?

        var body: some View {
            VStack(spacing: 34) {
                Text("Choose a level")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)

                HStack(spacing: 40) {
                    ForEach(Array(Level.allCases.enumerated()), id: \.element) { i, level in
                        Button { onPick(level) } label: {
                            LevelTile(level: level)
                        }
                        .buttonStyle(PressStyle())
                        .rotationEffect(.degrees(i == 0 ? -2 : 2))
                        .accessibilityLabel("\(level.title), \(level.cardCount) cards")
                    }
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if let onClose {
                    RoundIcon(systemName: "xmark", action: onClose)
                        .accessibilityLabel("Close game")
                        .padding(24)
                }
            }
        }
    }

    private struct LevelTile: View {
        let level: Level

        var body: some View {
            let columns = level == .easy ? 2 : 4
            VStack(spacing: 0) {
                Text(level.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 22)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(level == .easy ? 78 : 50), spacing: 8), count: columns), spacing: 8) {
                    ForEach(level.pieces) { piece in
                        Image(piece.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: level == .easy ? 78 : 50)
                    }
                }
                .frame(height: 170)
                Text("\(level.cardCount) cards")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.bottom, 18)
            }
            .frame(width: 260)
            .background(Palette.face)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
        }
    }
}

// MARK: - Board

extension MemoryGame {
    struct Board: View {
        let game: Game
        let onLevels: () -> Void
        let onClose: (() -> Void)?

        /// Picks the column count that gives the biggest cards in the space available.
        private func layout(in size: CGSize, count: Int) -> (columns: Int, cardWidth: CGFloat, gap: CGFloat) {
            var best = (columns: 4, cardWidth: CGFloat(0), gap: CGFloat(12))
            for columns in 2...8 where count % columns == 0 {
                let rows = count / columns
                let gap = max(10, min(size.width, size.height) * 0.025)
                let byWidth = (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
                let byHeight = (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows) * 3 / 4
                let w = min(byWidth, byHeight, 210)
                if w > best.cardWidth { best = (columns, w, gap) }
            }
            return best
        }

        var body: some View {
            GeometryReader { geo in
                let area = CGSize(width: geo.size.width - 48, height: geo.size.height - 190)
                let grid = layout(in: area, count: game.cards.count)
                let rows = game.cards.count / grid.columns

                VStack(spacing: max(16, geo.size.height * 0.03)) {
                    Header(game: game, onLevels: onLevels, onClose: onClose)
                        .padding(.horizontal, 24)

                    VStack(spacing: grid.gap) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: grid.gap) {
                                ForEach(Array(game.cards[(row * grid.columns)..<((row + 1) * grid.columns)].enumerated()), id: \.element.id) { offset, card in
                                    Button { game.tap(card.id) } label: {
                                        CardView(card: card)
                                    }
                                    .buttonStyle(PressStyle())
                                    .frame(width: grid.cardWidth, height: grid.cardWidth * 4 / 3)
                                    .modifier(DealIn(delay: Double(row * grid.columns + offset) * 0.045))
                                }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)

                    Group {
                        if game.isPreviewing, let ends = game.previewEnds {
                            MemorizeCountdown(ends: ends)
                        } else {
                            FoundRow(pieces: game.level.pieces, found: game.foundPieces)
                                .accessibilityElement()
                                .accessibilityLabel("\(game.foundPieces.count) of \(game.level.pieces.count) pairs found")
                        }
                    }
                    .frame(height: 52)
                    .animation(.easeInOut(duration: 0.3), value: game.isPreviewing)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlay {
                if game.isWon {
                    WinSheet(game: game, onLevels: onLevels, onClose: onClose)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.35), value: game.isWon)
        }
    }

    private struct Header: View {
        let game: Game
        let onLevels: () -> Void
        let onClose: (() -> Void)?

        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                if let onClose {
                    RoundIcon(systemName: "xmark", action: onClose)
                        .accessibilityLabel("Close game")
                }
                Button(action: onLevels) {
                    Label(game.level.title, systemImage: "chevron.left")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 18)
                        .frame(height: 52)
                        .background(Capsule().fill(Palette.chip))
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Back to levels")

                Spacer(minLength: 12)

                TimelineView(.periodic(from: .now, by: 0.5)) { tl in
                    HStack(spacing: 14) {
                        Stat(value: "\(game.moves)", label: "moves")
                        Rectangle().fill(Palette.inkSoft.opacity(0.3)).frame(width: 1, height: 22)
                        Stat(value: formatTime(game.elapsed(at: tl.date)), label: "time")
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(Capsule().fill(Palette.chip))
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                }

                Spacer(minLength: 12)

                Button { game.useHint() } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "eye")
                            .font(.system(size: 19, weight: .semibold))
                        HStack(spacing: 3) {
                            ForEach(0..<game.level.hints, id: \.self) { i in
                                Circle()
                                    .fill(i < game.hintsLeft ? Palette.accent : Palette.inkSoft.opacity(0.25))
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Palette.chip))
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                }
                .buttonStyle(PressStyle())
                .disabled(!game.canHint)
                .opacity(game.canHint ? 1 : 0.55)
                .accessibilityLabel("Peek at a pair, \(game.hintsLeft) left")

                RoundIcon(systemName: "arrow.counterclockwise") { game.newGame() }
                    .accessibilityLabel("Shuffle and start again")
            }
        }
    }

    /// "Memorize the cards" with the seconds left before they flip over.
    private struct MemorizeCountdown: View {
        let ends: Date

        var body: some View {
            TimelineView(.periodic(from: .now, by: 0.2)) { tl in
                let left = max(1, Int(ceil(ends.timeIntervalSince(tl.date))))
                HStack(spacing: 10) {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(Palette.accent)
                    Text("Memorize the cards")
                        .foregroundStyle(Palette.ink)
                    Text("\(left)")
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Palette.accent))
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: left)
                }
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .padding(.leading, 18)
                .padding(.trailing, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(Palette.chip))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Memorize the cards, \(left) seconds left")
            }
        }
    }

    struct RoundIcon: View {
        let systemName: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Palette.chip))
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
            }
            .buttonStyle(PressStyle())
        }
    }

    private struct Stat: View {
        let value: String
        let label: String

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private struct WinSheet: View {
        let game: Game
        let onLevels: () -> Void
        let onClose: (() -> Void)?
        @State private var shown = false

        var body: some View {
            let size: CGFloat = game.level == .easy ? 64 : 46
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()

                VStack(spacing: 0) {
                    Text("All pairs found!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        ForEach(Array(game.level.pieces.enumerated()), id: \.element) { i, piece in
                            Image(piece.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: size, height: size)
                                .scaleEffect(shown ? 1 : 0.3)
                                .opacity(shown ? 1 : 0)
                                .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.2 + Double(i) * 0.07), value: shown)
                        }
                    }
                    .padding(.vertical, 18)

                    Text("\(game.moves) moves · \(formatTime(game.finishTime ?? 0))")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    Text(game.note)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.top, 4)
                        .padding(.bottom, 24)

                    HStack(spacing: 12) {
                        Button(action: onLevels) {
                            Text("Levels")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 13)
                                .background(Capsule().strokeBorder(Palette.inkSoft.opacity(0.4), lineWidth: 1.5))
                        }
                        .buttonStyle(PressStyle())
                        Button { game.newGame() } label: {
                            Text("Play again")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 13)
                                .background(Capsule().fill(Palette.accent))
                        }
                        .buttonStyle(PressStyle())
                    }
                    if let onClose {
                        Button("Done", action: onClose)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.inkSoft)
                            .padding(.top, 14)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 30)
                .padding(.bottom, 26)
                .frame(maxWidth: 520)
                .background(Palette.face)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .compositingGroup()
                .shadow(color: .black.opacity(0.3), radius: 24, y: 14)
                .scaleEffect(shown ? 1 : 0.9)
                .opacity(shown ? 1 : 0)
                .padding(.horizontal, 16)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { shown = true }
            }
        }
    }

    struct PressStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }

    /// Cards settle onto the table one after another when a round starts.
    private struct DealIn: ViewModifier {
        let delay: Double
        @State private var dealt = false

        func body(content: Content) -> some View {
            content
                .opacity(dealt ? 1 : 0)
                .offset(y: dealt ? 0 : 18)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.45).delay(delay)) { dealt = true }
                }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    MemoryGameView(showsCloseButton: false)
}
