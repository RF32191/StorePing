//
//  ConfettiView.swift
//  ShelfSense
//

import SwiftUI

struct ConfettiView: View {
    @Binding var isActive: Bool

    var body: some View {
        ZStack {
            if isActive {
                ForEach(0..<48, id: \.self) { index in
                    ConfettiParticle(index: index)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            guard active else { return }
            Task {
                try? await Task.sleep(for: .seconds(2.6))
                await MainActor.run { isActive = false }
            }
        }
    }
}

private struct ConfettiParticle: View {
    let index: Int

    @State private var yOffset: CGFloat = -40
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    private var color: Color {
        let colors: [Color] = [
            ShelfTheme.copperLight,
            ShelfTheme.copper,
            ShelfTheme.copperGlow,
            ShelfTheme.success,
            ShelfTheme.accentSecondary
        ]
        return colors[index % colors.count]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: CGFloat.random(in: 6...10), height: CGFloat.random(in: 10...16))
            .rotationEffect(.degrees(rotation))
            .offset(x: xOffset, y: yOffset)
            .opacity(opacity)
            .onAppear {
                let startX = CGFloat.random(in: -160...160)
                xOffset = startX
                yOffset = CGFloat.random(in: -120...(-20))
                rotation = Double.random(in: 0...360)

                withAnimation(.easeOut(duration: Double.random(in: 1.8...2.6))) {
                    yOffset = 420
                    xOffset = startX + CGFloat.random(in: -50...50)
                    rotation += Double.random(in: 180...540)
                    opacity = 0
                }
            }
    }
}
