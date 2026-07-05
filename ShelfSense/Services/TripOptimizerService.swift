//
//  TripOptimizerService.swift
//  ShelfSense
//

import Foundation

struct StoreTripPlan: Identifiable {
    let id = UUID()
    let storeName: String
    let items: [ShoppingListItem]
    let estimatedTotal: Double
    let dealSavings: Double
    let itemCount: Int
}

enum TripOptimizerService {
    static func optimize(listItems: [ShoppingListItem], deals: [Deal], stores: [Store]) -> [StoreTripPlan] {
        guard !listItems.isEmpty else { return [] }

        let activeItems = listItems.filter { !$0.isCompleted }
        var plans: [StoreTripPlan] = []

        for store in stores {
            let storeDeals = deals.filter { $0.storeName == store.name && $0.isActive }
            var matched: [ShoppingListItem] = []
            var total: Double = 0
            var savings: Double = 0

            for item in activeItems {
                if let deal = storeDeals.first(where: { d in dealMatches(d, item: item) }) {
                    matched.append(item)
                    total += deal.salePrice * item.quantity
                    savings += deal.savings * item.quantity
                } else if let price = item.estimatedPrice {
                    matched.append(item)
                    total += price * item.quantity
                }
            }

            if !matched.isEmpty {
                plans.append(StoreTripPlan(
                    storeName: store.name,
                    items: matched,
                    estimatedTotal: total,
                    dealSavings: savings,
                    itemCount: matched.count
                ))
            }
        }

        return plans.sorted { lhs, rhs in
            if lhs.itemCount != rhs.itemCount { return lhs.itemCount > rhs.itemCount }
            return lhs.estimatedTotal < rhs.estimatedTotal
        }
    }

    static func bestSplit(plans: [StoreTripPlan], totalItems: Int) -> (plans: [StoreTripPlan], uncovered: Int) {
        guard !plans.isEmpty else { return ([], totalItems) }
        var covered = Set<UUID>()
        var selected: [StoreTripPlan] = []

        for plan in plans.sorted(by: { $0.itemCount > $1.itemCount }) {
            let newItems = plan.items.filter { !covered.contains($0.id) }
            if !newItems.isEmpty {
                selected.append(plan)
                newItems.forEach { covered.insert($0.id) }
            }
        }

        return (selected, totalItems - covered.count)
    }

    private static func dealMatches(_ deal: Deal, item: ShoppingListItem) -> Bool {
        let dealName = deal.productName.lowercased()
        let itemName = item.name.lowercased()
        if dealName.contains(itemName) || itemName.contains(dealName) { return true }
        if let brand = item.brand?.lowercased(), dealName.contains(brand) { return true }
        return false
    }
}
