//
//  StoreChain.swift
//  ShelfSense
//

import Foundation

enum StoreChain: String, Codable, CaseIterable, Identifiable, Sendable {
    case costco
    case target
    case walmart
    case traderJoes
    case wholeFoods
    case cvs
    case walgreens
    case kroger
    case homeDepot
    case lowes
    case bestBuy
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .costco: "Costco"
        case .target: "Target"
        case .walmart: "Walmart"
        case .traderJoes: "Trader Joe's"
        case .wholeFoods: "Whole Foods"
        case .cvs: "CVS"
        case .walgreens: "Walgreens"
        case .kroger: "Kroger"
        case .homeDepot: "Home Depot"
        case .lowes: "Lowe's"
        case .bestBuy: "Best Buy"
        case .custom: "Custom Store"
        }
    }

    var icon: String {
        switch self {
        case .costco, .walmart, .kroger: "cart.fill"
        case .target: "target"
        case .traderJoes, .wholeFoods: "leaf.fill"
        case .cvs, .walgreens: "cross.case.fill"
        case .homeDepot, .lowes: "hammer.fill"
        case .bestBuy: "desktopcomputer"
        case .custom: "storefront.fill"
        }
    }

    /// Public weekly ad or deals landing page for each chain.
    var weeklyAdURL: URL? {
        switch self {
        case .costco: URL(string: "https://www.costco.com/weekly-offers.html")
        case .target: URL(string: "https://www.target.com/c/top-deals/-/N-4xw74")
        case .walmart: URL(string: "https://www.walmart.com/shop/deals")
        case .traderJoes: URL(string: "https://www.traderjoes.com/home")
        case .wholeFoods: URL(string: "https://www.amazon.com/fmc/deals")
        case .cvs: URL(string: "https://www.cvs.com/weeklyad")
        case .walgreens: URL(string: "https://www.walgreens.com/offers/offers.jsp")
        case .kroger: URL(string: "https://www.kroger.com/savings/cl/coupons/")
        case .homeDepot: URL(string: "https://www.homedepot.com/c/Specials")
        case .lowes: URL(string: "https://www.lowes.com/l/save")
        case .bestBuy: URL(string: "https://www.bestbuy.com/site/electronics/top-deals/pcmcat1563299784494.c")
        case .custom: nil
        }
    }

    var dealsPageURL: URL? { weeklyAdURL }

    static func from(name: String) -> StoreChain {
        let normalized = name.lowercased()
        for chain in StoreChain.allCases where chain != .custom {
            if normalized.contains(chain.displayName.lowercased()) ||
                normalized.contains(chain.rawValue.lowercased()) {
                return chain
            }
        }
        if normalized.contains("trader") { return .traderJoes }
        if normalized.contains("whole") { return .wholeFoods }
        if normalized.contains("home depot") { return .homeDepot }
        if normalized.contains("best buy") { return .bestBuy }
        return .custom
    }
}

enum DealSource: String, Codable, CaseIterable, Sendable {
    case manual
    case weeklyAd
    case chainCatalog
    case receipt
    case inventoryMatch
    case priceDrop
    case coupon

    var displayName: String {
        switch self {
        case .manual: "Added by you"
        case .weeklyAd: "Weekly ad"
        case .chainCatalog: "Store catalog"
        case .receipt: "From receipt"
        case .inventoryMatch: "Matches your inventory"
        case .priceDrop: "Price drop"
        case .coupon: "Coupon"
        }
    }

    var icon: String {
        switch self {
        case .manual: "pencil.circle.fill"
        case .weeklyAd: "newspaper.fill"
        case .chainCatalog: "storefront.fill"
        case .receipt: "doc.text.fill"
        case .inventoryMatch: "archivebox.fill"
        case .priceDrop: "arrow.down.circle.fill"
        case .coupon: "ticket.fill"
        }
    }
}
