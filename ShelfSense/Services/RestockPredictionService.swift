//
//  RestockPredictionService.swift
//  ShelfSense
//

import Foundation

struct RestockPrediction: Identifiable {
    let id = UUID()
    let itemName: String
    let daysUntilEmpty: Int
    let suggestedDate: Date
    let confidence: String
    let averageDaysBetweenPurchases: Int?
}

enum RestockPredictionService {
    static func predictions(from items: [InventoryItem], receipts: [Receipt], lineItems: [ReceiptLineItem]) -> [RestockPrediction] {
        var results: [RestockPrediction] = []

        for item in items {
            if let days = item.daysUntilRunOut, days <= 14 {
                let suggested = Calendar.current.date(byAdding: .day, value: max(days - 1, 0), to: Date()) ?? Date()
                results.append(RestockPrediction(
                    itemName: item.name,
                    daysUntilEmpty: days,
                    suggestedDate: suggested,
                    confidence: item.typicalUsageRate != nil ? "Based on usage rate" : "Based on minimum stock",
                    averageDaysBetweenPurchases: purchaseInterval(for: item.name, receipts: receipts, lineItems: lineItems)
                ))
            } else if item.isLowStock {
                results.append(RestockPrediction(
                    itemName: item.name,
                    daysUntilEmpty: 0,
                    suggestedDate: Date(),
                    confidence: "Below minimum quantity",
                    averageDaysBetweenPurchases: purchaseInterval(for: item.name, receipts: receipts, lineItems: lineItems)
                ))
            }
        }

        return results.sorted { $0.daysUntilEmpty < $1.daysUntilEmpty }
    }

    private static func purchaseInterval(for name: String, receipts: [Receipt], lineItems: [ReceiptLineItem]) -> Int? {
        let receiptDates = Dictionary(uniqueKeysWithValues: receipts.map { ($0.id, $0.purchaseDate) })
        let dates = lineItems
            .filter { $0.productName.lowercased().contains(name.lowercased()) }
            .compactMap { receiptDates[$0.receiptID] }
            .sorted()

        guard dates.count >= 2 else { return nil }
        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i - 1], to: dates[i]).day ?? 0
            if days > 0 { intervals.append(days) }
        }
        guard !intervals.isEmpty else { return nil }
        return intervals.reduce(0, +) / intervals.count
    }
}
