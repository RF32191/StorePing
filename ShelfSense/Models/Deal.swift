//
//  Deal.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class Deal {
    var id: UUID
    var productName: String
    var brand: String?
    var storeName: String
    var storeID: UUID?
    var originalPrice: Double
    var salePrice: Double
    var discountPercent: Double
    var expiresAt: Date?
    var isTrending: Bool
    var isRecommended: Bool
    var categoryRaw: String?
    var sourceRaw: String
    var sourceURL: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    @Transient
    var savings: Double {
        originalPrice - salePrice
    }

    @Transient
    var category: InventoryCategory? {
        guard let categoryRaw else { return nil }
        return InventoryCategory(rawValue: categoryRaw)
    }

    @Transient
    var source: DealSource {
        get { DealSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    @Transient
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    @Transient
    var isActive: Bool { !isExpired }

    init(
        productName: String,
        brand: String? = nil,
        storeName: String,
        storeID: UUID? = nil,
        originalPrice: Double,
        salePrice: Double,
        expiresAt: Date? = nil,
        isTrending: Bool = false,
        isRecommended: Bool = false,
        category: InventoryCategory? = nil,
        source: DealSource = .manual,
        sourceURL: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.productName = productName
        self.brand = brand
        self.storeName = storeName
        self.storeID = storeID
        self.originalPrice = originalPrice
        self.salePrice = salePrice
        self.discountPercent = originalPrice > 0 ? ((originalPrice - salePrice) / originalPrice) * 100 : 0
        self.expiresAt = expiresAt
        self.isTrending = isTrending
        self.isRecommended = isRecommended
        self.categoryRaw = category?.rawValue
        self.sourceRaw = source.rawValue
        self.sourceURL = sourceURL
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
