//
//  NearbyStoreAlert.swift
//  ShelfSense
//

import Foundation

struct NearbyStoreAlert: Identifiable, Codable, Sendable {
    let id: UUID
    let storeID: UUID
    let storeName: String
    let title: String
    let message: String
    let distanceMeters: Double
    let savingsEstimate: Double?
    let timestamp: Date

    init(
        storeID: UUID,
        storeName: String,
        title: String,
        message: String,
        distanceMeters: Double,
        savingsEstimate: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.storeID = storeID
        self.storeName = storeName
        self.title = title
        self.message = message
        self.distanceMeters = distanceMeters
        self.savingsEstimate = savingsEstimate
        self.timestamp = timestamp
    }

    var distanceLabel: String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters))m"
        }
        let miles = distanceMeters / 1609.34
        return String(format: "%.1f mi", miles)
    }
}

struct NearbyStorePresence: Identifiable, Sendable {
    let id: UUID
    let storeName: String
    let distanceMeters: Double
    let isInsideGeofence: Bool
    let subtitle: String

    var distanceLabel: String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters))m"
        }
        let miles = distanceMeters / 1609.34
        return String(format: "%.1f mi", miles)
    }
}
