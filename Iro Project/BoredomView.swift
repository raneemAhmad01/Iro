//
//  BoredomView.swift
//  Iro Project
//
//  Created by Ghada Abdulaziz on 11/05/1448 AH.
//

import SwiftUI

struct BoredomView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Petal Drift mini game; its X button returns to the page that opened this one
        PetalDriftGameView(onClose: { dismiss() })
            .statusBarHidden()
            .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    BoredomView()
}
