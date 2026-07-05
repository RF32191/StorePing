//
//  MoreView.swift
//  ShelfSense
//

import SwiftUI

struct MoreView: View {
    @Bindable var layoutStore: DashboardLayoutStore
    @Environment(PremiumAccessStore.self) private var premiumStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(ShelfTheme.heroGradient)
                        CopperGradientText(text: "More", font: .shelfTitle)
                        Text("Everything \(AppBrand.name) offers")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)

                        if !premiumStore.isPremium {
                            Text("Free each week: 1 price search, 1 Near Me check, 1 barcode scan, and 1 receipt scan. Tap the crown to unlock everything.")
                                .font(.system(size: 11))
                                .foregroundStyle(ShelfTheme.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section {
                    NavigationLink { FeaturesHubView() } label: {
                        Label("Browse All Features", systemImage: "square.grid.3x3.fill")
                    }
                }

                Section("Discover") {
                    PremiumLockedNavigationLink(feature: .mealPlanner) {
                        MealPlannerView()
                    } label: {
                        Label("Meal Planner", systemImage: "calendar")
                    }
                    PremiumLockedNavigationLink(feature: .spinWheel) {
                        SpinWheelView()
                    } label: {
                        Label("Spin the Wheel", systemImage: "arrow.trianglehead.clockwise")
                    }
                    NavigationLink { ExpirationRouletteView() } label: {
                        Label("Expiration Roulette", systemImage: "clock.badge.exclamationmark")
                    }
                    PremiumLockedNavigationLink(feature: .aiAssistant) {
                        AssistantView()
                    } label: {
                        Label("AI Assistant", systemImage: "sparkles")
                    }
                    NavigationLink { SiriShortcutsGuideView() } label: {
                        Label("Siri & Shortcuts", systemImage: "mic.badge.plus")
                    }
                }

                Section("Save Money") {
                    PremiumLockedNavigationLink(feature: .cheapestCart) {
                        CheapestCartView()
                    } label: {
                        Label("Cheapest Cart", systemImage: "cart.fill")
                    }
                    PremiumLockedNavigationLink(feature: .couponMatcher) {
                        CouponMatcherView()
                    } label: {
                        Label("Coupon Matcher", systemImage: "ticket.fill")
                    }
                    PremiumLockedNavigationLink(feature: .priceHistory) {
                        PriceHistoryView()
                    } label: {
                        Label("Price History", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    PremiumLockedNavigationLink(feature: .tripOptimizer) {
                        TripOptimizerView()
                    } label: {
                        Label("Trip Optimizer", systemImage: "map.fill")
                    }
                    NavigationLink { CouponWalletView() } label: {
                        Label("Coupon Wallet", systemImage: "ticket.fill")
                    }
                }

                Section("Health & Smart") {
                    NavigationLink { MacroDashboardView() } label: {
                        Label("Macro Dashboard", systemImage: "heart.text.square.fill")
                    }
                    NavigationLink { RestockPredictionsView() } label: {
                        Label("Restock Predictions", systemImage: "clock.arrow.circlepath")
                    }
                    NavigationLink { VoiceAddItemView() } label: {
                        Label("Voice Add", systemImage: "mic.fill")
                    }
                }

                Section("Alerts") {
                    NavigationLink { AlertsCenterView() } label: {
                        Label("GPS & Price Alerts", systemImage: "bell.badge.fill")
                    }
                    PremiumLockedNavigationLink(feature: .geofencing) {
                        GeofencingSettingsView()
                    } label: {
                        Label("Store Geofencing", systemImage: "location.fill")
                    }
                    NavigationLink { NotificationSettingsView() } label: {
                        Label("Notification Settings", systemImage: "bell.fill")
                    }
                }

                Section("Customize & Insights") {
                    NavigationLink { WidgetCustomizationView(layoutStore: layoutStore) } label: {
                        Label("Edit Home Widgets", systemImage: "square.grid.2x2")
                    }
                    NavigationLink { HomeScreenWidgetsGuideView() } label: {
                        Label("Home Screen Widgets", systemImage: "platter.2.filled.iphone")
                    }
                    NavigationLink { AchievementsView() } label: {
                        Label("Achievements", systemImage: "rosette")
                    }
                    PremiumLockedNavigationLink(feature: .pantryReport) {
                        PantryReportView()
                    } label: {
                        Label("Pantry Report", systemImage: "doc.richtext.fill")
                    }
                }

                Section("Household") {
                    NavigationLink { HouseholdLeaderboardView() } label: {
                        Label("Leaderboard", systemImage: "trophy.fill")
                    }
                    NavigationLink { ShareSavingsCardView() } label: {
                        Label("Share Savings", systemImage: "square.and.arrow.up")
                    }
                    NavigationLink { RecipeURLImportView() } label: {
                        Label("Import Recipe URL", systemImage: "link")
                    }
                    PremiumLockedNavigationLink(feature: .familySharing) {
                        FamilySharingView()
                    } label: {
                        Label("Family Sharing", systemImage: "person.2.fill")
                    }
                    PremiumLockedNavigationLink(feature: .receiptSplit) {
                        ReceiptSplitView()
                    } label: {
                        Label("Split Receipt", systemImage: "person.2.wave.2.fill")
                    }
                }

                Section("Account") {
                    NavigationLink { ProfileView() } label: {
                        Label("Profile & Settings", systemImage: "person.crop.circle.fill")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ShelfGradientBackground())
            .navigationTitle("More")
            .shelfScrollBottomInset()
            .shelfScrollContentInsets()
        }
    }
}

#Preview {
    MoreView(layoutStore: DashboardLayoutStore())
        .environment(LocationManager.shared)
        .environment(PremiumAccessStore.shared)
}
