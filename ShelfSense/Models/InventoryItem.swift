//
//  InventoryItem.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class InventoryItem {
    var id: UUID
    var name: String
    var brand: String
    var categoryRaw: String
    var barcode: String?
    var quantity: Double
    var quantityUnit: String
    var purchaseDate: Date?
    var purchasePrice: Double?
    var expirationDate: Date?
    var typicalUsageRate: Double?
    var storeName: String?
    var receiptReference: String?
    var storageLocation: String?
    var isFavorite: Bool
    var minimumQuantity: Double
    var preferredReplacementBrand: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var household: Household?

    @Transient
    var category: InventoryCategory {
        get { InventoryCategory(rawValue: categoryRaw) ?? .everythingElse }
        set { categoryRaw = newValue.rawValue }
    }

    @Transient
    var isLowStock: Bool {
        quantity <= minimumQuantity
    }

    @Transient
    var isExpiringSoon: Bool {
        guard let expirationDate else { return false }
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return expirationDate <= weekFromNow && expirationDate >= Date()
    }

    @Transient
    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
    }

    @Transient
    var daysUntilRunOut: Int? {
        guard let rate = typicalUsageRate, rate > 0 else { return nil }
        return Int(ceil(quantity / rate))
    }

    init(
        name: String,
        brand: String = "",
        category: InventoryCategory = .groceries,
        barcode: String? = nil,
        quantity: Double = 1,
        quantityUnit: String = "units",
        purchaseDate: Date? = nil,
        purchasePrice: Double? = nil,
        expirationDate: Date? = nil,
        typicalUsageRate: Double? = nil,
        storeName: String? = nil,
        receiptReference: String? = nil,
        storageLocation: String? = nil,
        isFavorite: Bool = false,
        minimumQuantity: Double = 1,
        preferredReplacementBrand: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.categoryRaw = category.rawValue
        self.barcode = barcode
        self.quantity = quantity
        self.quantityUnit = quantityUnit
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.expirationDate = expirationDate
        self.typicalUsageRate = typicalUsageRate
        self.storeName = storeName
        self.receiptReference = receiptReference
        self.storageLocation = storageLocation
        self.isFavorite = isFavorite
        self.minimumQuantity = minimumQuantity
        self.preferredReplacementBrand = preferredReplacementBrand
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
