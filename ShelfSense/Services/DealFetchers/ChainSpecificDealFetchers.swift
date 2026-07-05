//
//  ChainSpecificDealFetchers.swift
//  ShelfSense
//

import Foundation

struct WalmartDealFetcher: ChainDealFetcher {
    let chain: StoreChain = .walmart

    func fetchDeals(for store: Store) async -> [FetchedChainDeal] {
        let urlString = store.dealsPageURL ?? chain.dealsPageURL?.absoluteString
        guard let urlString, let url = URL(string: urlString) else { return [] }
        guard let html = await HTMLDealParser.fetchHTML(from: url) else { return [] }
        return HTMLDealParser.parseWalmartPriceInfo(from: html, sourceURL: url.absoluteString)
    }
}

struct TargetDealFetcher: ChainDealFetcher {
    let chain: StoreChain = .target

    func fetchDeals(for store: Store) async -> [FetchedChainDeal] {
        let candidates = [
            store.dealsPageURL,
            store.weeklyAdURL,
            chain.dealsPageURL?.absoluteString,
            "https://www.target.com/c/top-deals/-/N-4xw74",
            "https://www.target.com/c/circle-deals/-/N-4xw74"
        ]

        var combined: [FetchedChainDeal] = []

        for urlString in candidates.compactMap({ $0 }).uniqued() {
            guard let url = URL(string: urlString),
                  let html = await HTMLDealParser.fetchHTML(from: url) else { continue }

            let promos = HTMLDealParser.parseTargetPromotions(from: html, sourceURL: url.absoluteString)
            combined.append(contentsOf: promos)

            let embedded = HTMLDealParser.parseEmbeddedProductPrices(from: html, sourceURL: url.absoluteString)
            combined.append(contentsOf: embedded)

            if combined.count >= 20 { break }
        }

        return Array(HTMLDealParser.dedupe(combined).prefix(20))
    }
}

struct CostcoDealFetcher: ChainDealFetcher {
    let chain: StoreChain = .costco

    func fetchDeals(for store: Store) async -> [FetchedChainDeal] {
        let urlString = store.dealsPageURL ?? chain.dealsPageURL?.absoluteString
        guard let urlString, let url = URL(string: urlString) else { return [] }
        guard let html = await HTMLDealParser.fetchHTML(from: url) else { return [] }
        return HTMLDealParser.parseAllDeals(from: html, sourceURL: url.absoluteString)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
