//
//  LocalItemPriceService.swift
//  ShelfSense
//

import CoreLocation
import Foundation
import MapKit
import SwiftData

enum LocalItemPriceService {
    static func search(
        query: String,
        coordinate: CLLocationCoordinate2D?,
        stores: [Store],
        deals: [Deal],
        receipts: [Receipt],
        lineItems: [ReceiptLineItem]
    ) async -> [ItemSearchOffer] {
        var offers: [ItemSearchOffer] = []
        let normalized = query.lowercased()

        for deal in deals where deal.isActive && matches(deal.productName, query: normalized) {
            let distance = distance(to: deal.storeName, stores: stores, coordinate: coordinate)
            offers.append(ItemSearchOffer(
                id: "deal-\(deal.id.uuidString)",
                productName: deal.productName,
                brand: deal.brand,
                price: deal.salePrice,
                originalPrice: deal.originalPrice > deal.salePrice ? deal.originalPrice : nil,
                rating: nil,
                reviewCount: nil,
                storeName: deal.storeName,
                source: .savedDeal,
                distanceMeters: distance,
                productURL: deal.sourceURL.flatMap(URL.init(string:)),
                imageURL: nil,
                notes: deal.notes ?? "Saved deal in \(AppBrand.name)"
            ))
        }

        let receiptMap = Dictionary(uniqueKeysWithValues: receipts.map { ($0.id, $0) })
        for item in lineItems where matches(item.productName, query: normalized) {
            guard let receipt = receiptMap[item.receiptID] else { continue }
            let distance = distance(to: receipt.storeName, stores: stores, coordinate: coordinate)
            offers.append(ItemSearchOffer(
                id: "receipt-\(item.id.uuidString)",
                productName: item.productName,
                brand: nil,
                price: item.unitPrice,
                originalPrice: item.originalPrice,
                rating: nil,
                reviewCount: nil,
                storeName: receipt.storeName,
                source: .receiptHistory,
                distanceMeters: distance,
                productURL: nil,
                imageURL: nil,
                notes: "You paid this on \(receipt.purchaseDate.formatted(date: .abbreviated, time: .omitted))"
            ))
        }

        if let coordinate {
            let nearbyStores = await discoverNearbyStores(query: query, coordinate: coordinate)
            for store in nearbyStores {
                if offers.contains(where: { $0.storeName == store.name && $0.source != .nearbyStore }) { continue }
                if let priced = offers.filter({ $0.storeName == store.name && $0.hasPrice }).min(by: { $0.price < $1.price }) {
                    offers.append(ItemSearchOffer(
                        id: "nearby-priced-\(store.id)",
                        productName: priced.productName,
                        brand: priced.brand,
                        price: priced.price,
                        originalPrice: priced.originalPrice,
                        rating: priced.rating,
                        reviewCount: priced.reviewCount,
                        storeName: store.name,
                        source: .nearbyStore,
                        distanceMeters: store.distanceMeters,
                        productURL: priced.productURL,
                        imageURL: nil,
                        notes: "Near you · matches your saved prices/deals"
                    ))
                } else {
                    offers.append(ItemSearchOffer(
                        id: "nearby-\(store.id)",
                        productName: query.capitalized,
                        brand: nil,
                        price: 0,
                        originalPrice: nil,
                        rating: nil,
                        reviewCount: nil,
                        storeName: store.name,
                        source: .nearbyStore,
                        distanceMeters: store.distanceMeters,
                        productURL: nil,
                        imageURL: nil,
                        notes: store.address
                    ))
                }
            }
        }

        for store in stores where store.isFavorite {
            let distance = distance(toStore: store, coordinate: coordinate)
            guard offers.contains(where: { $0.storeName == store.name }) == false else { continue }
            if let deal = deals.first(where: { $0.isActive && $0.storeName == store.name && matches($0.productName, query: normalized) }) {
                continue
            }
            offers.append(ItemSearchOffer(
                id: "saved-store-\(store.id.uuidString)",
                productName: query.capitalized,
                brand: nil,
                price: 0,
                originalPrice: nil,
                rating: nil,
                reviewCount: nil,
                storeName: store.name,
                source: .nearbyStore,
                distanceMeters: distance,
                productURL: store.dealsPageURL.flatMap(URL.init(string:)),
                imageURL: nil,
                notes: "Saved store — refresh deals for pricing"
            ))
        }

        return dedupe(offers)
    }

    private struct NearbyStoreHit: Sendable {
        let id: String
        let name: String
        let address: String?
        let distanceMeters: Double?
    }

    private static func discoverNearbyStores(query: String, coordinate: CLLocationCoordinate2D) async -> [NearbyStoreHit] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(query) grocery store"
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 12_000,
            longitudinalMeters: 12_000
        )

        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return response.mapItems.prefix(8).compactMap { item in
            guard let name = item.name, !name.isEmpty else { return nil }
            let distance = userLocation.distance(from: item.location)
            return NearbyStoreHit(
                id: "\(name)-\(item.location.coordinate.latitude)",
                name: name,
                address: item.placemark.title,
                distanceMeters: distance
            )
        }
    }

    private static func matches(_ text: String, query: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains(query) || query.contains(lower) ||
            query.split(separator: " ").allSatisfy { lower.contains(String($0)) }
    }

    private static func distance(to storeName: String, stores: [Store], coordinate: CLLocationCoordinate2D?) -> Double? {
        guard let store = stores.first(where: { $0.name == storeName }),
              let lat = store.latitude, let lon = store.longitude,
              let coordinate else { return nil }
        let storeLocation = CLLocation(latitude: lat, longitude: lon)
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return userLocation.distance(from: storeLocation)
    }

    private static func distance(toStore store: Store, coordinate: CLLocationCoordinate2D?) -> Double? {
        guard let lat = store.latitude, let lon = store.longitude, let coordinate else { return nil }
        let storeLocation = CLLocation(latitude: lat, longitude: lon)
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return userLocation.distance(from: storeLocation)
    }

    private static func dedupe(_ offers: [ItemSearchOffer]) -> [ItemSearchOffer] {
        var seen = Set<String>()
        return offers.filter { offer in
            let key = "\(offer.source.rawValue)-\(offer.storeName)-\(offer.productName)-\(offer.price)"
            return seen.insert(key).inserted
        }
    }
}
