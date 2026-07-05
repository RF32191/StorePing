//
//  UserPreferencesStore.swift
//  ShelfSense
//

import Foundation

enum DietPreference: String, CaseIterable, Identifiable, Codable {
    case none, vegetarian, vegan, glutenFree, lowSodium, keto, dairyFree

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "No restrictions"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten-free"
        case .lowSodium: "Low sodium"
        case .keto: "Keto"
        case .dairyFree: "Dairy-free"
        }
    }
}

enum UserPreferencesStore {
    private static let dietKey = "userDietPreference"
    private static let allergensKey = "userAllergens"
    private static let streakKey = "savingsStreakWeeks"
    private static let streakStartKey = "savingsStreakStart"

    static var dietPreference: DietPreference {
        get {
            guard let raw = UserDefaults.standard.string(forKey: dietKey),
                  let pref = DietPreference(rawValue: raw) else { return .none }
            return pref
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: dietKey) }
    }

    static var allergens: [String] {
        get { UserDefaults.standard.stringArray(forKey: allergensKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: allergensKey) }
    }

    static var savingsStreakWeeks: Int {
        get { UserDefaults.standard.integer(forKey: streakKey) }
        set { UserDefaults.standard.set(newValue, forKey: streakKey) }
    }

    static func matchesDiet(_ tags: [String]) -> Bool {
        switch dietPreference {
        case .none: return true
        case .vegetarian: return !tags.contains("meat") && !tags.contains("fish")
        case .vegan: return tags.contains("vegan") || (!tags.contains("meat") && !tags.contains("dairy") && !tags.contains("eggs"))
        case .glutenFree: return !tags.contains("gluten")
        case .lowSodium: return tags.contains("low-sodium") || !tags.contains("high-sodium")
        case .keto: return tags.contains("keto") || tags.contains("low-carb")
        case .dairyFree: return !tags.contains("dairy")
        }
    }

    static func containsAllergen(_ allergenTags: [String]) -> Bool {
        let userAllergens = Set(allergens.map { $0.lowercased() })
        return allergenTags.contains { userAllergens.contains($0.lowercased()) }
    }
}
