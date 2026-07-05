//
//  PreviewModelContainer.swift
//  ShelfSense
//

import SwiftData

enum PreviewModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            Household.self,
            InventoryItem.self,
            Store.self,
            Deal.self,
            ShoppingListItem.self,
            Receipt.self,
            ReceiptLineItem.self,
            Budget.self,
            PriceAlert.self,
            PriceHistoryEntry.self,
            Coupon.self,
            WasteEntry.self,
            MealPlanEntry.self,
            HouseholdMember.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }()
}
