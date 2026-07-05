//
//  PantryReportService.swift
//  ShelfSense
//

import Foundation

struct PantryReport {
    let generatedAt: Date
    let inventoryCount: Int
    let inventoryValue: Double
    let monthlySpent: Double
    let monthlySavings: Double
    let wasteLogged: Double
    let topStores: [(name: String, visits: Int)]
    let expiringCount: Int
    let lowStockCount: Int
    let achievementsUnlocked: Int
    let achievementsTotal: Int

    var summaryText: String {
        """
        \(AppBrand.name) Pantry Report
        Generated: \(generatedAt.formatted(date: .long, time: .shortened))

        INVENTORY
        • \(inventoryCount) items tracked
        • Est. value: \(Formatters.currencyString(inventoryValue))
        • \(lowStockCount) running low
        • \(expiringCount) expiring soon

        FINANCE
        • Spent this month: \(Formatters.currencyString(monthlySpent))
        • Deal savings: \(Formatters.currencyString(monthlySavings))
        • Waste logged: \(Formatters.currencyString(wasteLogged))

        TOP STORES
        \(topStores.prefix(5).map { "• \($0.name) — \($0.visits) visit\($0.visits == 1 ? "" : "s")" }.joined(separator: "\n"))

        ACHIEVEMENTS
        • \(achievementsUnlocked) of \(achievementsTotal) unlocked
        """
    }
}

enum PantryReportService {
    static func generate(
        inventory: [InventoryItem],
        receipts: [Receipt],
        deals: [Deal],
        waste: [WasteEntry],
        achievements: [Achievement]
    ) -> PantryReport {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        let monthlyReceipts = receipts.filter { $0.purchaseDate >= monthStart }
        let storeVisits = Dictionary(grouping: monthlyReceipts, by: \.storeName).map { ($0.key, $0.value.count) }

        return PantryReport(
            generatedAt: Date(),
            inventoryCount: inventory.count,
            inventoryValue: inventory.compactMap(\.purchasePrice).reduce(0, +),
            monthlySpent: monthlyReceipts.reduce(0) { $0 + $1.total },
            monthlySavings: deals.filter(\.isActive).reduce(0) { $0 + $1.savings },
            wasteLogged: waste.compactMap(\.estimatedValue).reduce(0, +),
            topStores: storeVisits.sorted { $0.1 > $1.1 }.map { (name: $0.0, visits: $0.1) },
            expiringCount: inventory.filter { $0.isExpiringSoon }.count,
            lowStockCount: inventory.filter { $0.isLowStock }.count,
            achievementsUnlocked: AchievementService.unlockedCount(from: achievements),
            achievementsTotal: achievements.count
        )
    }
}
