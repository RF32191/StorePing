//
//  ShelfMotion.swift
//  ShelfSense
//

import SwiftUI

enum ShelfMotion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let quick = Animation.easeOut(duration: 0.22)
    static let stagger: Double = 0.05
}

extension View {
    func shelfAppear(delay: Double = 0, offset: CGFloat = 14) -> some View {
        modifier(ShelfAppearModifier(delay: delay, offset: offset))
    }

    func shelfShimmer(delay: Double = 0) -> some View {
        modifier(ShelfShimmerModifier(delay: delay))
    }

    func shelfPressScale() -> some View {
        buttonStyle(ShelfPressButtonStyle())
    }

    func shelfStaggered(index: Int) -> some View {
        shelfAppear(delay: Double(index) * ShelfMotion.stagger)
    }
}

private struct ShelfAppearModifier: ViewModifier {
    let delay: Double
    let offset: CGFloat
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : offset)
            .onAppear {
                withAnimation(ShelfMotion.spring.delay(delay)) {
                    visible = true
                }
            }
    }
}

private struct ShelfShimmerModifier: ViewModifier {
    let delay: Double
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            ShelfTheme.copperLight.opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.45)
                    .offset(x: phase * geo.size.width * 1.4)
                }
                .clipped()
            }
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false).delay(delay)) {
                    phase = 1
                }
            }
    }
}

struct ShelfPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ShelfMotion.quick, value: configuration.isPressed)
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.shelfCaption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule().fill(ShelfTheme.copperGradient.opacity(0.25))
                } else {
                    Capsule().fill(ShelfTheme.backgroundSecondary)
                }
            }
            .foregroundStyle(isSelected ? ShelfTheme.copperLight : ShelfTheme.textSecondary)
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected ? ShelfTheme.copper.opacity(0.55) : ShelfTheme.separator,
                        lineWidth: isSelected ? 1 : 0.5
                    )
            }
        }
        .buttonStyle(ShelfPressButtonStyle())
    }
}
