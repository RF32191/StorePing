//
//  HealthHubViews.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct MacroDashboardView: View {
    @Query private var listItems: [ShoppingListItem]
    @Query private var inventory: [InventoryItem]

    private var activeList: [ShoppingListItem] {
        listItems.filter { !$0.isCompleted && $0.caloriesPer100g != nil }
    }

    var body: some View {
        List {
            Section("Shopping List") {
                macroRow("Calories", value: activeList.compactMap(\.caloriesPer100g).reduce(0, +), unit: "cal/100g")
                macroRow("Carbs", value: activeList.compactMap(\.carbsPer100g).reduce(0, +), unit: "g")
                macroRow("Protein", value: activeList.compactMap(\.proteinPer100g).reduce(0, +), unit: "g")
                macroRow("Fat", value: activeList.compactMap(\.fatPer100g).reduce(0, +), unit: "g")
                macroRow("Fiber", value: activeList.compactMap(\.fiberPer100g).reduce(0, +), unit: "g")
            }

            Section {
                Text("Add items with brand/nutrition info on the Lists tab for accurate tracking. Values shown per 100g.")
                    .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
            }

            Section("Inventory Items with Nutrition") {
                if inventory.isEmpty {
                    Text("No inventory items").font(.shelfCaption).foregroundStyle(ShelfTheme.textTertiary)
                } else {
                    Text("\(inventory.count) items tracked")
                        .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                }
            }
        }
        .navigationTitle("Macro Dashboard")
    }

    private func macroRow(_ label: String, value: Double, unit: String) -> some View {
        LabeledContent(label) {
            Text(value > 0 ? "\(label == "Calories" ? String(Int(value)) : Formatters.decimalString(value)) \(unit)" : "—")
                .foregroundStyle(value > 0 ? ShelfTheme.copperLight : ShelfTheme.textTertiary)
        }
    }
}

struct DietPreferencesView: View {
    @State private var diet = UserPreferencesStore.dietPreference
    @State private var allergenInput = ""
    @State private var allergens = UserPreferencesStore.allergens

    var body: some View {
        Form {
            Section("Diet Preference") {
                Picker("Diet", selection: $diet) {
                    ForEach(DietPreference.allCases) { pref in
                        Text(pref.title).tag(pref)
                    }
                }
                .onChange(of: diet) { _, newValue in
                    UserPreferencesStore.dietPreference = newValue
                }
            }

            Section("Allergens to Avoid") {
                ForEach(allergens, id: \.self) { allergen in
                    Text(allergen)
                }
                .onDelete { index in
                    allergens.remove(atOffsets: index)
                    UserPreferencesStore.allergens = allergens
                }

                HStack {
                    TextField("e.g. peanuts, shellfish", text: $allergenInput)
                    Button("Add") {
                        let trimmed = allergenInput.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        allergens.append(trimmed)
                        UserPreferencesStore.allergens = allergens
                        allergenInput = ""
                    }
                }
            }

            Section {
                Text("Recipes and brand search results will respect your diet and flag allergens when data is available.")
                    .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
            }
        }
        .navigationTitle("Diet & Allergens")
    }
}
