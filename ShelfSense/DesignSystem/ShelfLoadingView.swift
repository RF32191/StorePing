//
//  ShelfLoadingView.swift
//  ShelfSense
//

import SwiftUI

struct ShelfLoadingView: View {
    var message: String = "Finding items for you…"
    var detail: String? = "Scanning stores, brands, and prices"
    var style: Style = .full

    enum Style {
        case full
        case inline
        case compact
    }

    @State private var rotation: Double = 0
    @State private var pulse = false

    var body: some View {
        switch style {
        case .full:
            fullLoader
        case .inline:
            inlineLoader
        case .compact:
            compactLoader
        }
    }

    private var fullLoader: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(ShelfTheme.separator, lineWidth: 3)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(
                        ShelfTheme.copperGradient,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(rotation))

                Image(systemName: "bag.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ShelfTheme.heroGradient)
                    .scaleEffect(pulse ? 1.08 : 0.94)
            }

            VStack(spacing: 6) {
                Text(message)
                    .font(.shelfSubheadline)
                    .foregroundStyle(ShelfTheme.textPrimary)

                if let detail {
                    Text(detail)
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    SkeletonProductRow()
                        .shelfShimmer(delay: Double(index) * 0.15)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .onAppear { startAnimations() }
    }

    private var inlineLoader: some View {
        HStack(spacing: 12) {
            compactSpinner
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(ShelfTheme.textTertiary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(ShelfTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ShelfTheme.copper.opacity(0.2), lineWidth: 0.5)
        }
        .onAppear { startAnimations() }
    }

    private var compactLoader: some View {
        HStack(spacing: 8) {
            compactSpinner
            Text(message)
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.textSecondary)
        }
        .onAppear { startAnimations() }
    }

    private var compactSpinner: some View {
        ZStack {
            Circle()
                .stroke(ShelfTheme.separator, lineWidth: 2)
                .frame(width: 22, height: 22)
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(ShelfTheme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(rotation))
        }
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

struct SkeletonProductRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ShelfTheme.backgroundTertiary)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ShelfTheme.backgroundTertiary)
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ShelfTheme.backgroundTertiary)
                    .frame(width: 120, height: 10)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ShelfTheme.backgroundTertiary)
                    .frame(width: 80, height: 10)
            }
        }
        .padding(12)
        .background(ShelfTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ShelfProcessingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            GlassCard(glow: true) {
                ShelfLoadingView(message: message, detail: nil, style: .inline)
            }
            .padding(32)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

struct ShelfRefreshIndicator: View {
    @State private var spin = false

    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.body.weight(.semibold))
            .foregroundStyle(ShelfTheme.heroGradient)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
    }
}
