//
//  DealEngine.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Observable
@MainActor
final class DealEngine {
    static let shared = DealEngine()

    private(set) var isRefreshing = false
    private(set) var lastRefreshSummary: String?

    private init() {}

    func refreshAllStores(context: ModelContext) async {
        let stores = (try? context.fetch(FetchDescriptor<Store>())) ?? []
        await refreshStores(stores, context: context)
    }

    func refreshStaleStores(context: ModelContext, maxStores: Int = 3) async {
        let stores = (try? context.fetch(FetchDescriptor<Store>())) ?? []
        let stale = stores.filter(\.needsDealRefresh).prefix(max(0, maxStores))
        await refreshStores(Array(stale), context: context)
    }

    private func refreshStores(_ stores: [Store], context: ModelContext) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var refreshed = 0

        for store in stores {
            await refreshStore(store, context: context)
            refreshed += 1
        }

        try? context.save()
        lastRefreshSummary = refreshed > 0
            ? "Updated deals for \(refreshed) store\(refreshed == 1 ? "" : "s")"
            : lastRefreshSummary

        let alerts = (try? context.fetch(FetchDescriptor<PriceAlert>())) ?? []
        let allDeals = (try? context.fetch(FetchDescriptor<Deal>())) ?? []
        PriceAlertService.evaluate(deals: allDeals, alerts: alerts)
        PriceHistoryService.record(deals: allDeals, context: context)
        PlayerLevelStore.shared.syncDealSavings(allDeals)
    }

    func refreshStore(_ store: Store, context: ModelContext) async {
        expireOldDeals(for: store, context: context)
        await syncWeeklyAdReference(for: store, context: context)
        await fetchOnlineDeals(for: store, context: context)
        matchInventoryDeals(for: store, context: context)
        detectPriceDrops(for: store, context: context)
        scoreDeals(for: store, context: context)

        store.lastDealRefresh = Date()
        try? context.save()
    }

    func addManualDeal(
        productName: String,
        brand: String?,
        store: Store,
        originalPrice: Double,
        salePrice: Double,
        expiresAt: Date?,
        notes: String?,
        context: ModelContext
    ) {
        let deal = Deal(
            productName: productName,
            brand: brand,
            storeName: store.name,
            storeID: store.id,
            originalPrice: originalPrice,
            salePrice: salePrice,
            expiresAt: expiresAt,
            category: nil,
            source: .manual,
            notes: notes
        )
        context.insert(deal)
        score(deal: deal, store: store, context: context)
        store.lastDealRefresh = Date()
        try? context.save()
    }

    func processReceiptDeals(
        receipt: Receipt,
        lineItems: [ParsedReceiptLineItem],
        store: Store,
        context: ModelContext
    ) async {
        createDealsFromReceiptLineItems(lineItems, store: store, context: context)
        detectPriceDrops(for: store, context: context)
        scoreDeals(for: store, context: context)
        store.lastDealRefresh = Date()
        try? context.save()
    }

    func processReceiptDealsWithoutStore(
        receipt: Receipt,
        lineItems: [ParsedReceiptLineItem],
        context: ModelContext
    ) async {
        for parsed in lineItems where parsed.isOnSale || parsed.discountAmount > 0 {
            let existing = fetchDealsByName(parsed.productName, context: context)
            if existing.contains(where: { $0.source == .receipt && $0.productName == parsed.productName }) { continue }

            let deal = Deal(
                productName: parsed.productName,
                storeName: receipt.storeName,
                originalPrice: parsed.originalPrice ?? parsed.unitPrice + parsed.discountAmount,
                salePrice: parsed.unitPrice,
                expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                source: .receipt,
                notes: "Sale item from receipt on \(receipt.purchaseDate.formatted(date: .abbreviated, time: .omitted))"
            )
            context.insert(deal)
        }
        try? context.save()
    }

    // MARK: - Per-store refresh steps

    private func expireOldDeals(for store: Store, context: ModelContext) {
        let deals = fetchDeals(for: store, context: context)
        for deal in deals where deal.isExpired {
            context.delete(deal)
        }
    }

    private func syncWeeklyAdReference(for store: Store, context: ModelContext) async {
        guard let adURL = store.weeklyAdURL ?? store.chain.weeklyAdURL?.absoluteString else { return }

        store.weeklyAdURL = adURL
        store.dealsPageURL = store.dealsPageURL ?? adURL

        let existing = fetchDeals(for: store, context: context)
        let hasWeeklyAdEntry = existing.contains {
            $0.source == .weeklyAd && $0.sourceURL == adURL
        }

        guard !hasWeeklyAdEntry else { return }

        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        let deal = Deal(
            productName: "\(store.name) Weekly Ad",
            storeName: store.name,
            storeID: store.id,
            originalPrice: 0,
            salePrice: 0,
            expiresAt: weekEnd,
            isTrending: true,
            source: .weeklyAd,
            sourceURL: adURL,
            notes: "Tap to view current weekly deals and add items you find."
        )
        context.insert(deal)
    }

    private func fetchOnlineDeals(for store: Store, context: ModelContext) async {
        let fetched = await ChainDealFetcherRegistry.fetchDeals(for: store)
        guard !fetched.isEmpty else { return }

        let existing = fetchDeals(for: store, context: context)
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date())

        for item in fetched {
            guard item.isValidProductDeal else { continue }

            if let match = existing.first(where: {
                $0.source == .chainCatalog &&
                $0.productName.localizedCaseInsensitiveCompare(item.productName) == .orderedSame
            }) {
                match.originalPrice = item.originalPrice
                match.salePrice = item.salePrice
                match.discountPercent = item.originalPrice > 0
                    ? ((item.originalPrice - item.salePrice) / item.originalPrice) * 100
                    : 0
                match.source = .chainCatalog
                match.sourceURL = item.sourceURL ?? store.dealsPageURL
                match.notes = item.notes
                match.expiresAt = item.expiresAt ?? weekEnd
                match.updatedAt = Date()
                continue
            }

            let deal = Deal(
                productName: item.productName,
                brand: item.brand,
                storeName: store.name,
                storeID: store.id,
                originalPrice: item.originalPrice,
                salePrice: item.salePrice,
                expiresAt: item.expiresAt ?? weekEnd,
                source: .chainCatalog,
                sourceURL: item.sourceURL ?? store.dealsPageURL,
                notes: item.notes
            )
            context.insert(deal)
        }
    }

    private func matchInventoryDeals(for store: Store, context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<InventoryItem>())) ?? []
        let deals = fetchDeals(for: store, context: context)

        for item in items {
            guard item.isLowStock || item.isExpiringSoon || item.isFavorite else { continue }

            if let existing = deals.first(where: { dealsMatch($0, item: item) }) {
                existing.isRecommended = true
                existing.source = .inventoryMatch
                existing.updatedAt = Date()
                continue
            }

            let price = item.purchasePrice ?? 0
            let deal = Deal(
                productName: item.name,
                brand: item.brand.isEmpty ? nil : item.brand,
                storeName: store.name,
                storeID: store.id,
                originalPrice: price,
                salePrice: price * 0.85,
                expiresAt: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
                isRecommended: true,
                category: item.category,
                source: .inventoryMatch,
                notes: recommendationNote(for: item)
            )
            context.insert(deal)
        }
    }

    private func detectPriceDrops(for store: Store, context: ModelContext) {
        let receipts = (try? context.fetch(FetchDescriptor<Receipt>())) ?? []
            .filter { $0.storeName == store.name }
        guard !receipts.isEmpty else { return }

        let items = (try? context.fetch(FetchDescriptor<InventoryItem>())) ?? []
            .filter { $0.storeName == store.name && $0.purchasePrice != nil }

        for item in items {
            guard let currentPrice = item.purchasePrice else { continue }
            let avgRecent = averageRecentPrice(for: item.name, storeName: store.name, context: context) ?? currentPrice
            guard avgRecent > currentPrice * 1.05 else { continue }

            let existing = fetchDeals(for: store, context: context)
            if existing.contains(where: { $0.source == .priceDrop && $0.productName == item.name }) { continue }

            let deal = Deal(
                productName: item.name,
                brand: item.brand.isEmpty ? nil : item.brand,
                storeName: store.name,
                storeID: store.id,
                originalPrice: avgRecent,
                salePrice: currentPrice,
                expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                source: .priceDrop,
                notes: "Recent price at \(store.name) is lower than your average."
            )
            context.insert(deal)
        }
    }

    private func createDealsFromReceiptLineItems(
        _ lineItems: [ParsedReceiptLineItem],
        store: Store,
        context: ModelContext
    ) {
        let existing = fetchDeals(for: store, context: context)

        for parsed in lineItems {
            let isDeal = parsed.isOnSale || parsed.discountAmount > 0.01
            guard isDeal else { continue }

            if existing.contains(where: {
                $0.source == .receipt &&
                $0.productName.localizedCaseInsensitiveCompare(parsed.productName) == .orderedSame
            }) { continue }

            let original = parsed.originalPrice ?? parsed.unitPrice + parsed.discountAmount
            let deal = Deal(
                productName: parsed.productName,
                storeName: store.name,
                storeID: store.id,
                originalPrice: original,
                salePrice: parsed.unitPrice,
                expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                isRecommended: true,
                source: .receipt,
                notes: "Sale item detected on your receipt."
            )
            context.insert(deal)
        }
    }

    private func scoreDeals(for store: Store, context: ModelContext) {
        let deals = fetchDeals(for: store, context: context)
        for deal in deals {
            score(deal: deal, store: store, context: context)
        }
    }

    private func score(deal: Deal, store: Store, context: ModelContext) {
        var score = deal.discountPercent

        if deal.isRecommended { score += 15 }
        if deal.source == .inventoryMatch { score += 20 }
        if deal.source == .priceDrop { score += 10 }
        if deal.source == .receipt { score += 8 }
        if deal.source == .chainCatalog { score += 5 }
        if deal.savings > 5 { score += 5 }

        deal.isTrending = score >= 20
        deal.isRecommended = deal.isRecommended || deal.source == .inventoryMatch
        deal.updatedAt = Date()
    }

    // MARK: - Helpers

    private func fetchDeals(for store: Store, context: ModelContext) -> [Deal] {
        let all = (try? context.fetch(FetchDescriptor<Deal>())) ?? []
        return all.filter { $0.storeID == store.id || $0.storeName == store.name }
    }

    private func fetchDealsByName(_ name: String, context: ModelContext) -> [Deal] {
        (try? context.fetch(FetchDescriptor<Deal>())) ?? []
    }

    private func dealsMatch(_ deal: Deal, item: InventoryItem) -> Bool {
        deal.productName.localizedCaseInsensitiveCompare(item.name) == .orderedSame
    }

    private func recommendationNote(for item: InventoryItem) -> String {
        if item.isExpiringSoon { return "Expiring soon — check for markdowns." }
        if item.isLowStock {
            if let days = item.daysUntilRunOut {
                return "You may run out in ~\(days) days."
            }
            return "Running low in your inventory."
        }
        return "On your favorites list."
    }

    private func averageRecentPrice(for productName: String, storeName: String, context: ModelContext) -> Double? {
        let lineItems = (try? context.fetch(FetchDescriptor<ReceiptLineItem>())) ?? []
        let receipts = (try? context.fetch(FetchDescriptor<Receipt>())) ?? []
            .filter { $0.storeName == storeName }
            .sorted { $0.purchaseDate > $1.purchaseDate }

        let receiptIDs = Set(receipts.prefix(10).map(\.id))
        let matching = lineItems.filter { item in
            receiptIDs.contains(item.receiptID) &&
            (item.productName.localizedCaseInsensitiveCompare(productName) == .orderedSame ||
             productName.localizedCaseInsensitiveContains(item.productName))
        }

        guard matching.count >= 2 else { return nil }
        let total = matching.reduce(0.0) { $0 + $1.unitPrice }
        return total / Double(matching.count)
    }
}
