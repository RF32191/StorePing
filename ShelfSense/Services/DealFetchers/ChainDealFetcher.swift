//
//  ChainDealFetcher.swift
//  ShelfSense
//

import Foundation

struct FetchedChainDeal: Sendable {
    var productName: String
    var brand: String?
    var originalPrice: Double
    var salePrice: Double
    var sourceURL: String?
    var expiresAt: Date?
    var notes: String?

    var hasDiscount: Bool {
        originalPrice > salePrice && salePrice > 0
    }

    var isValidProductDeal: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        salePrice > 0 &&
        productName.count >= 4
    }
}

protocol ChainDealFetcher: Sendable {
    var chain: StoreChain { get }
    func fetchDeals(for store: Store) async -> [FetchedChainDeal]
}

enum HTMLDealParser {
    static func fetchHTML(from url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
        } catch {
            return nil
        }
    }

    static func parseAllDeals(from html: String, sourceURL: String?) -> [FetchedChainDeal] {
        let parsers: [[FetchedChainDeal]] = [
            parseWalmartPriceInfo(from: html, sourceURL: sourceURL),
            parseEmbeddedProductPrices(from: html, sourceURL: sourceURL),
            parseTargetPromotions(from: html, sourceURL: sourceURL),
            parseJSONLDProducts(from: html, sourceURL: sourceURL),
            parseWasNowPrices(from: html, sourceURL: sourceURL),
            parsePriceInfoBlocks(from: html, sourceURL: sourceURL)
        ]

        return dedupe(parsers.flatMap { $0 })
    }

    // MARK: - Walmart priceInfo blocks

    static func parseWalmartPriceInfo(from html: String, sourceURL: String?) -> [FetchedChainDeal] {
        var deals: [FetchedChainDeal] = []
        let pattern = #""name":"([^"]{8,120})".{0,4500}?"linePriceDisplay":"(?:Now )?\$([\d.]+)".{0,400}?"savingsAmt":([\d.]+).{0,120}?"wasPrice":"\$([\d.]+)""#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)

        regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match,
                  match.numberOfRanges >= 5,
                  let nameRange = Range(match.range(at: 1), in: html),
                  let saleRange = Range(match.range(at: 2), in: html),
                  let savingsRange = Range(match.range(at: 3), in: html),
                  let wasRange = Range(match.range(at: 4), in: html) else { return }

            let name = decodeJSONString(String(html[nameRange]))
            guard !isNoise(name) else { return }

            guard let sale = Double(html[saleRange]),
                  let savings = Double(html[savingsRange]),
                  let was = Double(html[wasRange]),
                  sale > 0, was >= sale else { return }

            deals.append(FetchedChainDeal(
                productName: name,
                originalPrice: was,
                salePrice: sale,
                sourceURL: sourceURL,
                notes: "Save \(currency(savings)) online at Walmart"
            ))
        }

        return dedupe(deals)
    }

    // MARK: - Target promotions + embedded prices

    static func parseTargetPromotions(from html: String, sourceURL: String?) -> [FetchedChainDeal] {
        var deals: [FetchedChainDeal] = []
        let pattern = #""title":"([^"]*(?:Up to [0-9]+%|[0-9]+% off|BOGO)[^"]*)""#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)

        regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges > 1,
                  let titleRange = Range(match.range(at: 1), in: html) else { return }

            let raw = decodeJSONString(String(html[titleRange]))
            guard let cleaned = cleanTargetPromoTitle(raw),
                  let percent = extractDiscountPercent(from: cleaned) else { return }

            let reference = 49.99
            let sale = (reference * (1 - percent / 100)).rounded(toPlaces: 2)

            deals.append(FetchedChainDeal(
                productName: cleaned,
                originalPrice: reference,
                salePrice: sale,
                sourceURL: sourceURL,
                notes: "Up to \(Int(percent))% off — example price on a $49.99 item. Open weekly ad for exact products."
            ))
        }

        return dedupe(deals)
    }

    static func parseEmbeddedProductPrices(from html: String, sourceURL: String?) -> [FetchedChainDeal] {
        var deals: [FetchedChainDeal] = []

        let patterns = [
            #""title":"([^"]{8,120})".{0,1500}?"formatted_comparison_price":"\$([\d.]+)".{0,300}?"formatted_current_price":"\$([\d.]+)""#,
            #""name":"([^"]{8,120})".{0,1500}?"listPrice":([\d.]+).{0,300}?"salePrice":([\d.]+)"#,
            #""productName":"([^"]{8,120})".{0,1500}?"regularPrice":([\d.]+).{0,300}?"salePrice":([\d.]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)

            regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges >= 4,
                      let nameRange = Range(match.range(at: 1), in: html),
                      let originalRange = Range(match.range(at: 2), in: html),
                      let saleRange = Range(match.range(at: 3), in: html) else { return }

                let name = decodeJSONString(String(html[nameRange]))
                guard !isNoise(name),
                      let original = Double(html[originalRange]),
                      let sale = Double(html[saleRange]),
                      original >= sale, sale > 0 else { return }

                deals.append(FetchedChainDeal(
                    productName: name,
                    originalPrice: original,
                    salePrice: sale,
                    sourceURL: sourceURL,
                    notes: "Save \(currency(original - sale))"
                ))
            }
        }

        return dedupe(deals)
    }

    // MARK: - Generic parsers

    static func parseJSONLDProducts(from html: String, sourceURL: String?) -> [FetchedChainDeal] {
        var deals: [FetchedChainDeal] = []
        let chunks = html.components(separatedBy: "\"@type\":\"Product\"")
        guard chunks.count > 1 else { return [] }

        for chunk in chunks.dropFirst().prefix(30) {
            guard let name = firstMatch(in: chunk, pattern: #""name"\s*:\s*"([^"]+)""#) ??
                    firstMatch(in: chunk, pattern: #""title"\s*:\s*"([^"]+)""#) else { continue }

            let decoded = decodeJSONString(name)
            guard !isNoise(decoded) else { continue }

            let prices = allMatches(in: chunk, pattern: #""price"\s*:\s*"?([\d.]+)"?"#)
                .compactMap { Double($0) }
                .filter { $0 > 0 && $0 < 10_000 }

            if prices.count >= 2 {
                let original = prices[prices.count - 2]
                let sale = prices.last!
                guard original >= sale else { continue }
                deals.append(FetchedChainDeal(
                    productName: decoded,
                    originalPrice: original,
                    salePrice: sale,
                    sourceURL: sourceURL,
                    notes: "Save \(currency(original - sale))"
                ))
                continue
            }

            if let sale = prices.last {
                deals.append(FetchedChainDeal(
                    productName: decoded,
                    originalPrice: sale,
                    salePrice: sale,
                    sourceURL: sourceURL,
                    notes: "Listed on store page"
                ))
            }
        }

        return dedupe(deals)
    }

    static func parseWasNowPrices(from html: String, sourceURL: String?) -> [FetchedChainDeal] {
        var deals: [FetchedChainDeal] = []
        let pattern = #/(?<name>[A-Za-z][A-Za-z0-9 .,'\-/&]{4,70})\s+(?:was|Was)\s+\$?(?<was>\d+\.\d{2}).{0,40}?(?:now|Now)\s+\$?(?<now>\d+\.\d{2})/#

        for match in html.matches(of: pattern) {
            let name = String(match.name).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !isNoise(name),
                  let was = Double(match.was),
                  let now = Double(match.now),
                  was >= now, now > 0 else { continue }

            deals.append(FetchedChainDeal(
                productName: name,
                originalPrice: was,
                salePrice: now,
                sourceURL: sourceURL,
                notes: "Save \(currency(was - now))"
            ))
        }

        return dedupe(deals)
    }

    static func parsePriceInfoBlocks(from html: String, sourceURL: String?) -> [FetchedChainDeal] {
        let stripped = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#36;", with: "$")

        var deals: [FetchedChainDeal] = []
        let linePattern = #/(?<name>[A-Za-z][A-Za-z0-9 .,'\-/&]{4,70})\s+\$?(?<price>\d+\.\d{2})\s+\$?(?<sale>\d+\.\d{2})/#

        for match in stripped.matches(of: linePattern) {
            let name = String(match.name).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !isNoise(name),
                  let original = Double(match.price),
                  let sale = Double(match.sale),
                  original >= sale, sale > 0 else { continue }

            deals.append(FetchedChainDeal(
                productName: name,
                originalPrice: original,
                salePrice: sale,
                sourceURL: sourceURL,
                notes: "Save \(currency(original - sale))"
            ))
            if deals.count >= 15 { break }
        }

        return dedupe(deals)
    }

    // MARK: - Helpers

    static func dedupe(_ deals: [FetchedChainDeal]) -> [FetchedChainDeal] {
        var seen = Set<String>()
        return deals.filter { deal in
            let key = deal.productName.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return deal.isValidProductDeal
        }
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    private static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1, let captureRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[captureRange])
        }
    }

    private static func decodeJSONString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\u0027", with: "'")
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\\"", with: "\"")
    }

    private static func cleanTargetPromoTitle(_ raw: String) -> String? {
        var text = raw
        text = text.replacingOccurrences(of: #"^20\d{2}_[A-Za-z0-9&]+_"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "_FOJ$", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "_Junwk5$", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "junwk5_home_2026_", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "SOL_JUNWK5_", with: "", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard text.count >= 8, !text.hasPrefix("5.28_"), !text.contains("Dynamic Placeholder") else { return nil }
        return text
    }

    private static func extractDiscountPercent(from text: String) -> Double? {
        let pattern = #"(?i)(?:up to )?([0-9]{1,2})%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text),
              let percent = Double(text[range]) else {
            if text.localizedCaseInsensitiveContains("bogo") { return 50 }
            return nil
        }
        return percent
    }

    private static func isNoise(_ name: String) -> Bool {
        let lower = name.lowercased()
        let noise = [
            "copyright", "privacy", "javascript", "cookie", "sign in", "cart", "shipping",
            "footer", "header", "fulfillment", "page title", "global navigation", "placeholder",
            "roundel", "product grid", "featured deals", "shop by category"
        ]
        return noise.contains(where: { lower.contains($0) }) || lower.count < 4
    }

    private static func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

struct GenericChainDealFetcher: ChainDealFetcher {
    let chain: StoreChain

    func fetchDeals(for store: Store) async -> [FetchedChainDeal] {
        guard chain != .custom else { return [] }

        let urlString = store.dealsPageURL ?? store.weeklyAdURL ?? chain.weeklyAdURL?.absoluteString
        guard let urlString, let url = URL(string: urlString) else { return [] }
        guard let html = await HTMLDealParser.fetchHTML(from: url) else { return [] }

        return HTMLDealParser.parseAllDeals(from: html, sourceURL: url.absoluteString)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
