//
//  TargetProductSearchService.swift
//  ShelfSense
//

import Foundation

enum TargetProductSearchService {
    static func search(query: String) async -> [ItemSearchOffer] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://www.target.com/s?searchTerm=\(encoded)"),
              let html = await HTMLDealParser.fetchHTML(from: url) else { return [] }

        return parseProducts(from: html, query: query)
    }

    private static func parseProducts(from html: String, query: String) -> [ItemSearchOffer] {
        var offers: [ItemSearchOffer] = []
        var seen = Set<String>()

        let patterns = [
            #""title":"([^"]{8,120})".{0,2000}?"formatted_current_price":"\$([\d.]+)".{0,400}?"formatted_comparison_price":"\$([\d.]+)""#,
            #""title":"([^"]{8,120})".{0,2000}?"current_retail":([\d.]+).{0,300}?"reg_retail":([\d.]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)

            regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges >= 4,
                      let nameRange = Range(match.range(at: 1), in: html),
                      let saleRange = Range(match.range(at: 2), in: html),
                      let originalRange = Range(match.range(at: 3), in: html) else { return }

                let name = decode(String(html[nameRange]))
                guard !isNoise(name), seen.insert(name.lowercased()).inserted else { return }
                guard let sale = Double(html[saleRange]),
                      let original = Double(html[originalRange]),
                      sale > 0, original >= sale else { return }

                offers.append(ItemSearchOffer(
                    id: "target-\(name.hashValue)-\(offers.count)",
                    productName: name,
                    brand: extractBrand(from: name),
                    price: sale,
                    originalPrice: original > sale ? original : nil,
                    rating: nil,
                    reviewCount: nil,
                    storeName: "Target",
                    source: .target,
                    distanceMeters: nil,
                    productURL: URL(string: "https://www.target.com/s?searchTerm=\(encodedQuery(query))"),
                    imageURL: nil,
                    notes: original > sale ? "Save \(Formatters.currencyString(original - sale)) at Target" : "Target online price"
                ))
            }
        }

        return Array(offers.prefix(12))
    }

    private static func encodedQuery(_ query: String) -> String {
        query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    }

    private static func decode(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\/", with: "/")
    }

    private static func isNoise(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("placeholder") || lower.contains("navigation") || lower.hasPrefix("2026_")
    }

    private static func extractBrand(from name: String) -> String? {
        let brands = ["Good & Gather", "Market Pantry", "Up & Up", "Horizon", "Silk", "Starbucks"]
        for brand in brands where name.localizedCaseInsensitiveContains(brand) { return brand }
        return name.components(separatedBy: " ").prefix(2).joined(separator: " ")
    }
}
