//
//  Formatters.swift
//  ShelfSense
//

import Foundation

enum Formatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }()

    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static func currencyString(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? "$\(String(format: "%.2f", value))"
    }

    static func decimalString(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    static func percentString(_ value: Double) -> String {
        percent.string(from: NSNumber(value: value / 100)) ?? "\(Int(value))%"
    }

    static func relativeString(from date: Date) -> String {
        relativeDate.localizedString(for: date, relativeTo: Date())
    }

    static func daysUntil(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
    }
}
