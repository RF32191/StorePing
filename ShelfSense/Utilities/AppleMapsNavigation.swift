//
//  AppleMapsNavigation.swift
//  ShelfSense
//

import MapKit

enum AppleMapsNavigation {
    static func openDirections(to store: Store, transport: MKDirectionsTransportType = .automobile) {
        guard let lat = store.latitude, let lon = store.longitude else { return }

        let location = CLLocation(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = store.name

        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: launchOptionsMode(for: transport)
        ]
        mapItem.openInMaps(launchOptions: launchOptions)
        HapticManager.lightImpact()
    }

    private static func launchOptionsMode(for transport: MKDirectionsTransportType) -> String {
        switch transport {
        case .walking: MKLaunchOptionsDirectionsModeWalking
        case .transit: MKLaunchOptionsDirectionsModeTransit
        default: MKLaunchOptionsDirectionsModeDriving
        }
    }
}
