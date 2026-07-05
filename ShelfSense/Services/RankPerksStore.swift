//
//  RankPerksStore.swift
//  ShelfSense
//

import Foundation

struct RankPerk: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let unlockLevel: Int
}

enum RankPerksStore {
    static let all: [RankPerk] = [
        RankPerk(id: "spin-gold", title: "Gold Wheel", description: "Golden spin wheel theme", icon: "arrow.trianglehead.clockwise", unlockLevel: 5),
        RankPerk(id: "badge-glow", title: "Rank Glow", description: "Glowing level badge on top bar", icon: "sparkles", unlockLevel: 8),
        RankPerk(id: "confetti-copper", title: "Copper Confetti", description: "Copper burst on level up", icon: "party.popper.fill", unlockLevel: 12),
        RankPerk(id: "widget-legend", title: "Legend Widgets", description: "Premium dashboard widget styles", icon: "square.grid.2x2.fill", unlockLevel: 20),
        RankPerk(id: "spin-double", title: "Double or Nothing", description: "Unlock spin wheel gamble mode", icon: "dice.fill", unlockLevel: 15),
        RankPerk(id: "title-master", title: "Master Title", description: "Exclusive Master Saver flair", icon: "crown.fill", unlockLevel: 30)
    ]

    static func unlocked(for level: Int) -> [RankPerk] {
        all.filter { level >= $0.unlockLevel }
    }

    static func isUnlocked(_ perkID: String, level: Int) -> Bool {
        all.first { $0.id == perkID }.map { level >= $0.unlockLevel } ?? false
    }

    static func nextPerk(for level: Int) -> RankPerk? {
        all.first { level < $0.unlockLevel }
    }
}
