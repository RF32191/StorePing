//
//  Receipt.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class Receipt {
    var id: UUID
    var storeName: String
    var purchaseDate: Date
    var subtotal: Double
    var tax: Double
    var discounts: Double
    var total: Double
    var paymentMethod: String?
    var itemCount: Int
    var rawOCRText: String?
    var createdAt: Date
    var household: Household?

    init(
        storeName: String,
        purchaseDate: Date = Date(),
        subtotal: Double,
        tax: Double = 0,
        discounts: Double = 0,
        total: Double,
        paymentMethod: String? = nil,
        itemCount: Int = 0,
        rawOCRText: String? = nil
    ) {
        self.id = UUID()
        self.storeName = storeName
        self.purchaseDate = purchaseDate
        self.subtotal = subtotal
        self.tax = tax
        self.discounts = discounts
        self.total = total
        self.paymentMethod = paymentMethod
        self.itemCount = itemCount
        self.rawOCRText = rawOCRText
        self.createdAt = Date()
    }
}
