//
//  Budget.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID
    var name: String
    var monthlyLimit: Double
    var currentSpent: Double
    var categoryRaw: String?
    var storeName: String?
    var createdAt: Date

    @Transient
    var progress: Double {
        guard monthlyLimit > 0 else { return 0 }
        return min(currentSpent / monthlyLimit, 1.0)
    }

    @Transient
    var remaining: Double {
        max(monthlyLimit - currentSpent, 0)
    }

    @Transient
    var isNearLimit: Bool {
        progress >= 0.85
    }

    init(
        name: String,
        monthlyLimit: Double,
        currentSpent: Double = 0,
        category: InventoryCategory? = nil,
        storeName: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.monthlyLimit = monthlyLimit
        self.currentSpent = currentSpent
        self.categoryRaw = category?.rawValue
        self.storeName = storeName
        self.createdAt = Date()
    }
}
