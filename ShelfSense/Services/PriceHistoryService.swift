//
//  PriceHistoryService.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum PriceHistoryService {
    static func record(deals: [Deal], context: ModelContext) {
        for deal in deals where deal.isActive && deal.salePrice > 0 {
            let entry = PriceHistoryEntry(
                productName: deal.productName,
                brand: deal.brand,
                storeName: deal.storeName,
                price: deal.salePrice
            )
            context.insert(entry)
        }
    }

    static func history(for productName: String, entries: [PriceHistoryEntry]) -> [PriceHistoryEntry] {
        let query = productName.lowercased()
        return entries
            .filter { $0.productName.lowercased().contains(query) || query.contains($0.productName.lowercased()) }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    static func lowestPrice(for productName: String, entries: [PriceHistoryEntry]) -> PriceHistoryEntry? {
        history(for: productName, entries: entries).min(by: { $0.price < $1.price })
    }

    static func averagePrice(for productName: String, entries: [PriceHistoryEntry]) -> Double? {
        let items = history(for: productName, entries: entries)
        guard !items.isEmpty else { return nil }
        return items.reduce(0) { $0 + $1.price } / Double(items.count)
    }

    static func groupedProducts(_ entries: [PriceHistoryEntry]) -> [(name: String, count: Int, latest: Double, lowest: Double)] {
        let grouped = Dictionary(grouping: entries) { $0.productName.lowercased() }
        return grouped.map { key, values in
            let name = values.first?.productName ?? key
            let latest = values.max(by: { $0.recordedAt < $1.recordedAt })?.price ?? 0
            let lowest = values.min(by: { $0.price < $1.price })?.price ?? 0
            return (name: name, count: values.count, latest: latest, lowest: lowest)
        }
        .sorted { $0.name < $1.name }
    }
}
