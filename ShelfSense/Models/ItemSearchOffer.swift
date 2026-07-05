//
//  ItemSearchOffer.swift
//  ShelfSense
//

import Foundation

enum ItemSearchSource: String, Sendable, CaseIterable {
    case amazon
    case walmart
    case target
    case nearbyStore
    case savedDeal
    case receiptHistory
    case openFoodFacts
    case pantry

    var displayName: String {
        switch self {
        case .amazon: "Amazon"
        case .walmart: "Walmart"
        case .target: "Target"
        case .nearbyStore: "Nearby store"
        case .savedDeal: "Your deal"
        case .receiptHistory: "Your receipt"
        case .openFoodFacts: "Product catalog"
        case .pantry: "Your pantry"
        }
    }

    var icon: String {
        switch self {
        case .amazon: "cart.fill"
        case .walmart: "building.2.fill"
        case .target: "target"
        case .nearbyStore: "location.fill"
        case .savedDeal: "tag.fill"
        case .receiptHistory: "doc.text.fill"
        case .openFoodFacts: "leaf.fill"
        case .pantry: "archivebox.fill"
        }
    }
}

struct ItemSearchOffer: Identifiable, Sendable, Hashable {
    let id: String
    let productName: String
    let brand: String?
    let price: Double
    let originalPrice: Double?
    let rating: Double?
    let reviewCount: Int?
    let storeName: String
    let source: ItemSearchSource
    let distanceMeters: Double?
    let productURL: URL?
    let imageURL: URL?
    let notes: String?

    var savings: Double {
        guard let originalPrice, originalPrice > price else { return 0 }
        return originalPrice - price
    }

    var hasPrice: Bool { price > 0 }
}

struct ItemSearchResults: Sendable {
    let query: String
    let offers: [ItemSearchOffer]
    let brands: [String]
    let searchedAt: Date

    var pricedOffers: [ItemSearchOffer] {
        offers.filter(\.hasPrice).sorted { $0.price < $1.price }
    }

    var amazonOffers: [ItemSearchOffer] {
        offers.filter { $0.source == .amazon && $0.hasPrice }
            .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }

    var walmartOffers: [ItemSearchOffer] {
        offers.filter { $0.source == .walmart && $0.hasPrice }
            .sorted { $0.price < $1.price }
    }

    var targetOffers: [ItemSearchOffer] {
        offers.filter { $0.source == .target && $0.hasPrice }
            .sorted { $0.price < $1.price }
    }

    var pantryOffers: [ItemSearchOffer] {
        offers.filter { $0.source == .pantry }
    }

    var nearbyOffers: [ItemSearchOffer] {
        offers.filter { $0.source == .nearbyStore || $0.source == .savedDeal || $0.source == .receiptHistory }
            .sorted {
                ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude)
            }
    }

    var catalogProducts: [ItemSearchOffer] {
        offers.filter { $0.source == .openFoodFacts }
    }

    var cheapest: ItemSearchOffer? { pricedOffers.first }
}
