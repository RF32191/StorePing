//
//  WalmartProductSearchService.swift
//  ShelfSense
//

import Foundation

enum WalmartProductSearchService {
    static func search(query: String) async -> [ItemSearchOffer] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://www.walmart.com/search?q=\(encoded)"),
              let html = await HTMLDealParser.fetchHTML(from: url) else { return [] }

        return parseProducts(from: html, query: query)
    }

    private static func parseProducts(from html: String, query: String) -> [ItemSearchOffer] {
        var offers: [ItemSearchOffer] = []
        let pattern = #""name":"([^"]{8,120})".{0,6000}?"averageRating":([\d.]+).{0,200}?"numberOfReviews":([0-9]+).{0,3500}?"linePrice":"\$([\d.]+)""#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var seen = Set<String>()

        regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 5,
                  let nameRange = Range(match.range(at: 1), in: html),
                  let ratingRange = Range(match.range(at: 2), in: html),
                  let reviewsRange = Range(match.range(at: 3), in: html),
                  let priceRange = Range(match.range(at: 4), in: html) else { return }

            let name = String(html[nameRange])
            let lower = name.lowercased()
            guard !lower.contains("fulfillment"), !lower.contains("module"), !lower.contains("config") else { return }
            guard seen.insert(name.lowercased()).inserted else { return }

            guard let rating = Double(html[ratingRange]),
                  let reviews = Int(html[reviewsRange]),
                  let price = Double(html[priceRange]), price > 0 else { return }

            let chunkRange = match.range
            let chunk = (html as NSString).substring(with: chunkRange)
            let wasPrice = extractWasPrice(from: chunk)
            let brand = extractBrand(from: name)

            offers.append(ItemSearchOffer(
                id: "walmart-\(name.hashValue)-\(offers.count)",
                productName: name,
                brand: brand,
                price: price,
                originalPrice: wasPrice,
                rating: rating,
                reviewCount: reviews,
                storeName: "Walmart",
                source: .walmart,
                distanceMeters: nil,
                productURL: URL(string: "https://www.walmart.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"),
                imageURL: nil,
                notes: wasPrice != nil ? "Save \(Formatters.currencyString((wasPrice ?? price) - price)) online" : "Walmart online price"
            ))
        }

        return Array(offers.prefix(12))
    }

    private static func extractWasPrice(from chunk: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #""wasPrice":"\$([\d.]+)""#),
              let match = regex.firstMatch(in: chunk, range: NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: chunk) else { return nil }

        return Double(String(chunk[range]))
    }

    private static func extractBrand(from name: String) -> String? {
        let prefixes = ["Great Value", "Horizon Organic", "Marketside", "Freshness Guaranteed", "Equate", "Parent's Choice"]
        for prefix in prefixes where name.localizedCaseInsensitiveContains(prefix) {
            return prefix
        }
        return name.components(separatedBy: " ").prefix(2).joined(separator: " ")
    }
}
