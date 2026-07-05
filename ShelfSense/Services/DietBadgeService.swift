//
//  DietBadgeService.swift
//  ShelfSense
//

import Foundation
import SwiftUI

enum DietBadge: String {
    case compatible
    case caution
    case avoid

    var title: String {
        switch self {
        case .compatible: "Diet OK"
        case .caution: "Check label"
        case .avoid: "Avoid"
        }
    }

    var color: Color {
        switch self {
        case .compatible: ShelfTheme.success
        case .caution: ShelfTheme.warning
        case .avoid: Color.red.opacity(0.85)
        }
    }

    var icon: String {
        switch self {
        case .compatible: "checkmark.seal.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .avoid: "xmark.octagon.fill"
        }
    }
}

enum DietBadgeService {
    static func inferTags(productName: String, brand: String?, notes: String?) -> [String] {
        let combined = [productName, brand, notes].compactMap { $0?.lowercased() }.joined(separator: " ")
        var tags: [String] = []

        let meatWords = ["chicken", "beef", "pork", "bacon", "sausage", "fish", "salmon", "tuna", "meat"]
        let dairyWords = ["milk", "cheese", "butter", "yogurt", "cream", "dairy"]
        let glutenWords = ["bread", "pasta", "wheat", "flour", "cracker", "bagel"]
        let eggWords = ["egg", "mayo"]

        if meatWords.contains(where: { combined.contains($0) }) { tags.append("meat") }
        if dairyWords.contains(where: { combined.contains($0) }) { tags.append("dairy") }
        if glutenWords.contains(where: { combined.contains($0) }) { tags.append("gluten") }
        if eggWords.contains(where: { combined.contains($0) }) { tags.append("eggs") }
        if combined.contains("vegan") { tags.append("vegan") }
        if combined.contains("keto") || combined.contains("low carb") { tags.append("keto") }
        if combined.contains("low sodium") || combined.contains("no salt") { tags.append("low-sodium") }
        if combined.contains("high sodium") || combined.contains("salted") { tags.append("high-sodium") }

        return tags
    }

    static func badge(for offer: ItemSearchOffer) -> DietBadge? {
        guard UserPreferencesStore.dietPreference != .none || !UserPreferencesStore.allergens.isEmpty else { return nil }

        let tags = inferTags(productName: offer.productName, brand: offer.brand, notes: offer.notes)

        if UserPreferencesStore.containsAllergen(tags) { return .avoid }
        if !UserPreferencesStore.matchesDiet(tags) { return .avoid }

        if UserPreferencesStore.dietPreference != .none && tags.isEmpty { return .caution }
        return .compatible
    }
}
