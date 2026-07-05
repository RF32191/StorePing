//
//  ReceiptLineItem.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class ReceiptLineItem {
    var id: UUID
    var receiptID: UUID
    var productName: String
    var quantity: Double
    var unitPrice: Double
    var lineTotal: Double
    var originalPrice: Double?
    var discountAmount: Double
    var isOnSale: Bool
    var expirationDate: Date?
    var createdAt: Date

    init(
        receiptID: UUID,
        productName: String,
        quantity: Double = 1,
        unitPrice: Double,
        lineTotal: Double? = nil,
        originalPrice: Double? = nil,
        discountAmount: Double = 0,
        isOnSale: Bool = false,
        expirationDate: Date? = nil
    ) {
        self.id = UUID()
        self.receiptID = receiptID
        self.productName = productName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal ?? (quantity * unitPrice)
        self.originalPrice = originalPrice
        self.discountAmount = discountAmount
        self.isOnSale = isOnSale
        self.expirationDate = expirationDate
        self.createdAt = Date()
    }
}
