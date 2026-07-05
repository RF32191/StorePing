//
//  BudgetAutoFillService.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum BudgetAutoFillService {
    @MainActor
    static func applyReceiptTotal(_ total: Double, storeName: String, context: ModelContext) {
        guard total > 0 else { return }

        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        guard !budgets.isEmpty else { return }

        if let storeBudget = budgets.first(where: { $0.storeName?.lowercased() == storeName.lowercased() }) {
            storeBudget.currentSpent += total
            return
        }

        if let groceries = budgets.first(where: { $0.name.lowercased().contains("grocer") || $0.categoryRaw == InventoryCategory.groceries.rawValue }) {
            groceries.currentSpent += total
            return
        }

        budgets.first?.currentSpent += total
    }
}
