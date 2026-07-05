//
//  AmazonProductSearchService.swift
//  ShelfSense
//

import Foundation

enum AmazonProductSearchService {
    static func search(query: String) async -> [ItemSearchOffer] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://www.amazon.com/s?k=\(encoded)") else { return fallbackOffers(query: query) }

        guard let html = await fetchHTML(from: url) else { return fallbackOffers(query: query) }
        let parsed = parseProducts(from: html, query: query)
        return parsed.isEmpty ? fallbackOffers(query: query) : parsed
    }

    private static func fetchHTML(from url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else { return nil }

        return html
    }

    private static func parseProducts(from html: String, query: String) -> [ItemSearchOffer] {
        var offers: [ItemSearchOffer] = []
        var seen = Set<String>()

        let asinParts = html.components(separatedBy: "data-asin=\"")
        for part in asinParts.dropFirst().prefix(40) {
            guard let asinEnd = part.firstIndex(of: "\"") else { continue }
            let asin = String(part[..<asinEnd])
            guard asin.count == 10, seen.insert(asin).inserted else { continue }

            let chunk = String(part[asinEnd...].prefix(6000))

            guard let title = extractTitle(from: chunk),
                  let price = extractPrice(from: chunk) else { continue }

            let rating = extractRating(from: chunk)
            let reviewCount = extractReviewCount(from: chunk)
            let brand = extractBrand(from: title)

            offers.append(ItemSearchOffer(
                id: "amazon-\(asin)",
                productName: title,
                brand: brand,
                price: price,
                originalPrice: extractWasPrice(from: chunk),
                rating: rating,
                reviewCount: reviewCount,
                storeName: "Amazon",
                source: .amazon,
                distanceMeters: nil,
                productURL: URL(string: "https://www.amazon.com/dp/\(asin)"),
                imageURL: extractImageURL(from: chunk),
                notes: rating != nil ? "Amazon customer rating" : nil
            ))

            if offers.count >= 12 { break }
        }

        return offers
    }

    private static func extractTitle(from chunk: String) -> String? {
        let patterns = [
            #"<span class="a-size-medium a-color-base a-text-normal">([^<]{8,200})</span>"#,
            #"aria-label="([^"]{10,200})""#,
            #"<h2[^>]*>\s*<span[^>]*>([^<]{10,200})</span>"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: chunk, range: NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: chunk) else { continue }

            let title = String(chunk[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            let blocked = ["Sponsored", "Go to", "Leave ad feedback", "Shop now"]
            guard title.count >= 8, !blocked.contains(where: { title.contains($0) }) else { continue }
            return title
        }

        return nil
    }

    private static func extractPrice(from chunk: String) -> Double? {
        guard let wholeRegex = try? NSRegularExpression(pattern: #"a-price-whole">([0-9,]+)"#),
              let wholeMatch = wholeRegex.firstMatch(in: chunk, range: NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)),
              wholeMatch.numberOfRanges > 1,
              let wholeRange = Range(wholeMatch.range(at: 1), in: chunk) else { return nil }

        let whole = String(chunk[wholeRange]).replacingOccurrences(of: ",", with: "")
        guard let dollars = Double(whole) else { return nil }

        if let fracRegex = try? NSRegularExpression(pattern: #"a-price-fraction">([0-9]{2})"#),
           let fracMatch = fracRegex.firstMatch(in: chunk, range: NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)),
           fracMatch.numberOfRanges > 1,
           let fracRange = Range(fracMatch.range(at: 1), in: chunk),
           let cents = Double(String(chunk[fracRange])) {
            return dollars + cents / 100
        }

        return dollars
    }

    private static func extractWasPrice(from chunk: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"a-text-price"><span[^>]*>\$([0-9,]+\.[0-9]{2})"#),
              let match = regex.firstMatch(in: chunk, range: NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: chunk) else { return nil }

        return Double(String(chunk[range]).replacingOccurrences(of: ",", with: ""))
    }

    private static func extractRating(from chunk: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"a-icon-alt">([0-9.]+) out of 5 stars"#),
              let match = regex.firstMatch(in: chunk, range: NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: chunk) else { return nil }

        return Double(String(chunk[range]))
    }

    private static func extractReviewCount(from chunk: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"a-size-base s-underline-text">([0-9,]+)"#),
              let match = regex.firstMatch(in: chunk, range: NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: chunk) else { return nil }

        return Int(String(chunk[range]).replacingOccurrences(of: ",", with: ""))
    }

    private static func extractImageURL(from chunk: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: #"src="(https://[^"]+\.(?:jpg|png|webp)[^"]*)""#),
              let match = regex.firstMatch(in: chunk, range: NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: chunk) else { return nil }

        return URL(string: String(chunk[range]))
    }

    private static func extractBrand(from title: String) -> String? {
        let known = ["Horizon", "Great Value", "Organic Valley", "Kirkland", "365", "O Organics", "Silk", "Almond Breeze"]
        for brand in known where title.localizedCaseInsensitiveContains(brand) {
            return brand
        }
        return title.components(separatedBy: " ").first
    }

    private static func fallbackOffers(query: String) -> [ItemSearchOffer] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return [
            ItemSearchOffer(
                id: "amazon-search-\(query.hashValue)",
                productName: "Search \"\(query)\" on Amazon",
                brand: nil,
                price: 0,
                originalPrice: nil,
                rating: nil,
                reviewCount: nil,
                storeName: "Amazon",
                source: .amazon,
                distanceMeters: nil,
                productURL: URL(string: "https://www.amazon.com/s?k=\(encoded)"),
                imageURL: nil,
                notes: "Open Amazon to compare live prices and ratings."
            )
        ]
    }
}
