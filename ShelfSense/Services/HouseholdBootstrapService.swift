//
//  HouseholdBootstrapService.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum HouseholdBootstrapService {
    @MainActor
    static func bootstrap(context: ModelContext) -> Household {
        if let existing = fetchPrimaryHousehold(context: context) {
            attachOrphans(to: existing, context: context)
            return existing
        }

        let household = Household(name: "My Household")
        context.insert(household)

        let me = HouseholdMember(name: "Me", role: .owner, isCurrentUser: true)
        me.household = household
        context.insert(me)

        attachOrphans(to: household, context: context)
        try? context.save()
        return household
    }

    @MainActor
    static func fetchPrimaryHousehold(context: ModelContext) -> Household? {
        let households = (try? context.fetch(FetchDescriptor<Household>())) ?? []
        return households.sorted { $0.createdAt < $1.createdAt }.first
    }

    @MainActor
    static func currentHousehold(context: ModelContext) -> Household {
        bootstrap(context: context)
    }

    @MainActor
    private static func attachOrphans(to household: Household, context: ModelContext) {
        attachOrphans(
            (try? context.fetch(FetchDescriptor<HouseholdMember>())) ?? [],
            keyPath: \HouseholdMember.household,
            household: household
        )
        attachOrphans(
            (try? context.fetch(FetchDescriptor<ShoppingListItem>())) ?? [],
            keyPath: \ShoppingListItem.household,
            household: household
        )
        attachOrphans(
            (try? context.fetch(FetchDescriptor<InventoryItem>())) ?? [],
            keyPath: \InventoryItem.household,
            household: household
        )
        attachOrphans(
            (try? context.fetch(FetchDescriptor<MealPlanEntry>())) ?? [],
            keyPath: \MealPlanEntry.household,
            household: household
        )
        attachOrphans(
            (try? context.fetch(FetchDescriptor<Receipt>())) ?? [],
            keyPath: \Receipt.household,
            household: household
        )
    }

    @MainActor
    private static func attachOrphans<T: PersistentModel>(
        _ items: [T],
        keyPath: ReferenceWritableKeyPath<T, Household?>,
        household: Household
    ) {
        for item in items where item[keyPath: keyPath] == nil {
            item[keyPath: keyPath] = household
        }
    }
}
