//
//  Store.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class Store {
    var id: UUID
    var name: String
    var chainName: String?
    var chainIdentifier: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var isFavorite: Bool
    var notificationRadiusMeters: Double
    var category: String?
    var weeklyAdURL: String?
    var dealsPageURL: String?
    var websiteURL: String?
    var lastDealRefresh: Date?
    var createdAt: Date

    @Transient
    var chain: StoreChain {
        get {
            if let chainIdentifier, let parsed = StoreChain(rawValue: chainIdentifier) {
                return parsed
            }
            return StoreChain.from(name: name)
        }
        set { chainIdentifier = newValue.rawValue }
    }

    @Transient
    var needsDealRefresh: Bool {
        guard let lastDealRefresh else { return true }
        return Date().timeIntervalSince(lastDealRefresh) > 60 * 60 * 12
    }

    init(
        name: String,
        chainName: String? = nil,
        chain: StoreChain? = nil,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isFavorite: Bool = false,
        notificationRadiusMeters: Double = 500,
        category: String? = nil,
        weeklyAdURL: String? = nil,
        dealsPageURL: String? = nil,
        websiteURL: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.chainName = chainName ?? chain?.displayName
        self.chainIdentifier = chain?.rawValue ?? StoreChain.from(name: name).rawValue
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.isFavorite = isFavorite
        self.notificationRadiusMeters = notificationRadiusMeters
        self.category = category
        self.weeklyAdURL = weeklyAdURL ?? chain?.weeklyAdURL?.absoluteString
        self.dealsPageURL = dealsPageURL ?? chain?.dealsPageURL?.absoluteString
        self.websiteURL = websiteURL
        self.lastDealRefresh = nil
        self.createdAt = Date()
    }
}
