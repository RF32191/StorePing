//
//  InventoryItemSearchService.swift
//  ShelfSense
//

import Foundation

enum InventoryItemSearchService {
    static func search(query: String, items: [InventoryItem]) -> [ItemSearchOffer] {
        let normalized = query.lowercased()

        return items.filter { matches($0, query: normalized) }.map { item in
            ItemSearchOffer(
                id: "pantry-\(item.id.uuidString)",
                productName: item.name,
                brand: item.brand.isEmpty ? nil : item.brand,
                price: item.purchasePrice ?? 0,
                originalPrice: nil,
                rating: item.isFavorite ? 5 : nil,
                reviewCount: nil,
                storeName: item.storeName ?? "Your pantry",
                source: .pantry,
                distanceMeters: nil,
                productURL: nil,
                imageURL: nil,
                notes: pantryNote(for: item)
            )
        }
    }

    private static func matches(_ item: InventoryItem, query: String) -> Bool {
        let name = item.name.lowercased()
        let brand = item.brand.lowercased()
        return name.contains(query) ||
            brand.contains(query) ||
            query.split(separator: " ").allSatisfy { name.contains($0) || brand.contains($0) }
    }

    private static func pantryNote(for item: InventoryItem) -> String {
        var parts: [String] = ["\(item.quantity.formatted()) \(item.quantityUnit) on hand"]
        if item.isLowStock { parts.append("running low") }
        if item.isExpiringSoon { parts.append("expiring soon") }
        if let price = item.purchasePrice { parts.append("last paid \(Formatters.currencyString(price))") }
        return parts.joined(separator: " · ")
    }
}
