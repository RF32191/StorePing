//
//  PriceAlertService.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum PriceAlertService {
    static var notifyPriceAlerts: Bool {
        get { UserDefaults.standard.object(forKey: "notifyPriceAlerts") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notifyPriceAlerts") }
    }

    static func evaluate(deals: [Deal], alerts: [PriceAlert]) {
        guard notifyPriceAlerts else { return }

        for alert in alerts where alert.isEnabled {
            let matches = deals.filter { deal in
                deal.isActive &&
                matchesName(deal.productName, alert: alert) &&
                (alert.storeName == nil || deal.storeName == alert.storeName)
            }

            guard let best = matches.min(by: { $0.salePrice < $1.salePrice }) else { continue }

            alert.lastKnownPrice = best.salePrice

            guard best.salePrice <= alert.targetPrice else { continue }

            let recentlyTriggered = alert.lastTriggeredAt.map {
                Date().timeIntervalSince($0) < 3600 * 6
            } ?? false
            guard !recentlyTriggered else { continue }

            let brand = alert.brand.map { "\($0) " } ?? ""
            LocalNotificationService.postPriceAlert(
                title: "Price alert: \(alert.productName)",
                body: "\(brand)now \(Formatters.currencyString(best.salePrice)) at \(best.storeName) — target \(Formatters.currencyString(alert.targetPrice))",
                alertID: alert.id
            )
            alert.lastTriggeredAt = Date()
        }
    }

    private static func matchesName(_ productName: String, alert: PriceAlert) -> Bool {
        let name = productName.lowercased()
        let query = alert.productName.lowercased()
        if let brand = alert.brand?.lowercased(), !brand.isEmpty {
            return name.contains(query) && name.contains(brand)
        }
        return name.contains(query) || query.contains(name)
    }
}
