//
//  ChainDealFetcherRegistry.swift
//  ShelfSense
//

import Foundation

enum ChainDealFetcherRegistry {
    private static let chainFetchers: [StoreChain: any ChainDealFetcher] = [
        .target: TargetDealFetcher(),
        .walmart: WalmartDealFetcher(),
        .costco: CostcoDealFetcher()
    ]

    private static let genericFetchers: [StoreChain: any ChainDealFetcher] = {
        var map: [StoreChain: any ChainDealFetcher] = [:]
        for chain in StoreChain.allCases where chain != .custom {
            map[chain] = GenericChainDealFetcher(chain: chain)
        }
        return map
    }()

    private static let storeOnlineFetcher = StoreOnlineDealFetcher()

    static func fetcher(for chain: StoreChain) -> (any ChainDealFetcher)? {
        chainFetchers[chain] ?? genericFetchers[chain]
    }

    static func fetchDeals(for store: Store) async -> [FetchedChainDeal] {
        var combined: [FetchedChainDeal] = []

        if let specialized = chainFetchers[store.chain] {
            combined.append(contentsOf: await specialized.fetchDeals(for: store))
        }

        if combined.isEmpty, let generic = genericFetchers[store.chain] {
            combined.append(contentsOf: await generic.fetchDeals(for: store))
        }

        let needsStorePull = store.chain == .custom ||
            store.websiteURL != nil ||
            (store.dealsPageURL != nil && store.dealsPageURL != store.chain.dealsPageURL?.absoluteString)

        if needsStorePull || combined.isEmpty {
            combined.append(contentsOf: await storeOnlineFetcher.fetchDeals(for: store))
        }

        return Array(HTMLDealParser.dedupe(combined).prefix(25))
    }
}
