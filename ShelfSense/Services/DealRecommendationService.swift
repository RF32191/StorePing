//
//  DealRecommendationService.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum DealRecommendationService {
    static func recommendations(
        deals: [Deal],
        inventoryItems: [InventoryItem],
        stores: [Store]
    ) -> [AIRecommendation] {
        let activeDeals = deals.filter(\.isActive)
        guard !activeDeals.isEmpty || !inventoryItems.isEmpty else { return [] }

        var results: [AIRecommendation] = []

        for deal in activeDeals.filter(\.isRecommended).prefix(3) {
            results.append(AIRecommendation(
                title: deal.productName,
                message: deal.notes ?? "Deal at \(deal.storeName) — save \(Formatters.currencyString(deal.savings)).",
                savingsEstimate: deal.savings > 0 ? deal.savings : nil,
                confidence: deal.source == .inventoryMatch ? 0.9 : 0.75,
                storeName: deal.storeName,
                productName: deal.productName
            ))
        }

        for item in inventoryItems.filter({ $0.isLowStock }).prefix(2) {
            if results.contains(where: { $0.productName == item.name }) { continue }
            let store = item.storeName ?? stores.first?.name ?? "a nearby store"
            results.append(AIRecommendation(
                title: "\(item.name) running low",
                message: "Consider restocking at \(store). Add deals for this store to see savings.",
                confidence: 0.8,
                storeName: store,
                productName: item.name
            ))
        }

        return results
    }
}
