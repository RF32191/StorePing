//
//  ItemSearchHistoryStore.swift
//  ShelfSense
//

import Foundation

enum ItemSearchHistoryStore {
    private static let searchesKey = "itemSearchRecentQueries"
    private static let brandsKey = "itemSearchRecentBrands"
    private static let maxCount = 12

    static let popularQueries = [
        "organic milk", "eggs", "bread", "chicken breast",
        "paper towels", "dish soap", "laundry detergent", "bananas",
        "greek yogurt", "olive oil", "cereal", "ground beef"
    ]

    static let popularBrands = [
        "Horizon", "Great Value", "Kirkland", "Organic Valley",
        "Tide", "Charmin", "Dawn", "Cheerios", "Silk", "O Organics"
    ]

    static func recentSearches() -> [String] {
        UserDefaults.standard.stringArray(forKey: searchesKey) ?? []
    }

    static func recentBrands() -> [String] {
        UserDefaults.standard.stringArray(forKey: brandsKey) ?? []
    }

    static func recordSearch(_ query: String) {
        var items = recentSearches().filter { $0.lowercased() != query.lowercased() }
        items.insert(query, at: 0)
        UserDefaults.standard.set(Array(items.prefix(maxCount)), forKey: searchesKey)
    }

    static func recordBrand(_ brand: String) {
        var items = recentBrands().filter { $0.lowercased() != brand.lowercased() }
        items.insert(brand, at: 0)
        UserDefaults.standard.set(Array(items.prefix(maxCount)), forKey: brandsKey)
    }

    static func clearHistory() {
        UserDefaults.standard.removeObject(forKey: searchesKey)
        UserDefaults.standard.removeObject(forKey: brandsKey)
    }
}
