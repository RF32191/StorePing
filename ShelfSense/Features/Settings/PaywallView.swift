//
//  PaywallView.swift
//  ShelfSense
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var premiumStore: PremiumAccessStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    reasonBanner
                    weeklyAllowanceCard
                    featureList
                    productSection
                    legalFooter
                }
                .padding()
                .padding(.bottom, 24)
            }
            .background(ShelfGradientBackground())
            .navigationTitle(AppBrand.proName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        premiumStore.dismissPaywall()
                        dismiss()
                    }
                }
            }
        }
        .task {
            premiumStore.beginStoreServicesIfNeeded()
            await premiumStore.refreshProducts()
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(ShelfTheme.copperGradient.opacity(0.22))
                    .frame(width: 96, height: 96)
                    .blur(radius: 2)

                Circle()
                    .stroke(ShelfTheme.copperGradient, lineWidth: 2)
                    .frame(width: 88, height: 88)

                Image(systemName: "crown.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(ShelfTheme.copperGradient)
                    .shadow(color: ShelfTheme.copper.opacity(0.5), radius: 8)
            }

            CopperGradientText(text: "Unlock StorePing Pro", font: .shelfTitle)

            Text("One purchase unlocks unlimited searches, scans, GPS, meal planning, AI, geofencing, family sharing, and every premium tool.")
                .font(.shelfSubheadline)
                .foregroundStyle(ShelfTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var reasonBanner: some View {
        if let reason = premiumStore.paywallReason {
            GlassCard(padding: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(ShelfTheme.warning)
                    Text(reasonMessage(reason))
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                }
            }
        }
    }

    private var weeklyAllowanceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Free this week")
                        .font(.shelfHeadline)
                        .foregroundStyle(ShelfTheme.textPrimary)
                    Spacer()
                    if premiumStore.isPremium {
                        Label("Unlocked", systemImage: "checkmark.seal.fill")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.accentSecondary)
                    }
                }

                ForEach(premiumStore.weeklyLimitedFeatures) { feature in
                    HStack {
                        Label(feature.title, systemImage: feature.icon)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                        Spacer()
                        Text(premiumStore.isPremium ? "∞" : "\(premiumStore.remainingUses(for: feature))/1")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(ShelfTheme.copperLight)
                    }
                }
            }
        }
    }

    private var featureList: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pro-only features")
                    .font(.shelfHeadline)
                    .foregroundStyle(ShelfTheme.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    ForEach(premiumStore.fullyGatedFeatures) { feature in
                        HStack(spacing: 6) {
                            Image(systemName: feature.icon)
                                .font(.caption2)
                                .foregroundStyle(ShelfTheme.copperLight)
                                .frame(width: 16)
                            Text(feature.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(ShelfTheme.textSecondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var productSection: some View {
        if premiumStore.isPremium {
            GlassCard {
                Label("\(AppBrand.proName) is active on this Apple ID", systemImage: "crown.fill")
                    .font(.shelfSubheadline)
                    .foregroundStyle(ShelfTheme.copperLight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if premiumStore.isLoadingProducts {
            ProgressView("Loading StorePing Pro…")
                .tint(ShelfTheme.copperLight)
        } else if let product = premiumStore.unlockProduct {
            Button {
                Task { await premiumStore.purchase(product) }
            } label: {
                VStack(spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.displayName)
                                .font(.shelfHeadline)
                            Text(product.description)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary.opacity(0.9))
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Text(product.displayPrice)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                    Text("One-time unlock · Restore anytime")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ShelfTheme.textSecondary.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(ShelfTheme.backgroundPrimary)
                .padding()
                .background(ShelfTheme.copperGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: ShelfTheme.copper.opacity(0.45), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(premiumStore.purchaseInFlight)
        } else {
            VStack(spacing: 12) {
                Text("Product ID: Store.ping.Unlock")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textTertiary)
                Text("Add the in-app purchase in App Store Connect, then test with StorePing.storekit or a Sandbox Apple ID.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textTertiary)
                    .multilineTextAlignment(.center)

                #if DEBUG
                Button("Unlock Pro (Debug)") {
                    premiumStore.unlockForTesting()
                    dismiss()
                }
                .font(.shelfHeadline)
                .foregroundStyle(ShelfTheme.backgroundPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ShelfTheme.copperGradient)
                .clipShape(Capsule())
                #endif
            }
        }

        if premiumStore.purchaseInFlight {
            ProgressView()
                .tint(ShelfTheme.copperLight)
        }

        if let error = premiumStore.lastError {
            Text(error)
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.warning)
                .multilineTextAlignment(.center)
        }

        if !premiumStore.isPremium {
            Button("Restore Purchases") {
                Task { await premiumStore.restorePurchases() }
            }
            .font(.shelfCaption)
            .foregroundStyle(ShelfTheme.accentSecondary)
        }
    }

    private var legalFooter: some View {
        Text("Payment is charged to your Apple ID. Purchases can be restored on any device signed into the same Apple ID.")
            .font(.system(size: 10))
            .foregroundStyle(ShelfTheme.textTertiary)
            .multilineTextAlignment(.center)
    }

    private func reasonMessage(_ reason: PremiumAccessReason) -> String {
        switch reason {
        case .weeklyLimitReached(let feature):
            "You've used this week's free \(feature.title.lowercased()). Upgrade for unlimited access."
        case .premiumRequired(let feature):
            "\(feature.title) is part of \(AppBrand.proName)."
        }
    }
}

struct PremiumGateModifier: ViewModifier {
    @Environment(PremiumAccessStore.self) private var premiumStore
    let feature: PremiumFeature
    @Binding var isActive: Bool

    func body(content: Content) -> some View {
        content
            .disabled(!premiumStore.canUse(feature) && feature.isFullyGated)
            .overlay(alignment: .trailing) {
                if !premiumStore.isPremium && feature.isFullyGated {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(ShelfTheme.copperLight)
                        .padding(.trailing, 8)
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                guard !premiumStore.canUse(feature) else { return }
                premiumStore.presentPaywall(for: feature)
            })
    }
}

extension View {
    func premiumGated(_ feature: PremiumFeature, isActive: Binding<Bool> = .constant(false)) -> some View {
        modifier(PremiumGateModifier(feature: feature, isActive: isActive))
    }
}

struct PremiumLockedNavigationLink<Destination: View, Label: View>: View {
    @Environment(PremiumAccessStore.self) private var premiumStore
    let feature: PremiumFeature
    @ViewBuilder var destination: () -> Destination
    @ViewBuilder var label: () -> Label

    var body: some View {
        if premiumStore.canUse(feature) {
            NavigationLink(destination: destination, label: label)
        } else {
            Button {
                premiumStore.presentPaywall(for: feature)
            } label: {
                HStack {
                    label()
                    Spacer()
                    Image(systemName: feature.isFullyGated ? "lock.fill" : "crown.fill")
                        .font(.caption)
                        .foregroundStyle(ShelfTheme.copperLight.opacity(feature.isFullyGated ? 0.7 : 1))
                }
            }
            .buttonStyle(.plain)
        }
    }
}
