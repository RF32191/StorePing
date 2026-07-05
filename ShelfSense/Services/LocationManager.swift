//
//  LocationManager.swift
//  ShelfSense
//

import Foundation
import CoreLocation
import SwiftData
import Observation

@Observable
@MainActor
final class LocationManager: NSObject {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?
    private var lastNotificationTimes: [String: Date] = [:]
    private let notificationCooldown: TimeInterval = 1800
    private var isAppConfigured = false
    private var isForegroundLocationActive = false

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var currentLocation: CLLocation?
    private(set) var isMonitoringActive = false
    private(set) var monitoredRegionCount = 0
    private(set) var nearbyAlerts: [NearbyStoreAlert] = []
    private(set) var activeNearbyStores: [NearbyStorePresence] = []
    private(set) var lastLocationUpdate: Date?
    private(set) var notificationsEnabled = false

    var geofencingEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "geofencingEnabled") as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: "geofencingEnabled")
            syncGeofenceMonitoring()
        }
    }

    var notifyGeofence: Bool {
        get { UserDefaults.standard.object(forKey: "notifyGeofence") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notifyGeofence") }
    }

    var isLocationAvailable: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: true
        default: false
        }
    }

    var isAlwaysAuthorized: Bool {
        authorizationStatus == .authorizedAlways
    }

    var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined: "Location permission needed"
        case .restricted: "Location restricted"
        case .denied: "Location denied — enable in Settings"
        case .authorizedAlways: "Geofencing active · on-device only"
        case .authorizedWhenInUse: "GPS active · while using app"
        @unknown default: "Unknown status"
        }
    }

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 25
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
        authorizationStatus = locationManager.authorizationStatus
        loadSavedAlerts()
    }

    func configure(context: ModelContext) {
        modelContext = context
        isAppConfigured = true
        syncGeofenceMonitoring()
    }

    func requestPermissions() async {
        notificationsEnabled = await LocalNotificationService.requestAuthorization()
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func requestAlwaysAccess() {
        geofencingEnabled = true
        switch authorizationStatus {
        case .notDetermined:
            Task {
                await requestPermissions()
                if authorizationStatus == .authorizedWhenInUse {
                    requestAlwaysAuthorization()
                }
            }
        case .authorizedWhenInUse:
            requestAlwaysAuthorization()
        case .authorizedAlways:
            syncGeofenceMonitoring()
        default:
            Task { await requestPermissions() }
        }
    }

    /// Starts foreground-only GPS for the Near Me map. Never enables background stay-up mode.
    func startForegroundLocation() {
        guard isLocationAvailable else {
            Task { await requestPermissions() }
            return
        }

        guard !isForegroundLocationActive else { return }

        isForegroundLocationActive = true
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.startUpdatingLocation()
        isMonitoringActive = true
    }

    func stopForegroundLocation() {
        guard isForegroundLocationActive else { return }

        isForegroundLocationActive = false
        locationManager.stopUpdatingLocation()
        isMonitoringActive = monitoredRegionCount > 0
    }

    func startMonitoring() {
        startForegroundLocation()
        syncGeofenceMonitoring()
    }

    func stopMonitoring() {
        stopForegroundLocation()
        stopGeofenceMonitoring()
        isMonitoringActive = false
        activeNearbyStores = []
    }

    func refreshGeofences() {
        syncGeofenceMonitoring()
    }

    private func syncGeofenceMonitoring() {
        guard isAppConfigured else { return }

        guard geofencingEnabled, isAlwaysAuthorized else {
            stopGeofenceMonitoring()
            return
        }

        guard let context = modelContext else { return }

        let stores = (try? context.fetch(FetchDescriptor<Store>())) ?? []
        stopGeofenceMonitoring()

        var count = 0
        for store in stores.filter(\.isFavorite) {
            guard let lat = store.latitude, let lon = store.longitude else { continue }
            guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { continue }

            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                radius: min(store.notificationRadiusMeters, locationManager.maximumRegionMonitoringDistance),
                identifier: store.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            locationManager.startMonitoring(for: region)
            count += 1
        }

        monitoredRegionCount = count
        isMonitoringActive = isForegroundLocationActive || count > 0
    }

    private func stopGeofenceMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredRegionCount = 0
        if !isForegroundLocationActive {
            isMonitoringActive = false
        }
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        currentLocation = location
        lastLocationUpdate = Date()
        evaluateNearbyStores(from: location)

        guard let context = modelContext else { return }
        Task {
            let stores = (try? context.fetch(FetchDescriptor<Store>())) ?? []
            for store in stores where store.latitude == nil {
                await StoreGeocoder.geocode(store: store)
            }
            try? context.save()
            if geofencingEnabled && isAlwaysAuthorized {
                syncGeofenceMonitoring()
            }
        }
    }

    private func evaluateNearbyStores(from location: CLLocation) {
        guard let context = modelContext else { return }

        guard let stores = try? context.fetch(FetchDescriptor<Store>()),
              let items = try? context.fetch(FetchDescriptor<InventoryItem>()),
              let deals = try? context.fetch(FetchDescriptor<Deal>()),
              let listItems = try? context.fetch(FetchDescriptor<ShoppingListItem>()) else { return }

        var presences: [NearbyStorePresence] = []

        for store in stores.filter(\.isFavorite) {
            guard let lat = store.latitude, let lon = store.longitude else { continue }

            let storeLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = location.distance(from: storeLocation)
            let radius = store.notificationRadiusMeters
            let isInside = distance <= radius

            if distance <= radius * 3 {
                let subtitle = NearbyStoreAlertService.presenceSubtitle(
                    for: store,
                    inventoryItems: items,
                    deals: deals,
                    listItems: listItems
                )
                presences.append(NearbyStorePresence(
                    id: store.id,
                    storeName: store.name,
                    distanceMeters: distance,
                    isInsideGeofence: isInside,
                    subtitle: subtitle
                ))
            }

            if isInside {
                triggerNearbyAlert(for: store, distanceMeters: distance, items: items, deals: deals, listItems: listItems)
            }
        }

        presences.sort { $0.distanceMeters < $1.distanceMeters }
        activeNearbyStores = presences
    }

    private func triggerNearbyAlert(
        for store: Store,
        distanceMeters: Double,
        items: [InventoryItem],
        deals: [Deal],
        listItems: [ShoppingListItem]
    ) {
        let storeKey = store.id.uuidString

        if let lastTime = lastNotificationTimes[storeKey],
           Date().timeIntervalSince(lastTime) < notificationCooldown {
            return
        }

        let alert = NearbyStoreAlertService.generateAlert(
            for: store,
            distanceMeters: distanceMeters,
            inventoryItems: items,
            deals: deals,
            listItems: listItems
        )

        nearbyAlerts.removeAll { $0.storeID == store.id }
        nearbyAlerts.insert(alert, at: 0)
        if nearbyAlerts.count > 20 {
            nearbyAlerts = Array(nearbyAlerts.prefix(20))
        }
        saveAlerts()
        lastNotificationTimes[storeKey] = Date()

        if notifyGeofence {
            LocalNotificationService.postNearbyStoreAlert(
                title: alert.title,
                body: alert.message,
                storeID: store.id
            )
        }

        HapticManager.mediumImpact()
    }

    private func handleRegionEntry(storeID: String) {
        guard let context = modelContext,
              let uuid = UUID(uuidString: storeID) else { return }

        guard let stores = try? context.fetch(FetchDescriptor<Store>()),
              let store = stores.first(where: { $0.id == uuid }) else { return }

        let items = (try? context.fetch(FetchDescriptor<InventoryItem>())) ?? []
        let deals = (try? context.fetch(FetchDescriptor<Deal>())) ?? []
        let listItems = (try? context.fetch(FetchDescriptor<ShoppingListItem>())) ?? []

        let distance: Double
        if let location = currentLocation, let lat = store.latitude, let lon = store.longitude {
            distance = location.distance(from: CLLocation(latitude: lat, longitude: lon))
        } else {
            distance = 0
        }

        triggerNearbyAlert(for: store, distanceMeters: distance, items: items, deals: deals, listItems: listItems)

        Task {
            await DealEngine.shared.refreshStore(store, context: context)
        }
    }

    private func handleAuthorizationChange() {
        guard isAppConfigured else { return }

        switch authorizationStatus {
        case .authorizedAlways:
            syncGeofenceMonitoring()
            if isForegroundLocationActive {
                startForegroundLocation()
            }
        case .authorizedWhenInUse:
            stopGeofenceMonitoring()
            if isForegroundLocationActive {
                startForegroundLocation()
            }
        default:
            stopMonitoring()
        }
    }

    private func loadSavedAlerts() {
        guard let data = UserDefaults.standard.data(forKey: "nearbyStoreAlerts"),
              let decoded = try? JSONDecoder().decode([NearbyStoreAlert].self, from: data) else { return }
        nearbyAlerts = decoded
    }

    private func saveAlerts() {
        if let data = try? JSONEncoder().encode(nearbyAlerts) {
            UserDefaults.standard.set(data, forKey: "nearbyStoreAlerts")
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            handleAuthorizationChange()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            handleLocationUpdate(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            handleRegionEntry(storeID: region.identifier)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // GPS errors are handled silently — all processing stays on-device.
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Region monitoring failures are handled silently.
    }
}
