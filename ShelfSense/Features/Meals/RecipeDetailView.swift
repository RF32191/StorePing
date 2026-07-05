//
//  RecipeDetailView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var inventory: [InventoryItem]
    let recipe: Recipe
    @State private var addedCount = 0

    private var missingIngredients: [RecipeIngredient] {
        let pantry = inventory.map { $0.name.lowercased() }
        return recipe.ingredients.filter { ing in
            !pantry.contains { $0.contains(ing.name.lowercased()) || ing.name.lowercased().contains($0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    CopperGradientText(text: recipe.name, font: .shelfTitle)
                    HStack(spacing: 12) {
                        Label("\(recipe.prepMinutes) min", systemImage: "clock")
                        Label("\(recipe.servings) servings", systemImage: "person.2")
                        if let cal = recipe.caloriesPerServing {
                            Label("\(cal) cal", systemImage: "flame")
                        }
                    }
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
                }

                if recipe.isFastFood, let chain = recipe.fastFoodChain {
                    GlassCard {
                        Label("Get directions to \(chain)", systemImage: "map.fill")
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.copperLight)
                    }
                }

                if !recipe.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ingredients").font(.shelfHeadline)
                        ForEach(recipe.ingredients) { ing in
                            HStack {
                                Circle().fill(ShelfTheme.copper.opacity(0.5)).frame(width: 6, height: 6)
                                Text("\(ing.quantity) \(ing.unit) \(ing.name)")
                                    .font(.shelfSubheadline)
                            }
                        }
                    }

                    if !missingIngredients.isEmpty {
                        Button {
                            addMissingToList()
                        } label: {
                            Label("Add \(missingIngredients.count) missing to list", systemImage: "cart.badge.plus")
                                .font(.shelfHeadline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ShelfTheme.copperGradient.opacity(0.3))
                                .foregroundStyle(ShelfTheme.copperLight)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(ShelfPressButtonStyle())

                        if addedCount > 0 {
                            Text("Added \(addedCount) items to your shopping list")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.success)
                        }
                    } else if !recipe.ingredients.isEmpty {
                        Label("You have all ingredients!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(ShelfTheme.success)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Steps").font(.shelfHeadline)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.copperLight)
                                .frame(width: 20)
                            Text(step).font(.shelfSubheadline)
                        }
                    }
                }

                if let carbs = recipe.carbsPerServing, let protein = recipe.proteinPerServing {
                    GlassCard {
                        Text("Per serving: \(Formatters.decimalString(carbs))g carbs · \(Formatters.decimalString(protein))g protein")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }
                }
            }
            .padding()
        }
        .background(ShelfGradientBackground())
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addMissingToList() {
        for ing in missingIngredients {
            let item = ShoppingListItem(name: ing.name, quantity: 1, quantityUnit: ing.unit, reason: "For \(recipe.name)")
            modelContext.insert(item)
        }
        addedCount = missingIngredients.count
        HapticManager.success()
    }
}
