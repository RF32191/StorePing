//
//  DashboardWidgetContainer.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct DashboardWidgetContainer: View {
    let widgetType: DashboardWidgetType
    let isEditing: Bool
    let inventoryItems: [InventoryItem]
    let deals: [Deal]
    let listItems: [ShoppingListItem]
    let receipts: [Receipt]
    let stores: [Store]
    let budgets: [Budget]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(ShelfTheme.textTertiary)
                    Image(systemName: widgetType.icon)
                        .foregroundStyle(ShelfTheme.accent)
                    Text(widgetType.title)
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                }
                .padding(.bottom, 8)
            }

            widgetContent
        }
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch widgetType {
        case .todaysDeals:
            TodaysDealsWidget(deals: deals)
        case .nearbyStoreAlerts:
            NearbyStoreAlertsWidget()
        case .itemsRunningLow:
            ItemsRunningLowWidget(items: inventoryItems.filter { $0.isLowStock })
        case .itemsExpiringSoon:
            ItemsExpiringSoonWidget(items: inventoryItems.filter { $0.isExpiringSoon || $0.isExpired })
        case .todaysShoppingList:
            ShoppingListWidget(items: listItems.filter { !$0.isCompleted })
        case .monthlySavings:
            MonthlySavingsWidget(receipts: receipts, deals: deals)
        case .moneySpentThisMonth:
            MoneySpentWidget(receipts: receipts)
        case .inventoryValue:
            InventoryValueWidget(items: inventoryItems)
        case .recentReceipts:
            RecentReceiptsWidget(receipts: receipts)
        case .favoriteStores:
            FavoriteStoresWidget(stores: stores.filter { $0.isFavorite })
        case .recommendedPurchases:
            RecommendedPurchasesWidget(deals: deals.filter { $0.isRecommended })
        case .priceDrops:
            PriceDropsWidget(deals: deals.sorted { $0.discountPercent > $1.discountPercent }.prefix(3).map { $0 })
        case .aiRecommendations:
            AIRecommendationsWidget(
                recommendations: DealRecommendationService.recommendations(
                    deals: deals,
                    inventoryItems: inventoryItems,
                    stores: stores
                )
            )
        case .recentNotifications:
            NotificationsWidget()
        case .familyActivity:
            FamilyActivityWidget()
        case .shoppingStreaks:
            ShoppingStreakWidget(receipts: receipts)
        case .budgetProgress:
            BudgetProgressWidget(budgets: budgets)
        case .dailyQuests:
            DailyQuestsWidget()
        case .couponMatches:
            CouponMatchesWidget()
        case .restockPredictions:
            RestockPredictionsWidget()
        }
    }
}
