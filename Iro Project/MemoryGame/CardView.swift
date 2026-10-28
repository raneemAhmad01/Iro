import SwiftUI

extension MemoryGame {
    struct CardView: View {
        let card: Card

        private var faceUp: Bool { card.isFaceUp || card.isMatched }

        var body: some View {
            GeometryReader { geo in
                let radius = geo.size.width * 0.09
                FlipView(angle: faceUp ? 180 : 0,
                         front: CardFront(piece: card.piece, matched: card.isMatched, radius: radius),
                         back: CardBack(hinted: card.isHinted, radius: radius))
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.14), radius: 6, x: 1, y: 4)
            }
            .modifier(Wiggle(animatableData: CGFloat(card.wiggles)))
            .rotationEffect(.degrees(card.tilt))
            .animation(.spring(response: 0.6, dampingFraction: 0.78), value: faceUp)
            .animation(.easeInOut(duration: 0.5), value: card.wiggles)
            .animation(.easeOut(duration: 0.3), value: card.isHinted)
            .accessibilityElement()
            .accessibilityLabel(faceUp ? card.piece.name : "Hidden card")
            .accessibilityAddTraits(.isButton)
        }
    }

    /// Lifts the card a little while it turns, and swaps sides at the halfway point.
    struct FlipView<Front: View, Back: View>: View, Animatable {
        var angle: Double
        let front: Front
        let back: Back

        var animatableData: Double {
            get { angle }
            set { angle = newValue }
        }

        var body: some View {
            ZStack {
                back.opacity(angle < 90 ? 1 : 0)
                front
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(angle >= 90 ? 1 : 0)
            }
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
            .scaleEffect(1 + 0.06 * sin(angle * .pi / 180))
        }
    }

    /// A soft side-to-side tilt for a pair that doesn't match.
    struct Wiggle: GeometryEffect {
        var animatableData: CGFloat
        func effectValue(size: CGSize) -> ProjectionTransform {
            let angle = 0.05 * sin(animatableData * .pi * 3)
            let t = CGAffineTransform(translationX: size.width / 2, y: size.height)
                .rotated(by: angle)
                .translatedBy(x: -size.width / 2, y: -size.height)
            return ProjectionTransform(t)
        }
    }

    struct CardFront: View {
        let piece: Piece
        let matched: Bool
        let radius: CGFloat

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack {
                    shape.fill(Palette.face)
                    Image(piece.imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(w * 0.1)
                    if matched {
                        Image(systemName: "heart.fill")
                            .font(.system(size: w * 0.08, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: w * 0.17, height: w * 0.17)
                            .background(Circle().fill(Palette.accent))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(w * 0.06)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: matched)
            }
            .clipShape(shape)
        }
    }

    struct CardBack: View {
        let hinted: Bool
        let radius: CGFloat

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            GeometryReader { geo in
                ZStack {
                    Palette.face
                    // the little flame character in the middle of every card back
                    Image("mg-cover")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * 0.62)
                }
            }
                .clipShape(shape)
                .overlay(shape.strokeBorder(hex(0xFFE58A), lineWidth: hinted ? 5 : 0))
                .shadow(color: hex(0xFFE58A).opacity(hinted ? 0.9 : 0), radius: 12)
        }
    }
}
