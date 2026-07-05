//
//  PlayerLevelService.swift
//  ShelfSense
//

import Foundation

struct PlayerRank: Sendable {
    let level: Int
    let title: String
    let icon: String
}

enum PlayerLevelService {
    static let xpPerDollarSaved = 15

    static func rank(for level: Int) -> PlayerRank {
        let titles: [(Int, String, String)] = [
            (1, "Cart Rookie", "cart"),
            (3, "Aisle Explorer", "figure.walk"),
            (5, "Deal Scout", "binoculars.fill"),
            (8, "Smart Shopper", "sparkles"),
            (12, "Bargain Hunter", "tag.fill"),
            (16, "Savings Striker", "bolt.fill"),
            (20, "Pantry Pro", "archivebox.fill"),
            (25, "Coupon Commander", "ticket.fill"),
            (30, "\(AppBrand.name) Legend", "crown.fill"),
            (40, "Master Saver", "star.fill")
        ]

        var chosen = titles[0]
        for entry in titles where level >= entry.0 {
            chosen = entry
        }

        return PlayerRank(level: level, title: chosen.1, icon: chosen.2)
    }

    static func xpRequired(for level: Int) -> Int {
        100 + max(level - 1, 0) * 80
    }

    static func progress(totalXP: Int) -> (level: Int, currentXP: Int, xpToNext: Int, progress: Double) {
        var level = 1
        var remaining = max(totalXP, 0)

        while remaining >= xpRequired(for: level) {
            remaining -= xpRequired(for: level)
            level += 1
        }

        let needed = xpRequired(for: level)
        let progress = needed > 0 ? Double(remaining) / Double(needed) : 0
        return (level, remaining, needed, min(progress, 1))
    }

    static func xpFromSavings(_ dollars: Double) -> Int {
        max(Int(dollars * Double(xpPerDollarSaved)), 0)
    }
}
