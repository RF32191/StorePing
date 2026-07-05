//
//  PlayerLevelStore.swift
//  ShelfSense
//

import Foundation
import Observation

struct LevelUpEvent: Equatable {
    let newLevel: Int
    let rankTitle: String
    let xpGained: Int
    let savingsGained: Double
}

@Observable
@MainActor
final class PlayerLevelStore {
    static let shared = PlayerLevelStore()

    private static let totalXPKey = "playerTotalXP"
    private static let lifetimeSavingsKey = "playerLifetimeSavings"
    private static let syncedDealSavingsKey = "playerSyncedDealSavings"

    private(set) var totalXP: Int
    private(set) var lifetimeSavings: Double
    private(set) var level: Int = 1
    private(set) var currentXP: Int = 0
    private(set) var xpToNext: Int = 100
    private(set) var progress: Double = 0
    private(set) var rank: PlayerRank = PlayerLevelService.rank(for: 1)

    var activeLevelUp: LevelUpEvent?
    var recentXPGain: Int?
    var showXPGainToast = false

    private var syncedDealSavings: Double

    private init() {
        totalXP = UserDefaults.standard.integer(forKey: Self.totalXPKey)
        lifetimeSavings = UserDefaults.standard.double(forKey: Self.lifetimeSavingsKey)
        syncedDealSavings = UserDefaults.standard.double(forKey: Self.syncedDealSavingsKey)
        refreshProgress()
    }

    func refreshProgress() {
        let snapshot = PlayerLevelService.progress(totalXP: totalXP)
        level = snapshot.level
        currentXP = snapshot.currentXP
        xpToNext = snapshot.xpToNext
        progress = snapshot.progress
        rank = PlayerLevelService.rank(for: level)
    }

    func recordSavings(_ amount: Double, reason: String = "Saved") {
        guard amount > 0.01 else { return }

        let previousLevel = level
        let xpGain = PlayerLevelService.xpFromSavings(amount)

        lifetimeSavings += amount
        totalXP += xpGain
        refreshProgress()

        UserDefaults.standard.set(totalXP, forKey: Self.totalXPKey)
        UserDefaults.standard.set(lifetimeSavings, forKey: Self.lifetimeSavingsKey)

        QuestStore.shared.recordSavings(amount)
        AchievementXPBridge.checkAfterSavings(totalSavings: lifetimeSavings)

        recentXPGain = xpGain
        showXPGainToast = true
        SpinWheelCelebration.playCoin()

        if level > previousLevel {
            activeLevelUp = LevelUpEvent(
                newLevel: level,
                rankTitle: rank.title,
                xpGained: xpGain,
                savingsGained: amount
            )
            SpinWheelCelebration.playWin()
            HapticManager.success()
        } else {
            HapticManager.lightImpact()
        }

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { showXPGainToast = false }
        }

        WidgetSnapshotSyncService.refreshLevelFields()
    }

    func recordActionXP(_ amount: Int, reason: String = "Action") {
        guard amount > 0 else { return }

        let previousLevel = level
        totalXP += amount
        refreshProgress()
        UserDefaults.standard.set(totalXP, forKey: Self.totalXPKey)

        recentXPGain = amount
        showXPGainToast = true
        SpinWheelCelebration.playCoin()

        if level > previousLevel {
            activeLevelUp = LevelUpEvent(
                newLevel: level,
                rankTitle: rank.title,
                xpGained: amount,
                savingsGained: 0
            )
            SpinWheelCelebration.playWin()
            HapticManager.success()
        } else {
            HapticManager.lightImpact()
        }

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { showXPGainToast = false }
        }

        WidgetSnapshotSyncService.refreshLevelFields()
    }

    func syncDealSavings(_ deals: [Deal]) {
        let active = deals.filter(\.isActive).reduce(0) { $0 + $1.savings }
        let delta = max(0, active - syncedDealSavings)
        syncedDealSavings = active
        UserDefaults.standard.set(syncedDealSavings, forKey: Self.syncedDealSavingsKey)
        if delta > 0.01 {
            recordSavings(delta, reason: "Deal savings")
        }
    }

    func dismissLevelUp() {
        activeLevelUp = nil
    }
}
