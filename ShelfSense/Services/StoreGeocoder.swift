//
//  StoreGeocoder.swift
//  ShelfSense
//

import Foundation
import CoreLocation
import MapKit
import SwiftData

enum StoreGeocoder {
    static func geocode(store: Store) async {
        guard store.latitude == nil || store.longitude == nil else { return }
        guard let address = store.address, !address.isEmpty else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(store.name) \(address)"

        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else { return }

        store.latitude = item.location.coordinate.latitude
        store.longitude = item.location.coordinate.longitude
    }
}
