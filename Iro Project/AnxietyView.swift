//
//  AnxietyView.swift
//  Iro Project
//
//  Created by RaneemAhmad on 11/05/1448 AH.
//

import SwiftUI
import Combine

enum AnxietyBreathingMethod: String, Identifiable, CaseIterable {
    case rhythm478 = "4-7-8 Rhythm"
    case boxBreathing = "Box Breathing"
    
    var id: String { self.rawValue }
    
    var subtitle: String {
        switch self {
        case .rhythm478:
            return "4 second inhale, 7 second hold, 8 second exhale."
        case .boxBreathing:
            return "4 second inhale, 6 second exhale."
        }
    }
}

struct AnxietyView: View {
    @State private var isActive = false
    @State private var timeRemaining = 120 // 2 minutes countdown
    @State private var selectedMethod: AnxietyBreathingMethod = .rhythm478
    @State private var showEditSheet = false
    
    @State private var circleScale: CGFloat = 0.9
    @State private var currentPhase: BreathingPhase = .ready
    @State private var currentSecond: Int = 0
    
    enum BreathingPhase {
        case ready, inhale, hold, exhale
        
        var title: String {
            switch self {
            case .ready: return "Inhale. Exhale. Reset."
            case .inhale: return "Inhale"
            case .hold: return "Hold"
            case .exhale: return "Exhale"
            }
        }
    }
    
    let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private let themeLavender = Color(red: 200/255, green: 185/255, blue: 225/255)
    
    var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func runBreathingCycle() {
        guard isActive else { return }
        
        if selectedMethod == .rhythm478 {
            currentPhase = .inhale
            currentSecond = 4
            withAnimation(.easeInOut(duration: 4.0)) {
                circleScale = 1.15
            }
            tickSeconds(total: 4) {
                guard isActive else { return }
                
                currentPhase = .hold
                currentSecond = 7
                tickSeconds(total: 7) {
                    guard isActive else { return }
                    
                    currentPhase = .exhale
                    currentSecond = 8
                    withAnimation(.easeInOut(duration: 8.0)) {
                        circleScale = 0.9
                    }
                    tickSeconds(total: 8) {
                        if isActive { runBreathingCycle() }
                    }
                }
            }
        } else {
            currentPhase = .inhale
            currentSecond = 4
            withAnimation(.easeInOut(duration: 4.0)) {
                circleScale = 1.15
            }
            tickSeconds(total: 4) {
                guard isActive else { return }
                
                currentPhase = .exhale
                currentSecond = 6
                withAnimation(.easeInOut(duration: 6.0)) {
                    circleScale = 0.9
                }
                tickSeconds(total: 6) {
                    if isActive { runBreathingCycle() }
                }
            }
        }
    }
    
    func tickSeconds(total: Int, completion: @escaping () -> Void) {
        if total <= 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                completion()
            }
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                if currentSecond > 1 {
                    currentSecond -= 1
                }
            }
            tickSeconds(total: total - 1, completion: completion)
        }
    }
    
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
                
                VStack(spacing: 16) {
                    Text("Breathe")
                        .font(.system(size: 50))
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 6) {
                        Text(currentPhase.title)
                        if currentPhase != .ready {
                            Text("\(currentSecond)")
                                .transition(.opacity.combined(with: .scale))
                                .id(currentSecond)
                        }
                    }
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.primary)
                    .animation(.easeInOut(duration: 0.3), value: currentSecond)
                    
                    Text(timeString)
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.top, 22)
                }
                .padding(.bottom, 44)
                
                Spacer()
                
                ZStack {
                        Circle().fill(themeLavender.opacity(0.06)).frame(width: 430, height: 430)
                        Circle().fill(themeLavender.opacity(0.12)).frame(width: 375, height: 375)
                        Circle().fill(themeLavender.opacity(0.20)).frame(width: 320, height: 320)
                        Circle().fill(themeLavender.opacity(0.30)).frame(width: 265, height: 265)
                        Circle().fill(themeLavender.opacity(0.42)).frame(width: 210, height: 210)
                        Circle().fill(themeLavender.opacity(0.60)).frame(width: 155, height: 155)
                        Circle().fill(themeLavender.opacity(0.85)).frame(width: 100, height: 100)
                    }              .frame(width: 450, height: 450)
                .scaleEffect(circleScale)
                .padding(.vertical, 20)
                
                Spacer()
                
                HStack {
                    Spacer()
                    HStack(spacing: 32) {
                        Button(action: {
                            isActive = false
                            timeRemaining = 120
                            circleScale = 0.9
                            currentPhase = .ready
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                        
                        Button(action: {
                            isActive.toggle()
                            if isActive {
                                runBreathingCycle()
                            } else {
                                circleScale = 0.9
                                currentPhase = .ready
                            }
                        }) {
                            Image(systemName: isActive ? "pause.fill" : "play.fill")
                                .font(.system(size: 50, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                        
                        Button(action: {
                            showEditSheet = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 110)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AnxietyEditSheet(selectedMethod: $selectedMethod, onMethodChanged: {
                isActive = false
                timeRemaining = 120
                circleScale = 0.9
                currentPhase = .ready
            })
            .presentationDetents([.fraction(0.55), .medium])
            .presentationCornerRadius(35)
        }
        .onReceive(timerPublisher) { _ in
            guard isActive else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                isActive = false
                currentPhase = .ready
            }
        }
    }
}

struct AnxietyEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedMethod: AnxietyBreathingMethod
    var onMethodChanged: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                
                Spacer()
                
                Text("Edit")
                    .font(.system(size: 24, weight: .bold))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            VStack(spacing: 20) {
                AnxietyOptionCard(
                    title: AnxietyBreathingMethod.rhythm478.rawValue,
                    subtitle: AnxietyBreathingMethod.rhythm478.subtitle,
                    isSelected: selectedMethod == .rhythm478,
                    onToggle: {
                        selectedMethod = .rhythm478
                        onMethodChanged()
                    }
                )
                
                AnxietyOptionCard(
                    title: AnxietyBreathingMethod.boxBreathing.rawValue,
                    subtitle: AnxietyBreathingMethod.boxBreathing.subtitle,
                    isSelected: selectedMethod == .boxBreathing,
                    onToggle: {
                        selectedMethod = .boxBreathing
                        onMethodChanged()
                    }
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(Color(red: 248/255, green: 248/255, blue: 248/255))
    }
}

struct AnxietyOptionCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { newValue in
                        if newValue { onToggle() }
                    }
                ))
                .labelsHidden()
                .tint(.green)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
        }
    }
}

#Preview {
    AnxietyView()
}
