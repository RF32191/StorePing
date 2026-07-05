//
//  ReceiptProcessingService.swift
//  ShelfSense
//

import Foundation
import SwiftData

@MainActor
enum ReceiptProcessingService {
    static func saveReceipt(
        storeName: String,
        purchaseDate: Date,
        lineItems: [ParsedReceiptLineItem],
        rawOCRText: String?,
        context: ModelContext
    ) async {
        let subtotal = lineItems.reduce(0) { $0 + $1.lineTotal }
        let discounts = lineItems.reduce(0) { $0 + $1.discountAmount }

        let receipt = Receipt(
            storeName: storeName,
            purchaseDate: purchaseDate,
            subtotal: subtotal,
            tax: 0,
            discounts: discounts,
            total: subtotal - discounts,
            itemCount: lineItems.count,
            rawOCRText: rawOCRText
        )
        context.insert(receipt)
        receipt.household = HouseholdBootstrapService.currentHousehold(context: context)

        for parsed in lineItems {
            let lineItem = ReceiptLineItem(
                receiptID: receipt.id,
                productName: parsed.productName,
                quantity: parsed.quantity,
                unitPrice: parsed.unitPrice,
                lineTotal: parsed.lineTotal,
                originalPrice: parsed.originalPrice,
                discountAmount: parsed.discountAmount,
                isOnSale: parsed.isOnSale,
                expirationDate: parsed.expirationDate
            )
            context.insert(lineItem)
        }

        let store = ensureStore(named: storeName, context: context)
        applyLineItemsToInventory(
            lineItems,
            storeName: store.name,
            purchaseDate: purchaseDate,
            receiptID: receipt.id,
            context: context
        )

        await DealEngine.shared.processReceiptDeals(
            receipt: receipt,
            lineItems: lineItems,
            store: store,
            context: context
        )

        RestockService.syncShoppingList(context: context)
        try? context.save()

        if discounts > 0.01 {
            PlayerLevelStore.shared.recordSavings(discounts, reason: "Receipt savings")
        }

        BudgetAutoFillService.applyReceiptTotal(receipt.total, storeName: storeName, context: context)
        QuestStore.shared.increment(.scanReceipt)
        WidgetSnapshotSyncService.sync(context: context)
    }

    private static func ensureStore(named name: String, context: ModelContext) -> Store {
        if let existing = findStore(named: name, context: context) {
            return existing
        }

        let store = Store(
            name: name,
            chain: StoreChain.from(name: name),
            isFavorite: false
        )
        context.insert(store)
        return store
    }

    private static func findStore(named name: String, context: ModelContext) -> Store? {
        let stores = (try? context.fetch(FetchDescriptor<Store>())) ?? []
        return stores.first {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame ||
            name.localizedCaseInsensitiveContains($0.name) ||
            $0.name.localizedCaseInsensitiveContains(name)
        }
    }

    private static func applyLineItemsToInventory(
        _ lineItems: [ParsedReceiptLineItem],
        storeName: String,
        purchaseDate: Date,
        receiptID: UUID,
        context: ModelContext
    ) {
        let inventory = (try? context.fetch(FetchDescriptor<InventoryItem>())) ?? []

        for parsed in lineItems {
            let category = parsed.category ?? InventoryProjection.inferredCategory(for: parsed.productName)

            if let existing = inventory.first(where: { matches($0, parsed: parsed) }) {
                update(existing, from: parsed, storeName: storeName, purchaseDate: purchaseDate, receiptID: receiptID, category: category)
            } else {
                let item = createItem(from: parsed, storeName: storeName, purchaseDate: purchaseDate, receiptID: receiptID, category: category)
                context.insert(item)
            }
        }
    }

    private static func matches(_ item: InventoryItem, parsed: ParsedReceiptLineItem) -> Bool {
        item.name.localizedCaseInsensitiveCompare(parsed.productName) == .orderedSame ||
        parsed.productName.localizedCaseInsensitiveContains(item.name) ||
        item.name.localizedCaseInsensitiveContains(parsed.productName)
    }

    private static func update(
        _ item: InventoryItem,
        from parsed: ParsedReceiptLineItem,
        storeName: String,
        purchaseDate: Date,
        receiptID: UUID,
        category: InventoryCategory
    ) {
        item.quantity += parsed.quantity
        item.quantityUnit = parsed.quantityUnit
        item.purchasePrice = parsed.unitPrice
        item.storeName = storeName
        item.purchaseDate = purchaseDate
        item.receiptReference = receiptID.uuidString
        item.category = category
        item.updatedAt = Date()

        if let expirationDate = parsed.expirationDate {
            item.expirationDate = expirationDate
        }

        if item.typicalUsageRate == nil {
            item.typicalUsageRate = InventoryProjection.inferredUsageRate(quantity: item.quantity, category: category)
        }

        if let summary = InventoryProjection.runOutSummary(for: item) {
            item.notes = summary
        }
    }

    private static func createItem(
        from parsed: ParsedReceiptLineItem,
        storeName: String,
        purchaseDate: Date,
        receiptID: UUID,
        category: InventoryCategory
    ) -> InventoryItem {
        let usageRate = InventoryProjection.inferredUsageRate(quantity: parsed.quantity, category: category)
        let item = InventoryItem(
            name: parsed.productName,
            category: category,
            quantity: parsed.quantity,
            quantityUnit: parsed.quantityUnit,
            purchaseDate: purchaseDate,
            purchasePrice: parsed.unitPrice,
            expirationDate: parsed.expirationDate,
            typicalUsageRate: usageRate,
            storeName: storeName,
            receiptReference: receiptID.uuidString,
            minimumQuantity: max(parsed.quantity * 0.25, 1),
            notes: nil
        )

        item.notes = InventoryProjection.runOutSummary(for: item)
        return item
    }
}
