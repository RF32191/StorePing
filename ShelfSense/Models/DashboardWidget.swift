//
//  DashboardWidget.swift
//  ShelfSense
//

import Foundation
import SwiftUI

enum DashboardWidgetType: String, CaseIterable, Identifiable, Codable, Sendable {
    case todaysDeals
    case nearbyStoreAlerts
    case itemsRunningLow
    case itemsExpiringSoon
    case todaysShoppingList
    case monthlySavings
    case moneySpentThisMonth
    case inventoryValue
    case recentReceipts
    case favoriteStores
    case recommendedPurchases
    case priceDrops
    case aiRecommendations
    case recentNotifications
    case familyActivity
    case shoppingStreaks
    case budgetProgress
    case dailyQuests
    case couponMatches
    case restockPredictions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todaysDeals: "Today's Deals"
        case .nearbyStoreAlerts: "Nearby Store Alerts"
        case .itemsRunningLow: "Running Low"
        case .itemsExpiringSoon: "Expiring Soon"
        case .todaysShoppingList: "Shopping List"
        case .monthlySavings: "Monthly Savings"
        case .moneySpentThisMonth: "Spent This Month"
        case .inventoryValue: "Inventory Value"
        case .recentReceipts: "Recent Receipts"
        case .favoriteStores: "Favorite Stores"
        case .recommendedPurchases: "Recommended"
        case .priceDrops: "Price Drops"
        case .aiRecommendations: "AI Recommendations"
        case .recentNotifications: "Notifications"
        case .familyActivity: "Family Activity"
        case .shoppingStreaks: "Shopping Streak"
        case .budgetProgress: "Budget Progress"
        case .dailyQuests: "Daily Quests"
        case .couponMatches: "Coupon Matches"
        case .restockPredictions: "Restock Soon"
        }
    }

    var icon: String {
        switch self {
        case .todaysDeals: "tag.fill"
        case .nearbyStoreAlerts: "location.fill"
        case .itemsRunningLow: "exclamationmark.triangle.fill"
        case .itemsExpiringSoon: "clock.badge.exclamationmark.fill"
        case .todaysShoppingList: "checklist"
        case .monthlySavings: "dollarsign.circle.fill"
        case .moneySpentThisMonth: "creditcard.fill"
        case .inventoryValue: "archivebox.fill"
        case .recentReceipts: "doc.text.fill"
        case .favoriteStores: "heart.fill"
        case .recommendedPurchases: "sparkles"
        case .priceDrops: "arrow.down.circle.fill"
        case .aiRecommendations: "brain.head.profile.fill"
        case .recentNotifications: "bell.fill"
        case .familyActivity: "person.2.fill"
        case .shoppingStreaks: "flame.fill"
        case .budgetProgress: "chart.pie.fill"
        case .dailyQuests: "flag.checkered"
        case .couponMatches: "ticket.fill"
        case .restockPredictions: "clock.arrow.circlepath"
        }
    }

    static var defaultOrder: [DashboardWidgetType] {
        [
            .todaysShoppingList,
            .itemsRunningLow,
            .itemsExpiringSoon,
            .todaysDeals,
            .dailyQuests,
            .monthlySavings,
            .budgetProgress,
            .moneySpentThisMonth,
            .recommendedPurchases,
            .priceDrops,
            .recentReceipts,
            .favoriteStores,
            .inventoryValue,
            .shoppingStreaks,
            .aiRecommendations,
            .nearbyStoreAlerts,
            .familyActivity,
            .recentNotifications,
            .couponMatches,
            .restockPredictions,
        ]
    }

    /// Hidden on first launch for faster home screen load. Users can enable in Edit.
    static var performanceHiddenDefaults: Set<DashboardWidgetType> {
        [
            .nearbyStoreAlerts,
            .familyActivity,
            .recentNotifications,
            .couponMatches,
            .restockPredictions,
            .aiRecommendations,
            .inventoryValue,
            .shoppingStreaks,
            .recommendedPurchases,
            .priceDrops,
            .recentReceipts,
            .favoriteStores,
            .moneySpentThisMonth,
        ]
    }
}

@Observable
final class DashboardLayoutStore {
    private static let storageKey = "dashboardWidgetOrder"
    private static let hiddenKey = "dashboardHiddenWidgets"
    private static let performanceDefaultsKey = "dashboardPerformanceDefaults_v1"

    var widgetOrder: [DashboardWidgetType] {
        didSet { save() }
    }

    var hiddenWidgets: Set<DashboardWidgetType> {
        didSet { saveHidden() }
    }

    var isEditing: Bool = false

    var visibleWidgetOrder: [DashboardWidgetType] {
        widgetOrder.filter { !hiddenWidgets.contains($0) }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([DashboardWidgetType].self, from: data) {
            widgetOrder = decoded
        } else {
            widgetOrder = DashboardWidgetType.defaultOrder
        }

        if let data = UserDefaults.standard.data(forKey: Self.hiddenKey),
           let decoded = try? JSONDecoder().decode([DashboardWidgetType].self, from: data) {
            hiddenWidgets = Set(decoded)
        } else {
            hiddenWidgets = DashboardWidgetType.performanceHiddenDefaults
        }

        if !UserDefaults.standard.bool(forKey: Self.performanceDefaultsKey) {
            hiddenWidgets.formUnion(DashboardWidgetType.performanceHiddenDefaults)
            UserDefaults.standard.set(true, forKey: Self.performanceDefaultsKey)
            saveHidden()
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        widgetOrder.moveItems(fromOffsets: source, toOffset: destination)
        HapticManager.selection()
    }

    func toggleVisibility(_ widget: DashboardWidgetType) {
        if hiddenWidgets.contains(widget) {
            hiddenWidgets.remove(widget)
        } else {
            hiddenWidgets.insert(widget)
        }
        HapticManager.selection()
    }

    func isVisible(_ widget: DashboardWidgetType) -> Bool {
        !hiddenWidgets.contains(widget)
    }

    func resetToDefault() {
        widgetOrder = DashboardWidgetType.defaultOrder
        hiddenWidgets = []
        HapticManager.success()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(widgetOrder) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func saveHidden() {
        if let data = try? JSONEncoder().encode(Array(hiddenWidgets)) {
            UserDefaults.standard.set(data, forKey: Self.hiddenKey)
        }
    }
}
