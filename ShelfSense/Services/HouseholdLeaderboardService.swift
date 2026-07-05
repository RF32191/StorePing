//
//  HouseholdLeaderboardService.swift
//  ShelfSense
//

import Foundation

struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let weeklySavings: Double
    let completedItems: Int
    let xp: Int
    let rank: Int
}

enum HouseholdLeaderboardService {
    static func entries(
        members: [HouseholdMember],
        listItems: [ShoppingListItem],
        playerXP: Int,
        playerSavings: Double
    ) -> [LeaderboardEntry] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        var scores: [(name: String, savings: Double, completed: Int, xp: Int)] = [
            ("You", playerSavings, listItems.filter { $0.isCompleted && $0.createdAt >= weekAgo }.count, playerXP)
        ]

        for member in members where !member.isCurrentUser {
            let name = member.name
            let completed = listItems.filter {
                $0.isCompleted && $0.assignedTo == name && $0.createdAt >= weekAgo
            }.count
            let estimated = listItems.filter { $0.assignedTo == name && $0.isCompleted }
                .compactMap(\.estimatedPrice).reduce(0, +) * 0.05
            scores.append((name, estimated, completed, completed * 15))
        }

        let sorted = scores.sorted {
            if $0.savings != $1.savings { return $0.savings > $1.savings }
            return $0.completed > $1.completed
        }

        return sorted.enumerated().map { index, score in
            LeaderboardEntry(
                id: score.name,
                name: score.name,
                weeklySavings: score.savings,
                completedItems: score.completed,
                xp: score.xp,
                rank: index + 1
            )
        }
    }
}
