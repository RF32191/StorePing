//
//  CouponMatchService.swift
//  ShelfSense
//

import Foundation

struct CouponMatch: Identifiable {
    let id: UUID
    let couponTitle: String
    let storeName: String?
    let matchedItemName: String
    let estimatedSavings: Double
}

enum CouponMatchService {
    static func matches(coupons: [Coupon], listItems: [ShoppingListItem]) -> [CouponMatch] {
        let active = listItems.filter { !$0.isCompleted }
        var results: [CouponMatch] = []

        for coupon in coupons where !coupon.isUsed {
            let keyword = (coupon.productName ?? coupon.title).lowercased()
            guard !keyword.isEmpty else { continue }
            for item in active where item.name.lowercased().contains(keyword) {
                let savings = coupon.discountAmount ?? item.estimatedPrice.map { min($0, coupon.discountAmount ?? $0) } ?? 1
                results.append(CouponMatch(
                    id: UUID(),
                    couponTitle: coupon.title,
                    storeName: coupon.storeName,
                    matchedItemName: item.name,
                    estimatedSavings: savings
                ))
            }
        }

        return results.sorted { $0.estimatedSavings > $1.estimatedSavings }
    }
}
