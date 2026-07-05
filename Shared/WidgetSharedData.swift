//
//  WidgetSharedData.swift
//  Shared between ShelfSense app and widget extension
//

import Foundation

enum WidgetAppGroup {
    static let identifier = "group.Fermoselle.ShelfSense"
    static let snapshotKey = "widgetSnapshot"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}

struct WidgetSnapshot: Codable, Sendable {
    var updatedAt: Date
    var level: Int
    var rankTitle: String
    var rankIcon: String
    var lifetimeSavings: Double
    var xpProgress: Double
    var currentXP: Int
    var xpToNext: Int
    var shoppingListItems: [String]
    var shoppingListCount: Int
    var estimatedListTotal: Double
    var expiringItems: [String]
    var expiringCount: Int
    var questsCompleted: Int
    var questsTotal: Int
    var questStreak: Int
    var monthlySavings: Double

    static let placeholder = WidgetSnapshot(
        updatedAt: Date(),
        level: 1,
        rankTitle: "Cart Rookie",
        rankIcon: "cart",
        lifetimeSavings: 0,
        xpProgress: 0.15,
        currentXP: 15,
        xpToNext: 100,
        shoppingListItems: ["Milk", "Eggs", "Bread"],
        shoppingListCount: 3,
        estimatedListTotal: 12.50,
        expiringItems: ["Yogurt"],
        expiringCount: 1,
        questsCompleted: 1,
        questsTotal: 5,
        questStreak: 0,
        monthlySavings: 0
    )
}

enum WidgetSharedDataStore {
    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = WidgetAppGroup.defaults,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: WidgetAppGroup.snapshotKey)
    }

    static func load() -> WidgetSnapshot {
        guard let defaults = WidgetAppGroup.defaults,
              let data = defaults.data(forKey: WidgetAppGroup.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }
}
