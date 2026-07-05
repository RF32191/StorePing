//
//  ShoppingListAddService.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum ShoppingListAddService {
    @MainActor
    static func add(_ offer: ItemSearchOffer, context: ModelContext) {
        let item = ShoppingListItem(
            name: offer.productName,
            brand: offer.brand,
            quantity: 1,
            reason: "From search · \(offer.storeName)",
            storeName: offer.storeName,
            estimatedPrice: offer.hasPrice ? offer.price : nil
        )
        context.insert(item)
        item.household = HouseholdBootstrapService.currentHousehold(context: context)
        QuestStore.shared.increment(.addListItems)
        try? context.save()
        WidgetSnapshotSyncService.sync(context: context)
        Task { await CloudKitHouseholdService.shared.syncSharedData(context: context) }
        HapticManager.success()
    }

    @MainActor
    static func add(name: String, brand: String? = nil, price: Double? = nil, context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = ShoppingListItem(
            name: trimmed,
            brand: brand,
            quantity: 1,
            estimatedPrice: price
        )
        context.insert(item)
        item.household = HouseholdBootstrapService.currentHousehold(context: context)
        QuestStore.shared.increment(.addListItems)
        try? context.save()
        WidgetSnapshotSyncService.sync(context: context)
        Task { await CloudKitHouseholdService.shared.syncSharedData(context: context) }
        HapticManager.lightImpact()
    }
}
