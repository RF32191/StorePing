//
//  AchievementXPBridge.swift
//  ShelfSense
//

import Foundation

enum AchievementXPBridge {
    private static let awardedKey = "achievementXPAwarded"

    static func xpReward(for achievementID: String) -> Int {
        switch achievementID {
        case "first-receipt": 50
        case "receipt-pro": 150
        case "saver-100": 300
        case "list-master": 200
        case "waste-warrior": 100
        case "streak-4": 175
        default: 25
        }
    }

    static func checkAndAward(achievements: [Achievement]) {
        var awarded = Set(UserDefaults.standard.stringArray(forKey: awardedKey) ?? [])

        for achievement in achievements where achievement.isUnlocked && !awarded.contains(achievement.id) {
            awarded.insert(achievement.id)
            PlayerLevelStore.shared.recordActionXP(xpReward(for: achievement.id), reason: achievement.title)
        }

        UserDefaults.standard.set(Array(awarded), forKey: awardedKey)
    }

    static func checkAfterSavings(totalSavings: Double) {
        if totalSavings >= 100 {
            checkAndAward(achievements: [
                Achievement(id: "saver-100", title: "Smart Saver", description: "", icon: "", isUnlocked: true, progress: 1)
            ])
        }
    }
}
