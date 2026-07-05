//
//  BusinessSearchService.swift
//  ShelfSense
//

import CoreLocation
import Foundation
import MapKit

struct BusinessSearchResult: Identifiable, Sendable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let distanceMeters: Double?
    let chain: StoreChain
    let websiteURL: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum BusinessSearchService {
    static func search(
        query: String,
        near coordinate: CLLocationCoordinate2D?,
        radiusMeters: Double = 50_000,
        searchAnywhere: Bool = false
    ) async -> [BusinessSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed

        if !searchAnywhere, let coordinate {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: radiusMeters,
                longitudinalMeters: radiusMeters
            )
        }

        return await performSearch(
            request,
            userLocation: coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        )
    }

    static func searchNearby(
        coordinate: CLLocationCoordinate2D,
        radiusMeters: Double = 12_000
    ) async -> [BusinessSearchResult] {
        let categories = [
            "store", "shop", "grocery store", "supermarket", "pharmacy",
            "department store", "wholesale club", "convenience store",
            "hardware store", "electronics store", "clothing store"
        ]
        var combined: [BusinessSearchResult] = []

        for category in categories {
            let results = await search(
                query: category,
                near: coordinate,
                radiusMeters: radiusMeters,
                searchAnywhere: false
            )
            combined.append(contentsOf: results)
            if combined.count >= 30 { break }
        }

        return dedupe(combined).prefix(30).map { $0 }
    }

    private static func performSearch(
        _ request: MKLocalSearch.Request,
        userLocation: CLLocation?
    ) async -> [BusinessSearchResult] {
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }

        return response.mapItems.compactMap { item in
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return nil }

            let address = formattedAddress(for: item)
            let coordinate = item.location.coordinate
            let distance = userLocation.map {
                $0.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            }

            return BusinessSearchResult(
                id: "\(name)-\(coordinate.latitude)-\(coordinate.longitude)",
                name: name,
                address: address,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                distanceMeters: distance,
                chain: StoreChain.from(name: name),
                websiteURL: item.url?.absoluteString
            )
        }
    }

    private static func formattedAddress(for item: MKMapItem) -> String {
        let placemark = item.placemark
        let parts = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea
        ].compactMap { $0 }

        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }
        return placemark.title ?? item.name ?? "Address unavailable"
    }

    private static func dedupe(_ results: [BusinessSearchResult]) -> [BusinessSearchResult] {
        var seen = Set<String>()
        return results.filter { result in
            let key = "\(result.name.lowercased())-\(result.latitude)-\(result.longitude)"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }.sorted {
            ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude)
        }
    }
}
