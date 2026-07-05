//
//  SubstitutionService.swift
//  ShelfSense
//

import Foundation

struct Substitution: Identifiable {
    let id = UUID()
    let original: String
    let substitute: String
    let reason: String
    let ratio: String
}

enum SubstitutionService {
    private static let database: [String: [(String, String, String)]] = [
        "butter": [("margarine", "Similar fat content for baking", "1:1"), ("olive oil", "For sautéing", "3/4 cup per 1 cup")],
        "milk": [("oat milk", "Dairy-free alternative", "1:1"), ("almond milk", "Lower calorie", "1:1")],
        "eggs": [("flax egg", "Vegan binding", "1 tbsp flax + 3 tbsp water"), ("applesauce", "Baking substitute", "1/4 cup per egg")],
        "flour": [("almond flour", "Gluten-free, keto", "1:1"), ("oat flour", "Whole grain option", "1:1")],
        "sugar": [("honey", "Natural sweetener", "3/4 cup per 1 cup"), ("stevia", "Zero calorie", "1 tsp per 1 cup")],
        "sour cream": [("greek yogurt", "Higher protein", "1:1"), ("coconut cream", "Dairy-free", "1:1")],
        "bread": [("tortillas", "Lower carb wrap", "1:1"), ("lettuce wraps", "Low carb", "2 leaves per slice")],
        "rice": [("cauliflower rice", "Low carb", "1:1"), ("quinoa", "Higher protein", "1:1")],
        "pasta": [("zucchini noodles", "Low carb", "1:1"), ("chickpea pasta", "Higher protein", "1:1")],
        "chicken": [("tofu", "Vegetarian protein", "1:1 by weight"), ("turkey", "Leaner meat", "1:1")]
    ]

    static func substitutes(for itemName: String) -> [Substitution] {
        let key = itemName.lowercased()
        for (ingredient, options) in database {
            if key.contains(ingredient) || ingredient.contains(key) {
                return options.map { Substitution(original: itemName, substitute: $0.0, reason: $0.1, ratio: $0.2) }
            }
        }
        return []
    }

    static func commonItems() -> [String] {
        Array(database.keys).sorted()
    }
}
