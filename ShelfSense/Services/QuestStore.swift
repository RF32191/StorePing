//
//  QuestStore.swift
//  ShelfSense
//

import Foundation
import Observation

enum QuestKind: String, Codable, CaseIterable, Identifiable {
    case addListItems
    case completeListItems
    case scanReceipt
    case checkDeals
    case saveMoney
    case weeklyBoss

    var id: String { rawValue }

    var isWeekly: Bool { self == .weeklyBoss }
}

struct QuestDefinition: Identifiable {
    let id: QuestKind
    let title: String
    let subtitle: String
    let icon: String
    let target: Int
    let xpReward: Int
    let isWeekly: Bool
}

struct QuestProgress: Identifiable {
    let definition: QuestDefinition
    let current: Int
    let isComplete: Bool
    let claimed: Bool

    var id: QuestKind { definition.id }
    var progress: Double {
        guard definition.target > 0 else { return 0 }
        return min(Double(current) / Double(definition.target), 1)
    }
}

@Observable
@MainActor
final class QuestStore {
    static let shared = QuestStore()

    private static let dailyDateKey = "questDailyDate"
    private static let dailyProgressKey = "questDailyProgress"
    private static let weeklyDateKey = "questWeeklyDate"
    private static let weeklyProgressKey = "questWeeklyProgress"
    private static let claimedKey = "questClaimedToday"
    private static let streakKey = "questStreakDays"

    private(set) var dailyProgress: [QuestKind: Int] = [:]
    private(set) var weeklyProgress: [QuestKind: Double] = [:]
    private(set) var claimedToday: Set<QuestKind> = []
    private(set) var streakDays: Int = 0

    static let dailyQuests: [QuestDefinition] = [
        QuestDefinition(id: .addListItems, title: "List Builder", subtitle: "Add 3 items to your list", icon: "cart.badge.plus", target: 3, xpReward: 25, isWeekly: false),
        QuestDefinition(id: .completeListItems, title: "Shop & Check", subtitle: "Complete 5 list items", icon: "checkmark.circle.fill", target: 5, xpReward: 40, isWeekly: false),
        QuestDefinition(id: .scanReceipt, title: "Receipt Scanner", subtitle: "Scan 1 receipt", icon: "doc.text.viewfinder", target: 1, xpReward: 50, isWeekly: false),
        QuestDefinition(id: .checkDeals, title: "Deal Hunter", subtitle: "Refresh or view deals", icon: "tag.fill", target: 1, xpReward: 20, isWeekly: false)
    ]

    static let weeklyQuest: QuestDefinition = QuestDefinition(
        id: .weeklyBoss,
        title: "Weekly Boss",
        subtitle: "Save $20 this week",
        icon: "crown.fill",
        target: 20,
        xpReward: 200,
        isWeekly: true
    )

    private init() {
        refreshIfNeeded()
    }

    func refreshIfNeeded() {
        let today = Self.dayKey(Date())
        let savedDay = UserDefaults.standard.string(forKey: Self.dailyDateKey) ?? ""
        if savedDay != today {
            if !savedDay.isEmpty, allDailyComplete(on: savedDay) {
                streakDays = UserDefaults.standard.integer(forKey: Self.streakKey) + 1
            } else if !savedDay.isEmpty {
                streakDays = 0
            }
            UserDefaults.standard.set(streakDays, forKey: Self.streakKey)
            UserDefaults.standard.set(today, forKey: Self.dailyDateKey)
            dailyProgress = [:]
            claimedToday = []
            persistDaily()
            persistClaimed()
        } else {
            loadDaily()
            loadClaimed()
            streakDays = UserDefaults.standard.integer(forKey: Self.streakKey)
        }

        let week = Self.weekKey(Date())
        let savedWeek = UserDefaults.standard.string(forKey: Self.weeklyDateKey) ?? ""
        if savedWeek != week {
            UserDefaults.standard.set(week, forKey: Self.weeklyDateKey)
            weeklyProgress = [:]
            persistWeekly()
        } else {
            loadWeekly()
        }
    }

