//
//  ReceiptParser.swift
//  ShelfSense
//

import Foundation

struct ParsedReceiptLineItem: Sendable {
    var productName: String
    var quantity: Double
    var unitPrice: Double
    var lineTotal: Double
    var originalPrice: Double?
    var discountAmount: Double
    var isOnSale: Bool
    var quantityUnit: String = "units"
    var expirationDate: Date?
    var category: InventoryCategory?
}

struct ParsedReceipt: Sendable {
    var storeName: String?
    var purchaseDate: Date?
    var lineItems: [ParsedReceiptLineItem]
    var subtotal: Double?
    var tax: Double?
    var discounts: Double?
    var total: Double?
}

enum ReceiptParser {
    private static let pricePattern = #/(?<name>.+?)\s+(?<orig>\d+\.\d{2})?\s*(?<sale>\d+\.\d{2})\s*$/#

    static func parse(_ text: String) -> ParsedReceipt {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var storeName: String?
        var purchaseDate: Date?
        var lineItems: [ParsedReceiptLineItem] = []
        var subtotal: Double?
        var tax: Double?
        var discounts: Double?
        var total: Double?

        let storeKeywords = ["costco", "target", "walmart", "trader", "whole foods", "cvs", "walgreens", "kroger", "home depot", "lowe", "best buy"]
        let skipPrefixes = ["subtotal", "total", "tax", "change", "cash", "visa", "mastercard", "amex", "debit", "credit", "auth", "approval", "member", "thank you", "welcome"]

        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()

            if storeName == nil, storeKeywords.contains(where: { lower.contains($0) }) {
                storeName = line
                continue
            }

            if purchaseDate == nil, let date = parseDate(from: line) {
                purchaseDate = date
                continue
            }

            if lower.hasPrefix("subtotal"), let value = trailingAmount(in: line) {
                subtotal = value
                continue
            }
            if lower.hasPrefix("tax"), let value = trailingAmount(in: line) {
                tax = value
                continue
            }
            if lower.contains("discount") || lower.contains("savings"), let value = trailingAmount(in: line) {
                discounts = (discounts ?? 0) + abs(value)
                continue
            }
            if lower.hasPrefix("total"), let value = trailingAmount(in: line) {
                total = value
                continue
            }

            if skipPrefixes.contains(where: { lower.hasPrefix($0) }) { continue }
            if line.count < 3 { continue }

            if let item = parseLineItem(line) {
                lineItems.append(item)
            } else if index > 0, let amount = trailingAmount(in: line), amount > 0, amount < 500 {
                let nameStart = line.prefix(while: { !$0.isNumber && $0 != "$" })
                let name = String(nameStart).trimmingCharacters(in: .whitespaces)
                if name.count >= 3 {
                    lineItems.append(ParsedReceiptLineItem(
                        productName: name,
                        quantity: 1,
                        unitPrice: amount,
                        lineTotal: amount,
                        originalPrice: nil,
                        discountAmount: 0,
                        isOnSale: false
                    ))
                }
            }
        }

        if subtotal == nil {
            subtotal = lineItems.reduce(0) { $0 + $1.lineTotal }
        }
        if total == nil {
            total = (subtotal ?? 0) + (tax ?? 0) - (discounts ?? 0)
        }

        return ParsedReceipt(
            storeName: storeName,
            purchaseDate: purchaseDate,
            lineItems: lineItems,
            subtotal: subtotal,
            tax: tax,
            discounts: discounts,
            total: total
        )
    }

    private static func parseLineItem(_ line: String) -> ParsedReceiptLineItem? {
        guard let match = line.firstMatch(of: pricePattern) else { return nil }

        let name = String(match.name).trimmingCharacters(in: .whitespaces)
        guard name.count >= 2 else { return nil }

        let sale = Double(match.sale) ?? 0
        guard sale > 0, sale < 10_000 else { return nil }

        let original = match.orig.flatMap { Double($0) }
        let isOnSale = original != nil && original! > sale
        let discount = isOnSale ? (original! - sale) : 0

        return ParsedReceiptLineItem(
            productName: name,
            quantity: 1,
            unitPrice: sale,
            lineTotal: sale,
            originalPrice: original,
            discountAmount: discount,
            isOnSale: isOnSale
        )
    }

    private static func trailingAmount(in line: String) -> Double? {
        let parts = line.split(whereSeparator: { $0.isWhitespace })
        guard let last = parts.last else { return nil }
        let cleaned = last.replacingOccurrences(of: "$", with: "")
        return Double(cleaned)
    }

    private static func parseDate(from line: String) -> Date? {
        let formats = ["MM/dd/yyyy", "M/d/yy", "MM/dd/yy", "yyyy-MM-dd", "MMM d, yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: line.trimmingCharacters(in: .whitespaces)) {
                return date
            }
        }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return detector?.firstMatch(in: line, options: [], range: range)?.date
    }
}
