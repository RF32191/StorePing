//
//  PriceAlert.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class PriceAlert {
    var id: UUID
    var productName: String
    var brand: String?
    var targetPrice: Double
    var storeName: String?
    var isEnabled: Bool
    var lastKnownPrice: Double?
    var lastTriggeredAt: Date?
    var createdAt: Date

    init(
        productName: String,
        brand: String? = nil,
        targetPrice: Double,
        storeName: String? = nil,
        isEnabled: Bool = true,
        lastKnownPrice: Double? = nil
    ) {
        self.id = UUID()
        self.productName = productName
        self.brand = brand
        self.targetPrice = targetPrice
        self.storeName = storeName
        self.isEnabled = isEnabled
        self.lastKnownPrice = lastKnownPrice
        self.lastTriggeredAt = nil
        self.createdAt = Date()
    }
}
