//
//  StoreOnlineDealFetcher.swift
//  ShelfSense
//

import Foundation

enum StoreDealsURLResolver {
    static func candidateURLs(for store: Store) -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()

        func append(_ string: String?) {
            guard let string, let url = URL(string: string), seen.insert(url.absoluteString).inserted else { return }
            urls.append(url)
        }

        append(store.dealsPageURL)
        append(store.weeklyAdURL)
        append(store.websiteURL)
        append(store.chain.dealsPageURL?.absoluteString)
        append(store.chain.weeklyAdURL?.absoluteString)

        if store.chain == .custom {
            for guessed in guessedDealURLs(for: store.name) {
                append(guessed.absoluteString)
            }
        }

        return urls
    }

    private static func guessedDealURLs(for storeName: String) -> [URL] {
        let slug = storeName
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)

        guard slug.count >= 4 else { return [] }

        let hosts = [
            "https://www.\(slug).com/deals",
            "https://www.\(slug).com/specials",
            "https://www.\(slug).com/savings",
            "https://\(slug).com/deals"
        ]

        return hosts.compactMap(URL.init(string:))
    }
}

struct StoreOnlineDealFetcher: ChainDealFetcher {
    let chain: StoreChain = .custom

    func fetchDeals(for store: Store) async -> [FetchedChainDeal] {
        let urls = StoreDealsURLResolver.candidateURLs(for: store)
        guard !urls.isEmpty else { return [] }

        var combined: [FetchedChainDeal] = []

        for url in urls.prefix(4) {
            guard let html = await HTMLDealParser.fetchHTML(from: url) else { continue }
            let parsed = HTMLDealParser.parseAllDeals(from: html, sourceURL: url.absoluteString)
            combined.append(contentsOf: parsed)
            if combined.count >= 20 { break }
        }

        return Array(HTMLDealParser.dedupe(combined).prefix(20))
    }
}
