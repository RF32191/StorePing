//
//  NearbyFastFoodService.swift
//  ShelfSense
//

import CoreLocation
import Foundation
import MapKit

struct NearbyFastFoodOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let displayName: String
    let distanceMeters: Double?
    let address: String?

    var distanceLabel: String? {
        guard let distanceMeters else { return nil }
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters)) m away"
        }
        return String(format: "%.1f mi away", distanceMeters / 1609.34)
    }
}

enum NearbyFastFoodService {
    static let fallbackChains = [
        "Chipotle", "In-N-Out", "Panera", "Subway", "Taco Bell",
        "McDonald's", "Wendy's", "Shake Shack", "Panda Express", "Five Guys",
        "Chick-fil-A", "Starbucks"
    ]

    private static let searchQueries = [
        "fast food", "quick service restaurant", "burger restaurant",
        "pizza restaurant", "taco restaurant", "coffee shop",
        "McDonald's", "Chipotle", "Starbucks", "Subway", "Wendy's",
        "Taco Bell", "Chick-fil-A", "Panera", "Panda Express"
    ]

    private static let knownChains = [
        "mcdonald", "chipotle", "starbucks", "subway", "wendy", "taco bell",
        "chick-fil-a", "chick fil a", "panera", "panda express", "five guys",
        "shake shack", "in-n-out", "in n out", "burger king", "kfc",
        "popeyes", "domino", "pizza hut", "dunkin", "jersey mike", "raising cane",
        "whataburger", "culver", "jack in the box", "del taco", "wingstop",
        "panda express", "qdoba", "moe's", "zaxby", "bojangles", "arby"
    ]

    static func fallbackOptions() -> [NearbyFastFoodOption] {
        fallbackChains.map { chain in
            NearbyFastFoodOption(
                id: "fallback-\(chain)",
                name: chain,
                displayName: chain,
                distanceMeters: nil,
                address: nil
            )
        }
    }

    static func nearbyOptions(near coordinate: CLLocationCoordinate2D?, radiusMeters: Double = 8_000) async -> [NearbyFastFoodOption] {
        guard let coordinate else { return fallbackOptions() }

        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var collected: [NearbyFastFoodOption] = []

        for query in searchQueries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = .pointOfInterest
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: radiusMeters,
                longitudinalMeters: radiusMeters
            )

            guard let response = try? await MKLocalSearch(request: request).start() else { continue }

            for item in response.mapItems {
                guard let rawName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawName.isEmpty,
                      isLikelyFastFood(rawName) else { continue }

                let displayName = cleanedName(rawName)
                let distance = userLocation.distance(from: item.location)
                let address = formattedAddress(for: item)

                collected.append(NearbyFastFoodOption(
                    id: "\(displayName)-\(item.location.coordinate.latitude)-\(item.location.coordinate.longitude)",
                    name: displayName,
                    displayName: displayName,
                    distanceMeters: distance,
                    address: address
                ))
            }

            if collected.count >= 24 { break }
        }

        let deduped = dedupe(collected)
        if deduped.count >= 6 {
            return Array(deduped.prefix(12))
        }

        // Blend nearby finds with fallbacks so the wheel always feels full.
        var blended = deduped
        for chain in fallbackChains where blended.count < 12 {
            if !blended.contains(where: { $0.displayName.lowercased() == chain.lowercased() }) {
                blended.append(NearbyFastFoodOption(
                    id: "fallback-\(chain)",
                    name: chain,
                    displayName: chain,
                    distanceMeters: nil,
                    address: nil
                ))
            }
        }
        return Array(blended.prefix(12))
    }

    private static func isLikelyFastFood(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.contains("restaurant") || lower.contains("grill") || lower.contains("kitchen") { return true }
        return knownChains.contains { lower.contains($0) }
    }

    private static func cleanedName(_ raw: String) -> String {
        let separators = [" - ", " – ", " — ", " @ ", " (#", " ("]
        var name = raw
        for separator in separators {
            if let range = name.range(of: separator) {
                name = String(name[..<range.lowerBound])
            }
        }

        let lower = name.lowercased()
        for chain in knownChains {
            if lower.contains(chain) {
                return canonicalName(for: chain)
            }
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func canonicalName(for chain: String) -> String {
        switch chain {
        case "mcdonald": return "McDonald's"
        case "chipotle": return "Chipotle"
        case "starbucks": return "Starbucks"
        case "subway": return "Subway"
        case "wendy": return "Wendy's"
        case "taco bell": return "Taco Bell"
        case "chick-fil-a", "chick fil a": return "Chick-fil-A"
        case "panera": return "Panera"
        case "panda express": return "Panda Express"
        case "five guys": return "Five Guys"
        case "shake shack": return "Shake Shack"
        case "in-n-out", "in n out": return "In-N-Out"
        case "burger king": return "Burger King"
        case "kfc": return "KFC"
        case "popeyes": return "Popeyes"
        case "domino": return "Domino's"
        case "pizza hut": return "Pizza Hut"
        case "dunkin": return "Dunkin'"
        default: return chain.capitalized
        }
    }

    private static func formattedAddress(for item: MKMapItem) -> String {
        let placemark = item.placemark
        let parts = [placemark.subThoroughfare, placemark.thoroughfare, placemark.locality]
            .compactMap { $0 }
        return parts.isEmpty ? (placemark.title ?? "") : parts.joined(separator: " ")
    }

    private static func dedupe(_ options: [NearbyFastFoodOption]) -> [NearbyFastFoodOption] {
        var seen = Set<String>()
        return options
            .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
            .filter { option in
                let key = option.displayName.lowercased()
                return seen.insert(key).inserted
            }
    }
}
