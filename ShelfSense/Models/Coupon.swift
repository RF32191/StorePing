//
//  Coupon.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class Coupon {
    var id: UUID
    var title: String
    var storeName: String
    var discountDescription: String
    var productName: String?
    var discountAmount: Double?
    var discountPercent: Double?
    var expiresAt: Date?
    var isUsed: Bool
    var barcode: String?
    var createdAt: Date

    @Transient
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    @Transient
    var isActive: Bool {
        !isUsed && !isExpired
    }

    init(
        title: String,
        storeName: String,
        discountDescription: String,
        productName: String? = nil,
        discountAmount: Double? = nil,
        discountPercent: Double? = nil,
        expiresAt: Date? = nil,
        barcode: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.storeName = storeName
        self.discountDescription = discountDescription
        self.productName = productName
        self.discountAmount = discountAmount
        self.discountPercent = discountPercent
        self.expiresAt = expiresAt
        self.isUsed = false
        self.barcode = barcode
        self.createdAt = Date()
    }
}
