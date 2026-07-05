//
//  ItemSearchService.swift
//  ShelfSense
//

import CoreLocation
import Foundation
import SwiftData

enum ItemSearchSort: String, CaseIterable, Identifiable {
    case bestPrice
    case topRated
    case nearest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bestPrice: "Best Price"
        case .topRated: "Top Rated"
        case .nearest: "Nearest"
        }
    }

    var icon: String {
        switch self {
        case .bestPrice: "dollarsign.circle.fill"
        case .topRated: "star.fill"
        case .nearest: "location.fill"
        }
    }
}

enum ItemSearchService {
    static func search(
        query: String,
        coordinate: CLLocationCoordinate2D?,
        stores: [Store],
        deals: [Deal],
        receipts: [Receipt],
        lineItems: [ReceiptLineItem],
        inventoryItems: [InventoryItem]
    ) async -> ItemSearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ItemSearchResults(query: query, offers: [], brands: [], searchedAt: Date())
        }

        async let amazon = AmazonProductSearchService.search(query: trimmed)
        async let walmart = WalmartProductSearchService.search(query: trimmed)
        async let target = TargetProductSearchService.search(query: trimmed)
        async let catalog = OpenFoodFactsSearchService.search(query: trimmed)
        async let local = LocalItemPriceService.search(
            query: trimmed,
            coordinate: coordinate,
            stores: stores,
            deals: deals,
            receipts: receipts,
            lineItems: lineItems
        )

        let pantry = InventoryItemSearchService.search(query: trimmed, items: inventoryItems)
        let combined = await amazon + walmart + target + catalog + local + pantry
        let brands = extractBrands(from: combined)

        ItemSearchHistoryStore.recordSearch(trimmed)
        for brand in brands.prefix(5) {
            ItemSearchHistoryStore.recordBrand(brand)
        }

        return ItemSearchResults(
            query: trimmed,
            offers: combined,
            brands: brands,
            searchedAt: Date()
        )
    }

    static func sort(_ offers: [ItemSearchOffer], by sort: ItemSearchSort) -> [ItemSearchOffer] {
        switch sort {
        case .bestPrice:
            return offers.sorted {
                let lp = $0.hasPrice ? $0.price : .greatestFiniteMagnitude
                let rp = $1.hasPrice ? $1.price : .greatestFiniteMagnitude
                return lp < rp
            }
        case .topRated:
            return offers.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .nearest:
            return offers.sorted {
                ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude)
            }
        }
    }

    private static func extractBrands(from offers: [ItemSearchOffer]) -> [String] {
        var seen = Set<String>()
        var brands: [String] = []

        for offer in offers {
            if let brand = offer.brand?.trimmingCharacters(in: .whitespacesAndNewlines),
               !brand.isEmpty,
               seen.insert(brand.lowercased()).inserted {
                brands.append(brand)
            }

            for token in inferredBrands(from: offer.productName) where seen.insert(token.lowercased()).inserted {
                brands.append(token)
            }
        }

        return brands.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func inferredBrands(from productName: String) -> [String] {
        let known = [
            "Great Value", "Horizon Organic", "Organic Valley", "Kirkland Signature", "Kirkland",
            "Good & Gather", "Market Pantry", "O Organics", "Silk", "Cheerios", "Tide",
            "Charmin", "Dawn", "Bounty", "Clorox", "Heinz", "Barilla", "Chobani", "Fage"
        ]
        return known.filter { productName.localizedCaseInsensitiveContains($0) }
    }
}
