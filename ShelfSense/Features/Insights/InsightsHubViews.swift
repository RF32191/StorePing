//
//  InsightsHubViews.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct SeasonalSuggestionsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(SeasonalSuggestionService.currentSuggestions()) { suggestion in
                Section(suggestion.title) {
                    Text(suggestion.subtitle).font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)

                    if !suggestion.items.isEmpty {
                        Text("Suggested items").font(.shelfCaption).foregroundStyle(ShelfTheme.copperLight)
                        ForEach(suggestion.items, id: \.self) { item in
                            Button {
                                modelContext.insert(ShoppingListItem(name: item, reason: suggestion.title))
                                HapticManager.lightImpact()
                            } label: {
                                Label(item, systemImage: "plus.circle")
                            }
                        }
                    }

                    ForEach(suggestion.recipes, id: \.self) { name in
                        if let recipe = Recipe.find(byName: name) {
                            NavigationLink { RecipeDetailView(recipe: recipe) } label: {
                                Text(name)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Seasonal Picks")
    }
}

struct AchievementsView: View {
    @Query private var receipts: [Receipt]
    @Query private var deals: [Deal]
    @Query private var waste: [WasteEntry]
    @Query private var listItems: [ShoppingListItem]

    private var achievements: [Achievement] {
        AchievementService.all(receipts: receipts, deals: deals, wasteEntries: waste, listItems: listItems)
    }

    var body: some View {
        List {
            Section {
                let unlocked = AchievementService.unlockedCount(from: achievements)
                Text("\(unlocked) of \(achievements.count) unlocked")
                    .font(.shelfHeadline)
            }

            ForEach(achievements) { achievement in
                HStack(spacing: 14) {
                    Image(systemName: achievement.icon)
                        .font(.title2)
                        .foregroundStyle(achievement.isUnlocked ? ShelfTheme.copperLight : ShelfTheme.textTertiary)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(achievement.title).font(.shelfSubheadline)
                            .foregroundStyle(achievement.isUnlocked ? ShelfTheme.textPrimary : ShelfTheme.textSecondary)
                        Text(achievement.description).font(.shelfCaption).foregroundStyle(ShelfTheme.textTertiary)
                        ProgressView(value: achievement.progress)
                            .tint(ShelfTheme.copper)
                    }

                    if achievement.isUnlocked {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(ShelfTheme.success)
                    }
                }
            }
        }
        .navigationTitle("Achievements")
        .onAppear {
            AchievementXPBridge.checkAndAward(achievements: achievements)
        }
    }
}

struct PantryReportView: View {
    @Query private var inventory: [InventoryItem]
    @Query private var receipts: [Receipt]
    @Query private var deals: [Deal]
    @Query private var waste: [WasteEntry]
    @Query private var listItems: [ShoppingListItem]
    @State private var reportText = ""

    private var report: PantryReport {
        let achievements = AchievementService.all(receipts: receipts, deals: deals, wasteEntries: waste, listItems: listItems)
        return PantryReportService.generate(inventory: inventory, receipts: receipts, deals: deals, waste: waste, achievements: achievements)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CopperGradientText(text: "Pantry Report", font: .shelfTitle)

                GlassCard {
                    Text(report.summaryText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(ShelfTheme.textSecondary)
                }

                ShareLink(item: report.summaryText) {
                    Label("Share Report", systemImage: "square.and.arrow.up")
                        .font(.shelfHeadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ShelfTheme.copper.opacity(0.2))
                        .foregroundStyle(ShelfTheme.copperLight)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
        .background(ShelfGradientBackground())
        .navigationTitle("Pantry Report")
    }
}
