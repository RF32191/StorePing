//
//  SeasonalSuggestionService.swift
//  ShelfSense
//

import Foundation

struct SeasonalSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let items: [String]
    let recipes: [String]
}

enum SeasonalSuggestionService {
    static func currentSuggestions() -> [SeasonalSuggestion] {
        let month = Calendar.current.component(.month, from: Date())

        switch month {
        case 6...8:
            return summer
        case 9...11:
            return fall
        case 12, 1, 2:
            return winter
        default:
            return spring
        }
    }

    private static let summer: [SeasonalSuggestion] = [
        SeasonalSuggestion(title: "Backyard BBQ", subtitle: "Grill season essentials", icon: "flame.fill",
                           items: ["burgers", "hot dogs", "buns", "ketchup", "charcoal", "watermelon"],
                           recipes: ["Sheet-pan fajitas", "Greek salad wraps"]),
        SeasonalSuggestion(title: "Pool Snacks", subtitle: "Easy grab-and-go", icon: "drop.fill",
                           items: ["chips", "salsa", "lemonade", "frozen fruit"],
                           recipes: ["Caprese panini"])
    ]

    private static let fall: [SeasonalSuggestion] = [
        SeasonalSuggestion(title: "Comfort Food", subtitle: "Cozy meals", icon: "leaf.fill",
                           items: ["pumpkin", "apples", "soup stock", "bread"],
                           recipes: ["Tomato soup + grilled cheese", "Chili"]),
        SeasonalSuggestion(title: "Game Day", subtitle: "Party platters", icon: "sportscourt.fill",
                           items: ["wings", "dip", "soda", "nacho chips"],
                           recipes: ["Tacos"])
    ]

    private static let winter: [SeasonalSuggestion] = [
        SeasonalSuggestion(title: "Holiday Baking", subtitle: "Sweet treats", icon: "gift.fill",
                           items: ["flour", "sugar", "butter", "eggs", "vanilla", "chocolate chips"],
                           recipes: ["Tomato soup + grilled cheese"]),
        SeasonalSuggestion(title: "Warm Dinners", subtitle: "Hearty one-pots", icon: "snowflake",
                           items: ["potatoes", "carrots", "beef broth", "onions"],
                           recipes: ["Chili", "Veggie curry"])
    ]

    private static let spring: [SeasonalSuggestion] = [
        SeasonalSuggestion(title: "Spring Cleaning", subtitle: "Restock household", icon: "sparkles",
                           items: ["detergent", "sponges", "trash bags", "paper towels"],
                           recipes: []),
        SeasonalSuggestion(title: "Fresh Starts", subtitle: "Light meals", icon: "sun.max.fill",
                           items: ["asparagus", "strawberries", "salmon", "salad mix"],
                           recipes: ["Salmon bowls", "Pasta primavera"])
    ]
}
