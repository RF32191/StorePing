//
//  UnitConversionService.swift
//  ShelfSense
//

import Foundation

enum UnitConversionService {
    static let volumeUnits = ["cup", "tbsp", "tsp", "ml", "fl oz", "liter"]
    static let weightUnits = ["g", "kg", "oz", "lb"]

    static func convert(value: Double, from: String, to: String) -> Double? {
        let fromKey = from.lowercased()
        let toKey = to.lowercased()
        guard fromKey != toKey else { return value }

        if let ml = toMilliliters(value, unit: fromKey), let result = fromMilliliters(ml, unit: toKey) {
            return result
        }
        if let grams = toGrams(value, unit: fromKey), let result = fromGrams(grams, unit: toKey) {
            return result
        }
        return nil
    }

    static func formatConversion(value: Double, from: String, to: String) -> String? {
        guard let result = convert(value: value, from: from, to: to) else { return nil }
        return "\(Formatters.decimalString(value)) \(from) = \(Formatters.decimalString(result)) \(to)"
    }

    private static func toMilliliters(_ value: Double, unit: String) -> Double? {
        switch unit {
        case "ml": return value
        case "liter", "l": return value * 1000
        case "cup": return value * 236.588
        case "tbsp": return value * 14.787
        case "tsp": return value * 4.929
        case "fl oz": return value * 29.574
        default: return nil
        }
    }

    private static func fromMilliliters(_ ml: Double, unit: String) -> Double? {
        switch unit {
        case "ml": return ml
        case "liter", "l": return ml / 1000
        case "cup": return ml / 236.588
        case "tbsp": return ml / 14.787
        case "tsp": return ml / 4.929
        case "fl oz": return ml / 29.574
        default: return nil
        }
    }

    private static func toGrams(_ value: Double, unit: String) -> Double? {
        switch unit {
        case "g": return value
        case "kg": return value * 1000
        case "oz": return value * 28.3495
        case "lb": return value * 453.592
        default: return nil
        }
    }

    private static func fromGrams(_ grams: Double, unit: String) -> Double? {
        switch unit {
        case "g": return grams
        case "kg": return grams / 1000
        case "oz": return grams / 28.3495
        case "lb": return grams / 453.592
        default: return nil
        }
    }
}
