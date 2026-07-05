//
//  MealPlanSyncService.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum MealPlanSyncService {
    @MainActor
    static func insert(
        recipeID: String,
        recipeName: String,
        scheduledDate: Date,
        mealType: MealType,
        context: ModelContext
    ) -> MealPlanEntry {
        let entry = MealPlanEntry(
            recipeID: recipeID,
            recipeName: recipeName,
            scheduledDate: scheduledDate,
            mealType: mealType
        )
        context.insert(entry)
        persist(entry, context: context)
        return entry
    }

    @MainActor
    static func persist(_ entry: MealPlanEntry, context: ModelContext) {
        entry.household = HouseholdBootstrapService.currentHousehold(context: context)
        try? context.save()
        Task { await CloudKitHouseholdService.shared.syncSharedData(context: context) }
    }

    @MainActor
    static func delete(_ entry: MealPlanEntry, context: ModelContext) {
        context.delete(entry)
        try? context.save()
        Task { await CloudKitHouseholdService.shared.syncSharedData(context: context) }
    }
}
