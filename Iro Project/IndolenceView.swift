//
//  IndolenceView.swift
//  Iro Project
//
//  Created by Ghada Abdulaziz on 11/05/1448 AH.
//

import SwiftUI

struct IndolenceView: View {
    @State private var isActive = false
    @State private var timeRemaining = 120 // 2 minutes countdown
    
    // Theme color matching your orange control buttons
    private let themeOrange = Color.orange
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 0) {
                // Top Header Section
                VStack(spacing: 16) {
                    Text("Breathe & Stretch")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("Breathe in. Stretch out. Let it go.")
                        .font(.system(size: 25))
                        .foregroundStyle(.secondary)
                    
                    // Tip Capsule Card
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 14))
                        Text("Tip: Do your light movement with slow breathing. Use the 4-7-8 rhythm.")
                            .font(.system(size: 15))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .clipShape(Capsule())
                    .padding(.top, 40)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Center area where you can place your breathing circle or content later
                VStack {
                    // Placeholder for content/circle if needed during exercise
                }
                
                Spacer()
                
                // Bottom Controls (Reset and Play)
                HStack(spacing: 40) {
                    // Reset Button
                    Button(action: {
                        isActive = false
                        timeRemaining = 120
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(themeOrange)
                    }
                    
                    // Play / Pause Button
                    Button(action: {
                        isActive.toggle()
                    }) {
                        Image(systemName: isActive ? "pause.fill" : "play.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(themeOrange)
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    IndolenceView()
}
