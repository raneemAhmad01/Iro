import SwiftUI

extension MemoryGame {
    /// Calm and simple: a white table, off-white cards (the little flame friend on every back), black text.
    enum Palette {
        static let table = Color.white
        static let face = hex(0xFAF6EF)
        static let ink = hex(0x111111)
        static let inkSoft = hex(0x6E6E73)
        static let accent = hex(0x111111)
        static let chip = hex(0xFAF6EF)
    }

    /// A plain white table.
    struct TableBackground: View {
        var body: some View {
            Palette.table
        }
    }

    /// The pictures for this level in a row; each lights up when its pair is found.
    struct FoundRow: View {
        let pieces: [Piece]
        let found: Set<Piece>

        var body: some View {
            HStack(spacing: 10) {
                ForEach(pieces) { piece in
                    let got = found.contains(piece)
                    Image(piece.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .saturation(got ? 1 : 0)
                        .opacity(got ? 1 : 0.35)
                        .scaleEffect(got ? 1.1 : 1)
                        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: got)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Palette.chip))
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        }
    }
}
