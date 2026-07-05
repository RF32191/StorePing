//
//  ExpirationRouletteService.swift
//  ShelfSense
//

import Foundation

struct ExpirationRouletteResult: Identifiable {
    let id = UUID()
    let expiringItems: [InventoryItem]
    let suggestedRecipe: Recipe?
    let xpBonus: Int
}

enum ExpirationRouletteService {
    static func spin(from items: [InventoryItem]) -> ExpirationRouletteResult? {
        let expiring = items
            .filter { $0.isExpiringSoon || $0.isExpired }
            .sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }

        guard !expiring.isEmpty else { return nil }

        let picked = Array(expiring.prefix(3))
        let names = picked.map(\.name)
        let recipe = Recipe.pantryMatches(inventoryNames: names).first
            ?? Recipe.all.first

        return ExpirationRouletteResult(
            expiringItems: picked,
            suggestedRecipe: recipe,
            xpBonus: 30 + picked.count * 10
        )
    }
}
