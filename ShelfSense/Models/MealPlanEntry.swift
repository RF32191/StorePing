//
//  MealPlanEntry.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class MealPlanEntry {
    var id: UUID
    var recipeID: String
    var recipeName: String
    var scheduledDate: Date
    var mealTypeRaw: String
    var isCompleted: Bool
    var createdAt: Date
    var household: Household?

    @Transient
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .dinner }
        set { mealTypeRaw = newValue.rawValue }
    }

    init(recipeID: String, recipeName: String, scheduledDate: Date, mealType: MealType = .dinner) {
        self.id = UUID()
        self.recipeID = recipeID
        self.recipeName = recipeName
        self.scheduledDate = scheduledDate
        self.mealTypeRaw = mealType.rawValue
        self.isCompleted = false
        self.createdAt = Date()
    }
}

enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        }
    }
}
