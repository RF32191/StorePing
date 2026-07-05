//
//  PriceHistoryEntry.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class PriceHistoryEntry {
    var id: UUID
    var productName: String
    var brand: String?
    var storeName: String
    var price: Double
    var recordedAt: Date

    init(productName: String, brand: String? = nil, storeName: String, price: Double, recordedAt: Date = Date()) {
        self.id = UUID()
        self.productName = productName
        self.brand = brand
        self.storeName = storeName
        self.price = price
        self.recordedAt = recordedAt
    }
}
