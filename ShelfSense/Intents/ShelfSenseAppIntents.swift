//
//  ShelfSenseAppIntents.swift
//  ShelfSense
//

import AppIntents
import SwiftUI

struct AddToShoppingListIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Shopping List"
    static var description = IntentDescription("Add an item to your StorePing shopping list.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Item", requestValueDialog: "What should I add to your list?")
    var itemName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$itemName) to my shopping list")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await MainActor.run { AppDataBridge.addToList(name: itemName) }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct ShowShoppingListIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Shopping List"
    static var description = IntentDescription("Read what's on your StorePing shopping list.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await MainActor.run { AppDataBridge.shoppingListSummary() }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct PlanMealIntent: AppIntent {
    static var title: LocalizedStringResource = "Plan a Meal"
    static var description = IntentDescription("Schedule a meal in StorePing.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Recipe", requestValueDialog: "Which recipe should I plan?")
    var recipeName: String

    @Parameter(title: "Days from today", default: 0)
    var daysFromNow: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Plan \(\.$recipeName) for dinner in \(\.$daysFromNow) days")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await MainActor.run { AppDataBridge.planMeal(recipeName: recipeName, daysFromNow: daysFromNow) }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct CheckExpiringIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Expiring Items"
    static var description = IntentDescription("See what's expiring in your pantry.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await MainActor.run { AppDataBridge.expiringSummary() }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct SavingsSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Savings Summary"
    static var description = IntentDescription("Hear your lifetime savings and level.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await MainActor.run { AppDataBridge.savingsSummary() }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct ImportRecipeIntent: AppIntent {
    static var title: LocalizedStringResource = "Import Recipe to List"
    static var description = IntentDescription("Parse a recipe URL and add ingredients to your list.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Recipe URL", requestValueDialog: "What's the recipe link?")
    var recipeURL: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add ingredients from \(\.$recipeURL)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await AppDataBridge.addRecipeIngredients(from: recipeURL)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct OpenShelfSenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Open StorePing"
    static var description = IntentDescription("Open the StorePing app.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct ShelfSenseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddToShoppingListIntent(),
            phrases: [
                "Add to my shopping list in \(.applicationName)",
                "Add groceries in \(.applicationName)"
            ],
            shortTitle: "Add to List",
            systemImageName: "cart.badge.plus"
        )

        AppShortcut(
            intent: ShowShoppingListIntent(),
            phrases: [
                "What's on my list in \(.applicationName)",
                "Read my shopping list in \(.applicationName)",
                "Show my shopping list in \(.applicationName)"
            ],
            shortTitle: "Shopping List",
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: PlanMealIntent(),
            phrases: [
                "Plan a meal in \(.applicationName)",
                "Plan dinner in \(.applicationName)"
            ],
            shortTitle: "Plan Meal",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: CheckExpiringIntent(),
            phrases: [
                "What's expiring in \(.applicationName)",
                "Check expiring food in \(.applicationName)",
                "What should I use up in \(.applicationName)"
            ],
            shortTitle: "Expiring Items",
            systemImageName: "clock.badge.exclamationmark"
        )

        AppShortcut(
            intent: SavingsSummaryIntent(),
            phrases: [
                "How much have I saved in \(.applicationName)",
                "What's my level in \(.applicationName)",
                "My savings in \(.applicationName)"
            ],
            shortTitle: "Savings",
            systemImageName: "star.fill"
        )

        AppShortcut(
            intent: ImportRecipeIntent(),
            phrases: [
                "Import a recipe in \(.applicationName)",
                "Add recipe ingredients in \(.applicationName)"
            ],
            shortTitle: "Import Recipe",
            systemImageName: "link"
        )
    }
}
