//
//  InventoryProjection.swift
//  ShelfSense
//

import Foundation

enum InventoryProjection {
    /// Default supply window used when estimating usage from a receipt.
    static let defaultSupplyDays: Double = 14

    static func inferredCategory(for productName: String) -> InventoryCategory {
        let name = productName.lowercased()
        let rules: [(InventoryCategory, [String])] = [
            (.medicine, ["vitamin", "medicine", "tylenol", "advil", "aspirin", "pill"]),
            (.cleaningSupplies, ["detergent", "bleach", "cleaner", "soap", "paper towel", "tissue"]),
            (.toiletries, ["shampoo", "toothpaste", "deodorant", "lotion"]),
            (.refrigerator, ["milk", "yogurt", "cheese", "butter", "egg"]),
            (.freezer, ["frozen", "ice cream"]),
            (.pantry, ["rice", "pasta", "cereal", "can", "beans", "flour", "oil"]),
            (.petSupplies, ["dog", "cat", "pet"]),
            (.babyProducts, ["diaper", "baby", "formula"])
        ]

        for (category, keywords) in rules where keywords.contains(where: { name.contains($0) }) {
            return category
        }
        return .groceries
    }

    static func inferredUsageRate(quantity: Double, category: InventoryCategory) -> Double? {
        guard quantity > 0 else { return nil }
        let days: Double = switch category {
        case .refrigerator, .freezer: 7
        case .medicine, .toiletries: 30
        case .cleaningSupplies, .pantry: 21
        default: defaultSupplyDays
        }
        return quantity / days
    }

    static func estimatedRunOutDate(for item: InventoryItem, referenceDate: Date = Date()) -> Date? {
        if let expirationDate = item.expirationDate {
            return expirationDate
        }
        guard let rate = item.typicalUsageRate, rate > 0, item.quantity > 0 else { return nil }
        let days = Int(ceil(item.quantity / rate))
        return Calendar.current.date(byAdding: .day, value: days, to: referenceDate)
    }

    static func runOutSummary(for item: InventoryItem) -> String? {
        if let expirationDate = item.expirationDate {
            let days = Formatters.daysUntil(expirationDate)
            if days < 0 { return "Expired" }
            if days == 0 { return "Expires today" }
            return "Expires in \(days) day\(days == 1 ? "" : "s")"
        }
        if let days = item.daysUntilRunOut {
            if days <= 0 { return "Out of stock soon" }
            return "Est. needed in \(days) day\(days == 1 ? "" : "s")"
        }
        return nil
    }
}
