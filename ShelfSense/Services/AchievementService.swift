//
//  AchievementService.swift
//  ShelfSense
//

import Foundation

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
    let progress: Double
}

enum AchievementService {
    static func all(
        receipts: [Receipt],
        deals: [Deal],
        wasteEntries: [WasteEntry],
        listItems: [ShoppingListItem]
    ) -> [Achievement] {
        let receiptCount = receipts.count
        let savings = deals.filter(\.isActive).reduce(0) { $0 + $1.savings }
        let completedList = listItems.filter(\.isCompleted).count
        let wasteValue = wasteEntries.compactMap(\.estimatedValue).reduce(0, +)

        return [
            Achievement(
                id: "first-receipt",
                title: "First Receipt",
                description: "Scan your first receipt",
                icon: "doc.text.fill",
                isUnlocked: receiptCount >= 1,
                progress: min(Double(receiptCount), 1)
            ),
            Achievement(
                id: "receipt-pro",
                title: "Receipt Pro",
                description: "Scan 10 receipts",
                icon: "doc.on.doc.fill",
                isUnlocked: receiptCount >= 10,
                progress: min(Double(receiptCount) / 10, 1)
            ),
            Achievement(
                id: "saver-100",
                title: "Smart Saver",
                description: "Save $100 from deals",
                icon: "dollarsign.circle.fill",
                isUnlocked: savings >= 100,
                progress: min(savings / 100, 1)
            ),
            Achievement(
                id: "list-master",
                title: "List Master",
                description: "Complete 25 shopping list items",
                icon: "checklist",
                isUnlocked: completedList >= 25,
                progress: min(Double(completedList) / 25, 1)
            ),
            Achievement(
                id: "waste-warrior",
                title: "Waste Warrior",
                description: "Log zero waste for 30 days",
                icon: "leaf.fill",
                isUnlocked: wasteEntries.isEmpty,
                progress: wasteEntries.isEmpty ? 1 : max(0, 1 - wasteValue / 50)
            ),
            Achievement(
                id: "streak-4",
                title: "Budget Streak",
                description: "4 weeks under budget",
                icon: "flame.fill",
                isUnlocked: UserPreferencesStore.savingsStreakWeeks >= 4,
                progress: min(Double(UserPreferencesStore.savingsStreakWeeks) / 4, 1)
            )
        ]
    }

    static func unlockedCount(from achievements: [Achievement]) -> Int {
        achievements.filter(\.isUnlocked).count
    }
}
