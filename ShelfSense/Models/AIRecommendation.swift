//
//  AIRecommendation.swift
//  ShelfSense
//

import Foundation

struct AIRecommendation: Identifiable, Sendable {
    let id: UUID
    let title: String
    let message: String
    let savingsEstimate: Double?
    let confidence: Double
    let storeName: String?
    let productName: String?
    let createdAt: Date

    init(
        title: String,
        message: String,
        savingsEstimate: Double? = nil,
        confidence: Double = 0.85,
        storeName: String? = nil,
        productName: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.message = message
        self.savingsEstimate = savingsEstimate
        self.confidence = confidence
        self.storeName = storeName
        self.productName = productName
        self.createdAt = Date()
    }

    var confidenceLabel: String {
        switch confidence {
        case 0.9...: "High confidence"
        case 0.7..<0.9: "Medium confidence"
        default: "Low confidence"
        }
    }
}

struct AppNotificationItem: Identifiable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let icon: String
    let timestamp: Date
    let isRead: Bool

    init(title: String, body: String, icon: String = "bell.fill", timestamp: Date = Date(), isRead: Bool = false) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.icon = icon
        self.timestamp = timestamp
        self.isRead = isRead
    }
}

struct FamilyActivityItem: Identifiable, Sendable {
    let id: UUID
    let memberName: String
    let action: String
    let itemName: String
    let timestamp: Date

    init(memberName: String, action: String, itemName: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.memberName = memberName
        self.action = action
        self.itemName = itemName
        self.timestamp = timestamp
    }
}
