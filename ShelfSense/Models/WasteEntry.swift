//
//  WasteEntry.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class WasteEntry {
    var id: UUID
    var itemName: String
    var quantity: Double
    var quantityUnit: String
    var estimatedValue: Double?
    var reason: String?
    var loggedAt: Date

    init(itemName: String, quantity: Double = 1, quantityUnit: String = "units", estimatedValue: Double? = nil, reason: String? = nil) {
        self.id = UUID()
        self.itemName = itemName
        self.quantity = quantity
        self.quantityUnit = quantityUnit
        self.estimatedValue = estimatedValue
        self.reason = reason
        self.loggedAt = Date()
    }
}
