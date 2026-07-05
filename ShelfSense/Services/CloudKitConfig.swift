//
//  CloudKitConfig.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum CloudKitConfig {
    static let containerIdentifier = "iCloud.Fermoselle.ShelfSense"

    static var sharedModels: [any PersistentModel.Type] {
        [
            Household.self,
            HouseholdMember.self,
            ShoppingListItem.self,
            InventoryItem.self,
            MealPlanEntry.self,
            Receipt.self
        ]
    }
}
