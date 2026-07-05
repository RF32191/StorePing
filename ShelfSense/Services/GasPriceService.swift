//
//  GasPriceService.swift
//  ShelfSense
//

import CoreLocation
import Foundation
import MapKit

struct GasStationQuote: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let brand: String
    let address: String
    let latitude: Double
    let longitude: Double
    let distanceMeters: Double?
    let pricePerGallon: Double
    let isUserReported: Bool

    var distanceLabel: String? {
        guard let distanceMeters else { return nil }
        if distanceMeters < 1000 { return "\(Int(distanceMeters)) m" }
        return String(format: "%.1f mi", distanceMeters / 1609.34)
    }
}

enum GasPriceService {
    private static let savedPricesKey = "savedGasPrices"
    private static let regionalAverageKey = "regionalGasAverage"

    static var regionalAverage: Double {
        get {
            let value = UserDefaults.standard.double(forKey: regionalAverageKey)
            return value > 0 ? value : 3.65
        }
        set { UserDefaults.standard.set(newValue, forKey: regionalAverageKey) }
    }

    static func nearbyStations(near coordinate: CLLocationCoordinate2D, radiusMeters: Double = 15_000) async -> [GasStationQuote] {
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var collected: [GasStationQuote] = []

        for query in ["gas station", "fuel", "chevron", "shell", "costco gas", "arco"] {
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
                guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else { continue }

                let brand = detectBrand(name)
                let stationID = "\(brand)-\(item.location.coordinate.latitude)-\(item.location.coordinate.longitude)"
                let saved = savedPrice(for: stationID)
                let estimated = saved ?? estimatedPrice(for: brand)
                let distance = userLocation.distance(from: item.location)

                collected.append(GasStationQuote(
                    id: stationID,
                    name: name,
                    brand: brand,
                    address: formattedAddress(for: item),
                    latitude: item.location.coordinate.latitude,
                    longitude: item.location.coordinate.longitude,
                    distanceMeters: distance,
                    pricePerGallon: estimated,
                    isUserReported: saved != nil
                ))
            }
        }

        return dedupe(collected).prefix(12).map { $0 }
    }

    static func savePrice(_ price: Double, for stationID: String) {
        var prices = UserDefaults.standard.dictionary(forKey: savedPricesKey) as? [String: Double] ?? [:]
        prices[stationID] = price
        UserDefaults.standard.set(prices, forKey: savedPricesKey)
    }

    static func tripEstimate(miles: Double, stations: [GasStationQuote]) -> (cheapest: GasStationQuote?, cost: Double, gallons: Double)? {
        guard let cheapest = stations.min(by: { $0.pricePerGallon < $1.pricePerGallon }) else { return nil }
        let gallons = VehicleSettingsStore.gallonsNeeded(miles: miles)
        let cost = VehicleSettingsStore.tripFuelCost(miles: miles, pricePerGallon: cheapest.pricePerGallon)
        return (cheapest, cost, gallons)
    }

    private static func savedPrice(for stationID: String) -> Double? {
        let prices = UserDefaults.standard.dictionary(forKey: savedPricesKey) as? [String: Double]
        return prices?[stationID]
    }

    private static func estimatedPrice(for brand: String) -> Double {
        let base = regionalAverage
        switch brand.lowercased() {
        case "costco", "arco", "sam's club": return base - 0.35
        case "chevron", "shell", "mobil": return base + 0.25
        case "76", "bp": return base + 0.12
        case "circle k", "7-eleven": return base + 0.08
        default: return base
        }
    }

    private static func detectBrand(_ name: String) -> String {
        let lower = name.lowercased()
        let brands = ["Costco", "Chevron", "Shell", "Arco", "Mobil", "76", "BP", "Circle K", "7-Eleven", "Exxon", "Valero", "Sinclair"]
        for brand in brands where lower.contains(brand.lowercased()) {
            return brand
        }
        return name.components(separatedBy: " ").first ?? name
    }

    private static func formattedAddress(for item: MKMapItem) -> String {
        let placemark = item.placemark
        let parts = [placemark.subThoroughfare, placemark.thoroughfare, placemark.locality].compactMap { $0 }
        return parts.isEmpty ? (placemark.title ?? "") : parts.joined(separator: " ")
    }

    private static func dedupe(_ stations: [GasStationQuote]) -> [GasStationQuote] {
        var seen = Set<String>()
        return stations
            .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
            .filter { seen.insert($0.id).inserted }
    }
}
