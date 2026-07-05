//
//  MealPlannerView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct MealPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealPlanEntry.scheduledDate) private var entries: [MealPlanEntry]
    @State private var showAdd = false

    private var upcoming: [MealPlanEntry] {
        entries.filter { !$0.isCompleted && $0.scheduledDate >= Calendar.current.startOfDay(for: Date()) }
    }

    var body: some View {
        List {
            Section {
                Text("Plan meals for the week. Missing ingredients can be added to your shopping list from any recipe.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
            }

            if upcoming.isEmpty {
                Section {
                    ContentUnavailableView("No meals planned", systemImage: "calendar", description: Text("Tap + to schedule a recipe"))
                }
            } else {
                Section("This Week") {
                    ForEach(upcoming, id: \.id) { entry in
                        NavigationLink {
                            if let recipe = Recipe.find(byID: entry.recipeID) {
                                RecipeDetailView(recipe: recipe)
                            }
                        } label: {
                            HStack {
                                Image(systemName: entry.mealType.icon)
                                    .foregroundStyle(ShelfTheme.copper)
                                VStack(alignment: .leading) {
                                    Text(entry.recipeName)
                                        .font(.shelfSubheadline)
                                    Text("\(entry.scheduledDate.formatted(date: .abbreviated, time: .omitted)) · \(entry.mealType.title)")
                                        .font(.shelfCaption)
                                        .foregroundStyle(ShelfTheme.textSecondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
            }

            Section("Quick Add") {
                ForEach(Recipe.all.filter { !$0.isFastFood }.prefix(6)) { recipe in
                    Button {
                        addRecipe(recipe, date: Date(), meal: .dinner)
                    } label: {
                        HStack {
                            Text(recipe.name)
                                .foregroundStyle(ShelfTheme.textPrimary)
                            Spacer()
                            Text("\(recipe.prepMinutes) min")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textTertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Meal Planner")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddMealPlanSheet(onAdd: addRecipe)
        }
    }

    private func addRecipe(_ recipe: Recipe, date: Date, meal: MealType) {
        _ = MealPlanSyncService.insert(
            recipeID: recipe.id,
            recipeName: recipe.name,
            scheduledDate: date,
            mealType: meal,
            context: modelContext
        )
        HapticManager.success()
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            MealPlanSyncService.delete(upcoming[index], context: modelContext)
        }
    }
}

struct AddMealPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecipe: Recipe?
    @State private var date = Date()
    @State private var meal: MealType = .dinner
    let onAdd: (Recipe, Date, MealType) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Recipe", selection: $selectedRecipe) {
                    Text("Select").tag(Optional<Recipe>.none)
                    ForEach(Recipe.all.filter { !$0.isFastFood }) { recipe in
                        Text(recipe.name).tag(Optional(recipe))
                    }
                }
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Meal", selection: $meal) {
                    ForEach(MealType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
            }
            .navigationTitle("Plan Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let selectedRecipe { onAdd(selectedRecipe, date, meal); dismiss() }
                    }
                    .disabled(selectedRecipe == nil)
                }
            }
        }
    }
}

struct PantryRecipesView: View {
    @Query private var inventory: [InventoryItem]

    private var matches: [Recipe] {
        Recipe.pantryMatches(inventoryNames: inventory.map(\.name))
            .filter { UserPreferencesStore.matchesDiet($0.tags) }
    }

    var body: some View {
        List {
            if matches.isEmpty {
                ContentUnavailableView("No matches", systemImage: "refrigerator", description: Text("Add more items to inventory"))
            } else {
                ForEach(matches) { recipe in
                    NavigationLink { RecipeDetailView(recipe: recipe) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name).font(.shelfSubheadline)
                            Text("\(recipe.prepMinutes) min · \(recipe.servings) servings")
                                .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pantry Recipes")
    }
}
