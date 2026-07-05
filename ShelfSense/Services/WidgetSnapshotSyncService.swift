//
//  WidgetSnapshotSyncService.swift
//  ShelfSense
//

import Foundation
import SwiftData
import WidgetKit

@MainActor
enum WidgetSnapshotSyncService {
    static func sync(context: ModelContext) {
        let listItems = (try? context.fetch(FetchDescriptor<ShoppingListItem>())) ?? []
        let inventory = (try? context.fetch(FetchDescriptor<InventoryItem>())) ?? []
        let receipts = (try? context.fetch(FetchDescriptor<Receipt>())) ?? []
        let deals = (try? context.fetch(FetchDescriptor<Deal>())) ?? []

        let activeList = listItems.filter { !$0.isCompleted }
        let expiring = inventory
            .filter { $0.isExpiringSoon || $0.isExpired }
            .sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }

        let player = PlayerLevelStore.shared
        let questStore = QuestStore.shared
        questStore.refreshIfNeeded()

        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        let monthReceiptSavings = receipts
            .filter { $0.purchaseDate >= monthStart }
            .map(\.discounts)
            .reduce(0, +)
        let monthDealSavings = deals.filter(\.isActive).map(\.savings).reduce(0, +)

        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            level: player.level,
            rankTitle: player.rank.title,
            rankIcon: player.rank.icon,
            lifetimeSavings: player.lifetimeSavings,
            xpProgress: player.progress,
            currentXP: player.currentXP,
            xpToNext: player.xpToNext,
            shoppingListItems: activeList.prefix(6).map(\.name),
            shoppingListCount: activeList.count,
            estimatedListTotal: activeList.compactMap(\.estimatedPrice).reduce(0, +),
            expiringItems: expiring.prefix(4).map(\.name),
            expiringCount: expiring.count,
            questsCompleted: questStore.completedCount,
            questsTotal: questStore.allQuests.count,
            questStreak: questStore.streakDays,
            monthlySavings: monthReceiptSavings + monthDealSavings
        )

        WidgetSharedDataStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func refreshLevelFields() {
        var snapshot = WidgetSharedDataStore.load()
        let player = PlayerLevelStore.shared
        snapshot.updatedAt = Date()
        snapshot.level = player.level
        snapshot.rankTitle = player.rank.title
        snapshot.rankIcon = player.rank.icon
        snapshot.lifetimeSavings = player.lifetimeSavings
        snapshot.xpProgress = player.progress
        snapshot.currentXP = player.currentXP
        snapshot.xpToNext = player.xpToNext

        let questStore = QuestStore.shared
        questStore.refreshIfNeeded()
        snapshot.questsCompleted = questStore.completedCount
        snapshot.questsTotal = questStore.allQuests.count
        snapshot.questStreak = questStore.streakDays

        WidgetSharedDataStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
