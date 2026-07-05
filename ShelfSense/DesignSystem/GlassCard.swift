//
//  GlassCard.swift
//  ShelfSense
//

import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = ShelfTheme.cornerRadiusMedium
    var padding: CGFloat = ShelfTheme.cardPadding
    var glow: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ShelfTheme.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        ShelfTheme.copperLight.opacity(0.35),
                                        ShelfTheme.copper.opacity(0.12),
                                        ShelfTheme.separator.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.75
                            )
                    }
                    .shadow(color: glow ? ShelfTheme.copper.opacity(0.2) : .black.opacity(0.35), radius: glow ? 12 : 8, y: 4)
            }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let tint: Color

    init(title: String, value: String, subtitle: String? = nil, icon: String, tint: Color = ShelfTheme.accent) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)

                    Text(value)
                        .font(.shelfStatSmall)
                        .foregroundStyle(ShelfTheme.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textTertiary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.shelfHeadline)
                .foregroundStyle(ShelfTheme.textPrimary)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.shelfSubheadline)
                    .foregroundStyle(ShelfTheme.accentSecondary)
            }
        }
    }
}
