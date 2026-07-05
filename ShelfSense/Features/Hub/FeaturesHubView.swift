//
//  FeaturesHubView.swift
//  ShelfSense
//

import SwiftUI

struct FeaturesHubView: View {
    @Environment(PremiumAccessStore.self) private var premiumStore

    var body: some View {
        List {
            Section("Arcade & Quests") {
                nav(DailyQuestsView(), "Daily Quests", "flag.checkered")
                nav(HouseholdLeaderboardView(), "Leaderboard", "trophy.fill")
                nav(ExpirationRouletteView(), "Expiration Roulette", "clock.badge.exclamationmark")
                nav(ShareSavingsCardView(), "Share Savings Card", "square.and.arrow.up")
            }

            Section("Voice & Siri") {
                nav(SiriShortcutsGuideView(), "Siri Shortcuts", "mic.badge.plus")
                nav(RecipeURLImportView(), "Import Recipe URL", "link")
                nav(VoiceAddItemView(), "Voice Add", "mic.fill")
            }

            Section("Meals & Planning") {
                premiumNav(.mealPlanner, MealPlannerView(), "Meal Planner", "calendar")
                premiumNav(.cookWithPantry, PantryRecipesView(), "Cook With Pantry", "refrigerator.fill")
                nav(SeasonalSuggestionsView(), "Seasonal Picks", "leaf.fill")
            }

            Section("Save Money") {
                premiumNav(.cheapestCart, CheapestCartView(), "Cheapest Cart", "cart.fill")
                premiumNav(.couponMatcher, CouponMatcherView(), "Coupon Matcher", "ticket.fill")
                premiumNav(.priceHistory, PriceHistoryView(), "Price History", "chart.line.uptrend.xyaxis")
                premiumNav(.tripOptimizer, TripOptimizerView(), "Trip Optimizer", "map.fill")
                nav(CouponWalletView(), "Coupon Wallet", "ticket.fill")
                nav(BudgetCategoriesView(), "Budget by Category", "chart.pie.fill")
                nav(SavingsStreakView(), "Savings Streak", "flame.fill")
            }

            Section("Health & Nutrition") {
                nav(MacroDashboardView(), "Macro Dashboard", "heart.text.square.fill")
                nav(DietPreferencesView(), "Diet & Allergens", "leaf.circle.fill")
            }

            Section("Smart Tools") {
                nav(RestockPredictionsView(), "Restock Predictions", "clock.arrow.circlepath")
                nav(WasteTrackerView(), "Waste Tracker", "trash.circle.fill")
                nav(SubstitutionView(), "Substitutions", "arrow.triangle.swap")
                nav(UnitConverterView(), "Unit Converter", "scalemass.fill")
            }

            Section("In Store") {
                nav(InStoreModeView(), "In-Store Mode", "cart.fill")
                nav(StoreComparisonView(), "Store Comparison", "storefront.fill")
            }

            Section("Household") {
                premiumNav(.familySharing, FamilySharingView(), "Family Sharing", "person.2.fill")
                premiumNav(.receiptSplit, ReceiptSplitView(), "Split Receipt", "person.2.wave.2.fill")
            }

            Section("Insights") {
                nav(AchievementsView(), "Achievements", "rosette")
                premiumNav(.pantryReport, PantryReportView(), "Pantry Report", "doc.richtext.fill")
            }
        }
        .scrollContentBackground(.hidden)
        .background(ShelfGradientBackground())
        .navigationTitle("All Features")
    }

    private func nav<V: View>(_ view: V, _ title: String, _ icon: String) -> some View {
        NavigationLink { view } label: {
            Label(title, systemImage: icon)
        }
    }

    private func premiumNav<V: View>(_ feature: PremiumFeature, _ view: V, _ title: String, _ icon: String) -> some View {
        PremiumLockedNavigationLink(feature: feature) {
            view
        } label: {
            Label(title, systemImage: icon)
        }
    }
}
