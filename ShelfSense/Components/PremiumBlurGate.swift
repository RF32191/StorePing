//
//  PremiumBlurGate.swift
//  ShelfSense
//

import SwiftUI

/// Blurs premium content and shows an unlock overlay until Pro is active or a weekly free use is spent.
struct PremiumBlurGate<Content: View>: View {
    @Environment(PremiumAccessStore.self) private var premiumStore
    @Binding var isUnlocked: Bool

    let feature: PremiumFeature
    var title: String = "Results locked"
    var subtitle: String = "Upgrade to see full prices, store names, and product details."
    var cornerRadius: CGFloat = ShelfTheme.cornerRadiusLarge
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()
                .blur(radius: showBlur ? 16 : 0)
                .scaleEffect(showBlur ? 0.985 : 1)
                .opacity(showBlur ? 0.78 : 1)
                .allowsHitTesting(!showBlur)
                .accessibilityHidden(showBlur)

            if showBlur {
                overlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if showBlur {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ShelfTheme.copper.opacity(0.35), lineWidth: 1)
            }
        }
        .animation(ShelfMotion.spring, value: showBlur)
        .onChange(of: premiumStore.isPremium) { _, isPremium in
            if isPremium { isUnlocked = true }
        }
    }

    private var showBlur: Bool {
        !premiumStore.isPremium && !isUnlocked
    }

    private var overlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ShelfTheme.backgroundPrimary.opacity(0.6),
                            ShelfTheme.backgroundSecondary.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(ShelfTheme.copperGradient.opacity(0.22))
                        .frame(width: 56, height: 56)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ShelfTheme.copperGradient)
                }

                Text(title)
                    .font(.shelfHeadline)
                    .foregroundStyle(ShelfTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                if premiumStore.canUse(feature) {
                    Button(action: revealWeeklyUse) {
                        Label(weeklyRevealLabel, systemImage: "eye.fill")
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.backgroundPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(ShelfTheme.copperGradient)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Weekly free use already spent")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ShelfTheme.warning)
                }

                Button {
                    premiumStore.presentPaywall(for: feature)
                } label: {
                    Text("Unlock \(AppBrand.proName)")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.copperLight)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }

    private var weeklyRevealLabel: String {
        "Reveal · \(premiumStore.remainingUses(for: feature)) left this week"
    }

    private func revealWeeklyUse() {
        if premiumStore.isPremium {
            isUnlocked = true
            return
        }
        if premiumStore.consume(feature) {
            isUnlocked = true
            HapticManager.success()
        }
    }
}