    var allQuests: [QuestProgress] {
        var list = Self.dailyQuests.map { def in
            QuestProgress(
                definition: def,
                current: dailyProgress[def.id] ?? 0,
                isComplete: (dailyProgress[def.id] ?? 0) >= def.target,
                claimed: claimedToday.contains(def.id)
            )
        }
        let weekly = Self.weeklyQuest
        list.append(QuestProgress(
            definition: weekly,
            current: Int(weeklyProgress[.weeklyBoss] ?? 0),
            isComplete: (weeklyProgress[.weeklyBoss] ?? 0) >= Double(weekly.target),
            claimed: claimedToday.contains(.weeklyBoss)
        ))
        return list
    }

    var completedCount: Int {
        allQuests.filter(\.isComplete).count
    }

    func increment(_ kind: QuestKind, by amount: Int = 1) {
        refreshIfNeeded()
        guard !kind.isWeekly else { return }
        dailyProgress[kind, default: 0] += amount
        persistDaily()
    }

    func recordSavings(_ dollars: Double) {
        refreshIfNeeded()
        weeklyProgress[.weeklyBoss, default: 0] += dollars
        persistWeekly()
        increment(.saveMoney)
    }

    func claim(_ kind: QuestKind) {
        guard let quest = allQuests.first(where: { $0.id == kind }),
              quest.isComplete,
              !quest.claimed else { return }

        claimedToday.insert(kind)
        persistClaimed()

        var xp = quest.definition.xpReward
        if streakDays >= 3 { xp = Int(Double(xp) * 1.25) }
        if streakDays >= 7 { xp = Int(Double(xp) * 1.5) }

        PlayerLevelStore.shared.recordActionXP(xp, reason: quest.definition.title)
        HapticManager.success()
    }

    func claimAllAvailable() {
        for quest in allQuests where quest.isComplete && !quest.claimed {
            claim(quest.id)
        }
    }

    private func allDailyComplete(on day: String) -> Bool {
        Self.dailyQuests.allSatisfy { (dailyProgress[$0.id] ?? 0) >= $0.target }
    }

    private static func dayKey(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    private static func weekKey(_ date: Date) -> String {
        let cal = Calendar.current
        let week = cal.component(.weekOfYear, from: date)
        let year = cal.component(.yearForWeekOfYear, from: date)
        return "\(year)-W\(week)"
    }

    private func loadDaily() {
        guard let data = UserDefaults.standard.data(forKey: Self.dailyProgressKey),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
        dailyProgress = decoded.reduce(into: [:]) { result, pair in
            if let kind = QuestKind(rawValue: pair.key) { result[kind] = pair.value }
        }
    }

    private func persistDaily() {
        let encoded = dailyProgress.reduce(into: [String: Int]()) { $0[$1.key.rawValue] = $1.value }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: Self.dailyProgressKey)
        }
    }

    private func loadWeekly() {
        guard let data = UserDefaults.standard.data(forKey: Self.weeklyProgressKey),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data) else { return }
        weeklyProgress = decoded.reduce(into: [:]) { result, pair in
            if let kind = QuestKind(rawValue: pair.key) { result[kind] = pair.value }
        }
    }

    private func persistWeekly() {
        let encoded = weeklyProgress.reduce(into: [String: Double]()) { $0[$1.key.rawValue] = $1.value }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: Self.weeklyProgressKey)
        }
    }

    private func loadClaimed() {
        let raw = UserDefaults.standard.stringArray(forKey: Self.claimedKey) ?? []
        claimedToday = Set(raw.compactMap(QuestKind.init(rawValue:)))
    }

    private func persistClaimed() {
        UserDefaults.standard.set(claimedToday.map(\.rawValue), forKey: Self.claimedKey)
    }
}
