//
//  AppDataBridge.swift
//  ShelfSense
//

import Foundation
import SwiftData

@MainActor
enum AppDataBridge {
    private static var container: ModelContainer?

    static func configure(container: ModelContainer) {
        self.container = container
    }

    static var context: ModelContext? {
        container?.mainContext
    }

    static func addToList(name: String, quantity: Double = 1) -> String {
        guard let context else { return "\(AppBrand.name) isn't ready yet." }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Please say an item name." }

        ShoppingListAddService.add(name: trimmed, context: context)
        QuestStore.shared.increment(.addListItems)
        try? context.save()
        return "Added \(trimmed) to your shopping list."
    }

    static func shoppingListSummary() -> String {
        guard let context else { return "\(AppBrand.name) isn't ready yet." }
        let items = (try? context.fetch(FetchDescriptor<ShoppingListItem>())) ?? []
        let active = items.filter { !$0.isCompleted }
        guard !active.isEmpty else { return "Your shopping list is empty." }

        let lines = active.prefix(10).map { "• \($0.name)" }.joined(separator: "\n")
        let suffix = active.count > 10 ? "\n…and \(active.count - 10) more." : ""
        return "You have \(active.count) items:\n\(lines)\(suffix)"
    }

    static func planMeal(recipeName: String, daysFromNow: Int = 0) -> String {
        guard let context else { return "\(AppBrand.name) isn't ready yet." }
        let recipe = Recipe.find(byName: recipeName) ?? Recipe.all.first { $0.name.localizedCaseInsensitiveContains(recipeName) }

        guard let recipe else {
            return "I couldn't find \(recipeName). Try a recipe from the meal planner."
        }

        let date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        _ = MealPlanSyncService.insert(
            recipeID: recipe.id,
            recipeName: recipe.name,
            scheduledDate: date,
            mealType: .dinner,
            context: context
        )
        QuestStore.shared.increment(.checkDeals)
        return "Planned \(recipe.name) for \(date.formatted(date: .abbreviated, time: .omitted))."
    }

    static func expiringSummary() -> String {
        guard let context else { return "\(AppBrand.name) isn't ready yet." }
        let items = (try? context.fetch(FetchDescriptor<InventoryItem>())) ?? []
        let expiring = items.filter { $0.isExpiringSoon || $0.isExpired }
            .sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }

        guard !expiring.isEmpty else { return "Nothing expiring soon — pantry looks good!" }

        let lines = expiring.prefix(8).map { item in
            let days: String
            if let date = item.expirationDate {
                let d = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
                days = "\(d)d"
            } else {
                days = "?"
            }
            return "• \(item.name) — \(days) left"
        }.joined(separator: "\n")
        return "\(expiring.count) item(s) expiring soon:\n\(lines)"
    }

    static func savingsSummary() -> String {
        let store = PlayerLevelStore.shared
        return "You've saved \(Formatters.currencyString(store.lifetimeSavings)) lifetime and you're level \(store.level) — \(store.rank.title)."
    }

    static func addRecipeIngredients(from url: String) async -> String {
        guard let context else { return "\(AppBrand.name) isn't ready yet." }
        let ingredients = await RecipeURLParser.parseIngredients(from: url)
        guard !ingredients.isEmpty else { return "Couldn't parse ingredients from that link." }

        var added = 0
        for ingredient in ingredients {
            ShoppingListAddService.add(name: ingredient, context: context)
            added += 1
        }
        try? context.save()
        QuestStore.shared.increment(.addListItems, by: min(added, 3))
        return "Added \(added) ingredients from the recipe to your list."
    }
}
