//
//  AssistantEngine.swift
//  ShelfSense
//

import Foundation

enum AssistantEngine {
    static func respond(
        to query: String,
        inventory: [InventoryItem],
        deals: [Deal],
        stores: [Store],
        receipts: [Receipt],
        listItems: [ShoppingListItem],
        wasteEntries: [WasteEntry],
        mealPlans: [MealPlanEntry]
    ) -> String {
        let lowercased = query.lowercased()

        if lowercased.contains("meal plan") || lowercased.contains("plan dinner") || lowercased.contains("what's for dinner") {
            let upcoming = mealPlans.filter { !$0.isCompleted && $0.scheduledDate >= Calendar.current.startOfDay(for: Date()) }
            if upcoming.isEmpty {
                return "No meals planned yet. Open More → Meal Planner or spin the wheel to pick something!"
            }
            let lines = upcoming.prefix(5).map { "• \($0.recipeName) — \($0.scheduledDate.formatted(date: .abbreviated, time: .omitted)) (\($0.mealType.title))" }.joined(separator: "\n")
            return "Your upcoming meals:\n\n\(lines)"
        }

        if lowercased.contains("cook with") || lowercased.contains("pantry recipe") || lowercased.contains("what can i make") {
            let names = inventory.map(\.name)
            let matches = Recipe.pantryMatches(inventoryNames: names)
            if matches.isEmpty {
                return "Add more ingredients to your inventory and I can suggest recipes you can make right now."
            }
            let lines = matches.prefix(5).map { "• \($0.name) — \($0.prepMinutes) min" }.joined(separator: "\n")
            return "Recipes you can make with what you have:\n\n\(lines)"
        }

        if lowercased.contains("waste") || lowercased.contains("threw away") {
            let total = wasteEntries.compactMap(\.estimatedValue).reduce(0, +)
            if wasteEntries.isEmpty {
                return "No waste logged — great job reducing food waste!"
            }
            return "You've logged \(wasteEntries.count) waste entries totaling \(Formatters.currencyString(total)). Check Waste Tracker in More to log items."
        }

        if lowercased.contains("substitut") || lowercased.contains("instead of") {
            for item in SubstitutionService.commonItems() where lowercased.contains(item) {
                let subs = SubstitutionService.substitutes(for: item)
                if subs.isEmpty { continue }
                let lines = subs.map { "• \($0.substitute) — \($0.reason) (\($0.ratio))" }.joined(separator: "\n")
                return "Substitutes for \(item):\n\n\(lines)"
            }
            return "Tell me an ingredient, like \"substitute for butter\" and I'll suggest alternatives."
        }

        if lowercased.contains("trip") || lowercased.contains("which store") || lowercased.contains("cheapest") {
            let active = listItems.filter { !$0.isCompleted }
            let plans = TripOptimizerService.optimize(listItems: active, deals: deals, stores: stores)
            if plans.isEmpty {
                return "Add items to your shopping list and save stores to get trip optimization suggestions."
            }
            let lines = plans.prefix(3).map { "• \($0.storeName) — \($0.itemCount) items, ~\(Formatters.currencyString($0.estimatedTotal))" }.joined(separator: "\n")
            return "Best stores for your list:\n\n\(lines)"
        }

        if lowercased.contains("macro") || lowercased.contains("calorie") || lowercased.contains("nutrition") {
            let withNutrition = listItems.filter { $0.caloriesPer100g != nil && !$0.isCompleted }
            if withNutrition.isEmpty {
                return "Add items with brand/nutrition info to your list to track macros. Use + on the Lists tab."
            }
            let cal = withNutrition.compactMap(\.caloriesPer100g).reduce(0, +)
            let carbs = withNutrition.compactMap(\.carbsPer100g).reduce(0, +)
            return "List nutrition snapshot (per 100g totals):\n• Calories: \(Int(cal))\n• Carbs: \(Formatters.decimalString(carbs))g\n\nOpen Macro Dashboard in More for details."
        }

        if lowercased.contains("restock") || lowercased.contains("when should i buy") {
            return "Check Restock Predictions in More for AI-suggested restock dates based on your usage and receipt history."
        }

        if lowercased.contains("achievement") || lowercased.contains("badge") {
            let achievements = AchievementService.all(receipts: receipts, deals: deals, wasteEntries: wasteEntries, listItems: listItems)
            let unlocked = AchievementService.unlockedCount(from: achievements)
            return "You've unlocked \(unlocked) of \(achievements.count) achievements. Open More → Achievements to see your progress!"
        }

        if lowercased.contains("season") || lowercased.contains("holiday") {
            let suggestions = SeasonalSuggestionService.currentSuggestions()
            let lines = suggestions.map { "• \($0.title) — \($0.subtitle)" }.joined(separator: "\n")
            return "Seasonal picks for this month:\n\n\(lines)"
        }

        return ""
    }
}
