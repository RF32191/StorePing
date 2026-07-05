//
//  NearbyStoreAlertService.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum NearbyStoreAlertService {
    static func generateAlert(
        for store: Store,
        distanceMeters: Double,
        inventoryItems: [InventoryItem],
        deals: [Deal],
        listItems: [ShoppingListItem] = []
    ) -> NearbyStoreAlert {
        let storeDeals = deals.filter { $0.storeName == store.name && $0.isActive }
        let activeList = listItems.filter { !$0.isCompleted }
        let listMatches = activeList.filter { item in
            storeDeals.contains { $0.productName.lowercased().contains(item.name.lowercased()) }
                || item.storeName?.lowercased() == store.name.lowercased()
        }
        let lowStockAtStore = inventoryItems.filter {
            $0.isLowStock && ($0.storeName == store.name || $0.storeName == nil)
        }

        if !listMatches.isEmpty, let deal = storeDeals.first {
            return NearbyStoreAlert(
                storeID: store.id,
                storeName: store.name,
                title: "You're near \(store.name)",
                message: "\(listMatches.count) list item(s) + \(storeDeals.count) deal(s)! Top deal: \(deal.productName) — save \(Formatters.currencyString(deal.savings)).",
                distanceMeters: distanceMeters,
                savingsEstimate: deal.savings
            )
        }

        if !listMatches.isEmpty {
            let names = listMatches.prefix(3).map(\.name).joined(separator: ", ")
            return NearbyStoreAlert(
                storeID: store.id,
                storeName: store.name,
                title: "You're near \(store.name)",
                message: "You need \(listMatches.count) item(s) on your list: \(names).",
                distanceMeters: distanceMeters
            )
        }

        if let deal = storeDeals.first, let lowItem = lowStockAtStore.first {
            return NearbyStoreAlert(
                storeID: store.id,
                storeName: store.name,
                title: "You're near \(store.name)",
                message: "\(deal.productName) is \(Int(deal.discountPercent))% off. \(lowItem.name) — only \(formatQuantity(lowItem)) left.",
                distanceMeters: distanceMeters,
                savingsEstimate: deal.savings
            )
        }

        if let deal = storeDeals.first {
            return NearbyStoreAlert(
                storeID: store.id,
                storeName: store.name,
                title: "You're near \(store.name)",
                message: "\(deal.productName) is on sale — save \(Formatters.currencyString(deal.savings)).",
                distanceMeters: distanceMeters,
                savingsEstimate: deal.savings
            )
        }

        if let item = lowStockAtStore.first {
            let daysText: String
            if let days = item.daysUntilRunOut {
                daysText = "Expected to run out in \(days) day\(days == 1 ? "" : "s")."
            } else {
                daysText = "Running low in your inventory."
            }
            return NearbyStoreAlert(
                storeID: store.id,
                storeName: store.name,
                title: "You're near \(store.name)",
                message: "\(item.name) is running low. \(daysText) Would you like to stop?",
                distanceMeters: distanceMeters
            )
        }

        return NearbyStoreAlert(
            storeID: store.id,
            storeName: store.name,
            title: "You're near \(store.name)",
            message: "You're within range of one of your favorite stores. Check your shopping list for needed items.",
            distanceMeters: distanceMeters
        )
    }

    static func presenceSubtitle(
        for store: Store,
        inventoryItems: [InventoryItem],
        deals: [Deal],
        listItems: [ShoppingListItem] = []
    ) -> String {
        let alert = generateAlert(for: store, distanceMeters: 0, inventoryItems: inventoryItems, deals: deals, listItems: listItems)
        return alert.message
    }

    private static func formatQuantity(_ item: InventoryItem) -> String {
        "\(item.quantity.formatted(.number.precision(.fractionLength(0...1)))) \(item.quantityUnit)"
    }
}
