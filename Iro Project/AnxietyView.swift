//
//  AnxietyView.swift
//  Iro Project
//
//  Created by RaneemAhmad on 11/05/1448 AH.
//

import SwiftUI

struct AnxietyView: View {
    
    @State private var isBathing = false
    
    var body: some View {
        
        ZStack {
            // Base clean background
          
            // Top-left warm/yellow ambient glow
            Circle()
                .fill(Color.yellow.opacity(0.25))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .position(x: 50, y: 50)
            
            // Top-left soft blue ambient glow
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 380, height: 380)
                .blur(radius: 70)
                .position(x: 200, y: 20)
            
            // Bottom-right soft blue ambient glow
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 400, height: 600)
                .blur(radius: 70)
                .position(x: 1300, y: 900)
            
            VStack(spacing: 0) {
                
                Spacer()
                
                // Titles
                VStack(spacing: 20) {
                    Text("Breathe").font(.system(size: 40))
                        .fontWeight(.semibold)
                    
                    Text("Inhale. Exhale. Reset.")
                        .font(.system(size: 24))
                }
                .padding(.bottom, 40)
                
                Spacer()
                
                // --- 7-LAYER CONTOUR CIRCULAR HALO (Fixed Frame, Internal Scaling Only) ---
                
                ZStack {
                    // Layer 7 (Outermost - Lightest airy tint)
                    Circle()
                        .fill(Color.blue.opacity(0.06))
                        .frame(width: 330, height: 330)
                    
                    // Layer 6
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 290, height: 290)
                    
                    // Layer 5
                    Circle()
                        .fill(Color.blue.opacity(0.20))
                        .frame(width: 250, height: 250)
                    
                    // Layer 4
                    Circle()
                        .fill(Color.blue.opacity(0.30))
                        .frame(width: 210, height: 210)
                    
                    // Layer 3
                    Circle()
                        .fill(Color.blue.opacity(0.40))
                        .frame(width: 170, height: 170)
                    
                    // Layer 2
                    Circle()
                        .fill(Color.blue.opacity(0.60))
                        .frame(width: 130, height: 130)
                    
                    // Layer 1 (Innermost Center - Medium Blue)
                    Circle()
                        .fill(Color(.systemBlue).opacity(0.85))
                        .frame(width: 90, height: 90)
                }
                .frame(width: 350, height: 350) // 1. Locks the layout boundary so nothing shifts
                .scaleEffect(isBathing ? 1.08 : 0.92) // 2. Animates purely visually
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isBathing.toggle()
                    }
                }
                .padding(.vertical, 40)
                
                Spacer()
                
                // Bottom Controls
                HStack(spacing: 24) {
                    
                    Button(action: {
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    
                    Button(action: {
                        // Action goes here
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundStyle(.orange)
                            .frame(alignment: .center)
                    }
                }
                .padding(.bottom, 100)
            }
        }// end body
    }
    
}
#Preview {
    AnxietyView()
}
