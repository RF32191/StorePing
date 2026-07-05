//
//  AppGlobalTopBar.swift
//  ShelfSense
//

import SwiftUI

enum ShelfChromeMetrics {
    static let topBarHeight: CGFloat = 52
    static let tabBarHeight: CGFloat = 72
    static let scrollBottomPadding: CGFloat = 20
    /// Reserves space for the Home profile button so the centered controls don't overlap it.
    static let homeLeadingReserve: CGFloat = 52
}

struct AppGlobalTopBar: View {
    @Bindable var premiumStore: PremiumAccessStore
    @Bindable var playerStore: PlayerLevelStore
    @Bindable var tutorialStore: TutorialStore
    var reservesHomeLeadingSpace: Bool
    var onScan: () -> Void
    var onShowPaywall: () -> Void
    var onShowProfile: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if reservesHomeLeadingSpace {
                Color.clear
                    .frame(width: ShelfChromeMetrics.homeLeadingReserve, height: 1)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                scanButton
                crownButton
            }

            Spacer(minLength: 0)

            trailingChrome
        }
        .padding(.horizontal, 10)
        .frame(height: ShelfChromeMetrics.topBarHeight)
    }

    private var scanButton: some View {
        Button(action: onScan) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ShelfTheme.copperLight)
                .frame(width: 40, height: 40)
                .background(ShelfTheme.backgroundSecondary.opacity(0.92))
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(ShelfTheme.copper.opacity(0.35), lineWidth: 0.75)
                }
        }
        .accessibilityLabel("Scan barcode or receipt")
    }

    private var crownButton: some View {
        Button(action: onShowPaywall) {
            HStack(spacing: 8) {
                ZStack {
                    if premiumStore.isPremium {
                        Circle()
                            .stroke(ShelfTheme.copperGradient, lineWidth: 2)
                            .frame(width: 34, height: 34)
                            .shadow(color: ShelfTheme.copper.opacity(0.45), radius: 6)
                    } else {
                        Circle()
                            .stroke(ShelfTheme.copper.opacity(0.35), lineWidth: 1)
                            .frame(width: 34, height: 34)
                    }

                    Image(systemName: "crown.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(
                            premiumStore.isPremium
                                ? AnyShapeStyle(ShelfTheme.copperGradient)
                                : AnyShapeStyle(ShelfTheme.copperLight)
                        )
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(premiumStore.isPremium ? AppBrand.proName : "Upgrade")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            premiumStore.isPremium ? ShelfTheme.copperLight : ShelfTheme.textPrimary
                        )
                    Text(premiumStore.crownBadgeText)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            premiumStore.isPremium
                                ? ShelfTheme.accentSecondary
                                : ShelfTheme.textTertiary
                        )
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .background {
                Group {
                    if premiumStore.isPremium {
                        Capsule(style: .continuous)
                            .fill(ShelfTheme.copperGradient.opacity(0.18))
                    } else {
                        Capsule(style: .continuous)
                            .fill(ShelfTheme.backgroundSecondary.opacity(0.95))
                    }
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            premiumStore.isPremium
                                ? ShelfTheme.copper.opacity(0.55)
                                : ShelfTheme.copper.opacity(0.28),
                            lineWidth: 1
                        )
                }
                .shadow(color: ShelfTheme.copper.opacity(premiumStore.isPremium ? 0.3 : 0.12), radius: 8, y: 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            premiumStore.isPremium
                ? "\(AppBrand.proName) active"
                : "Upgrade to \(AppBrand.proName). \(premiumStore.crownBadgeText) free uses remaining this week."
        )
    }

    private var trailingChrome: some View {
        HStack(spacing: 10) {
            Button {
                tutorialStore.present()
                HapticManager.lightImpact()
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ShelfTheme.copperLight.opacity(0.85))
            }
            .accessibilityLabel("Tutorial")

            Button(action: onShowProfile) {
                HStack(spacing: 6) {
                    Image(systemName: playerStore.rank.icon)
                        .font(.caption)
                    Text("Lv \(playerStore.level)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(ShelfTheme.backgroundPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(ShelfTheme.copperGradient)
                        .shadow(color: ShelfTheme.copper.opacity(0.35), radius: 4, y: 2)
                }
            }
            .accessibilityLabel("Level \(playerStore.level)")
        }
    }
}

extension View {
    /// Extra bottom padding so the last row/button clears scroll clipping inside tab content.
    func shelfScrollBottomInset() -> some View {
        padding(.bottom, ShelfChromeMetrics.scrollBottomPadding)
    }

    /// Ensures scroll views can reach the bottom without content sitting under the tab bar.
    func shelfScrollContentInsets() -> some View {
        contentMargins(.bottom, ShelfChromeMetrics.scrollBottomPadding, for: .scrollContent)
    }
}
