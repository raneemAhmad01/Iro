import SwiftUI
import UIKit

extension MemoryGame {
    enum Piece: String, CaseIterable, Identifiable {
        // Easy: fruits
        case orange, watermelon, strawberry, cherry
        // Medium: shapes
        case fish, pudding, croissant, star, sun, cat, bunny, leaf

        var id: String { rawValue }
        var name: String { rawValue.capitalized }
        /// Image in MemoryGameImages.xcassets.
        var imageName: String { "mg-\(rawValue)" }
    }

    enum Level: String, CaseIterable, Identifiable {
        case easy, medium

        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var pieces: [Piece] {
            switch self {
            case .easy: [.orange, .watermelon, .strawberry, .cherry]
            case .medium: [.fish, .pudding, .croissant, .star, .sun, .cat, .bunny, .leaf]
            }
        }
        var cardCount: Int { pieces.count * 2 }
        var hints: Int { self == .easy ? 2 : 3 }
        /// How long every card stays face up at the start so the player can memorize them.
        var previewSeconds: Double { self == .easy ? 3 : 5 }
    }

    struct Card: Identifiable {
        let id = UUID()
        let piece: Piece
        /// Small hand-placed tilt so the cards look laid out by hand.
        let tilt: Double
        var isFaceUp = false
        var isMatched = false
        var isHinted = false
        var wiggles = 0
    }

    @MainActor
    @Observable
    final class Game {
        let level: Level
        private(set) var cards: [Card] = []
        private(set) var moves = 0
        private(set) var hintsLeft = 0
        private(set) var startDate: Date?
        private(set) var finishTime: TimeInterval?
        /// True while all cards are shown face up at the start of a round.
        private(set) var isPreviewing = false
        /// When the memorize preview ends and the cards flip over.
        private(set) var previewEnds: Date?

        private var openIDs: [UUID] = []
        private var locked = false
        /// Bumped on every new round so delayed work from an old round is ignored.
        private var round = 0

        var isWon: Bool { finishTime != nil }
        var foundPieces: Set<Piece> { Set(cards.filter(\.isMatched).map(\.piece)) }
        var canHint: Bool { hintsLeft > 0 && !isWon && !isPreviewing }

        var note: String {
            let pairs = level.pieces.count
            if moves <= pairs + 2 { return "Sharp eyes. Hardly a wasted look." }
            if moves <= pairs * 2 { return "A sweet, tidy round." }
            return "All found. Try for fewer moves?"
        }

        init(level: Level) {
            self.level = level
            newGame()
        }

        func newGame() {
            round += 1
            cards = (level.pieces + level.pieces).shuffled().map {
                Card(piece: $0, tilt: .random(in: -1.5...1.5), isFaceUp: true)
            }
            moves = 0
            hintsLeft = level.hints
            startDate = nil
            finishTime = nil
            openIDs = []

            // Show every card face up for a moment, then flip them all over and start play.
            locked = true
            isPreviewing = true
            previewEnds = Date.now.addingTimeInterval(level.previewSeconds)
            let current = round
            Task {
                try? await Task.sleep(for: .seconds(level.previewSeconds))
                guard current == round else { return }
                for i in cards.indices { cards[i].isFaceUp = false }
                Haptics.flip()
                isPreviewing = false
                previewEnds = nil
                try? await Task.sleep(for: .milliseconds(450))
                guard current == round else { return }
                locked = false
            }
        }

        func elapsed(at date: Date) -> TimeInterval {
            if let finishTime { return finishTime }
            guard let startDate else { return 0 }
            return date.timeIntervalSince(startDate)
        }

        func tap(_ id: UUID) {
            guard !locked, let i = index(of: id), !cards[i].isFaceUp, !cards[i].isMatched else { return }
            if startDate == nil { startDate = .now }
            cards[i].isFaceUp = true
            Haptics.flip()
            openIDs.append(id)
            guard openIDs.count == 2 else { return }

            moves += 1
            let pair = openIDs
            openIDs = []
            locked = true
            let current = round
            let isMatch = cards[index(of: pair[0])!].piece == cards[index(of: pair[1])!].piece

            Task {
                if isMatch {
                    try? await Task.sleep(for: .milliseconds(380))
                    guard current == round else { return }
                    update(pair) { $0.isMatched = true }
                    Haptics.match()
                    locked = false
                    if cards.allSatisfy(\.isMatched) {
                        let time = elapsed(at: .now)
                        try? await Task.sleep(for: .milliseconds(800))
                        guard current == round else { return }
                        finishTime = time
                        Haptics.win()
                    }
                } else {
                    try? await Task.sleep(for: .milliseconds(600))
                    guard current == round else { return }
                    update(pair) { $0.wiggles += 1 }
                    Haptics.miss()
                    try? await Task.sleep(for: .milliseconds(600))
                    guard current == round else { return }
                    update(pair) { $0.isFaceUp = false }
                    locked = false
                }
            }
        }

        /// Briefly shows one pair that hasn't been found yet.
        /// If one card is already open, the hint shows its partner.
        func useHint() {
            guard !locked, canHint else { return }
            let openPiece = openIDs.first.flatMap(index(of:)).map { cards[$0].piece }
            guard let piece = openPiece ?? cards.first(where: { !$0.isMatched && !$0.isFaceUp })?.piece else { return }
            let ids = cards.filter { $0.piece == piece && !$0.isMatched && !$0.isFaceUp }.map(\.id)

            hintsLeft -= 1
            locked = true
            let current = round
            update(ids) { $0.isHinted = true }
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard current == round else { return }
                update(ids) { $0.isFaceUp = true }
                try? await Task.sleep(for: .milliseconds(1300))
                guard current == round else { return }
                update(ids) { $0.isFaceUp = false; $0.isHinted = false }
                locked = false
            }
        }

        private func index(of id: UUID) -> Int? { cards.firstIndex { $0.id == id } }

        private func update(_ ids: [UUID], _ change: (inout Card) -> Void) {
            for id in ids { if let i = index(of: id) { change(&cards[i]) } }
        }
    }

    enum Haptics {
        static func flip() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        static func match() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        static func miss() { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6) }
        static func win() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }
}
