//
//  GeofencingSettingsView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData
import CoreLocation

struct GeofencingSettingsView: View {
    @Environment(LocationManager.self) private var locationManager
    @Query(sort: \Store.name) private var stores: [Store]
    @AppStorage("defaultRadius") private var defaultRadius: Double = 500

    var body: some View {
        @Bindable var locationManager = locationManager

        List {
            Section {
                LocationPrivacyBanner(locationManager: locationManager, compact: true)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                Toggle("Location Alerts", isOn: $locationManager.geofencingEnabled)

                if locationManager.isMonitoringActive {
                    LabeledContent("GPS Status", value: "Active")
                    LabeledContent("Monitored Stores", value: "\(locationManager.monitoredRegionCount)")
                    if let lastUpdate = locationManager.lastLocationUpdate {
                        LabeledContent("Last Update", value: Formatters.relativeString(from: lastUpdate))
                    }
                }
            } footer: {
                Text("\(AppBrand.name) monitors favorite stores on your device only. Alerts are generated locally from your inventory and deals — no cloud tracking.")
            }

            Section("Default Radius") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Notification radius")
                        Spacer()
                        Text("\(Int(defaultRadius))m")
                            .foregroundStyle(ShelfTheme.accent)
                    }

                    Slider(value: $defaultRadius, in: 100...2000, step: 50)
                        .tint(ShelfTheme.accent)
                        .onChange(of: defaultRadius) { _, newValue in
                            applyDefaultRadius(newValue)
                        }
                }
            }

            Section("Favorite Stores") {
                ForEach(stores.filter(\.isFavorite), id: \.id) { store in
                    HStack {
                        Image(systemName: "storefront.fill")
                            .foregroundStyle(ShelfTheme.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.name)
                                .font(.shelfSubheadline)
                            if let lat = store.latitude, let lon = store.longitude {
                                Text(String(format: "%.4f, %.4f · local only", lat, lon))
                                    .font(.shelfCaption)
                                    .foregroundStyle(ShelfTheme.textTertiary)
                            } else {
                                Text("Waiting for GPS to set local coordinates")
                                    .font(.shelfCaption)
                                    .foregroundStyle(ShelfTheme.textSecondary)
                            }
                        }

                        Spacer()

                        Text("\(Int(store.notificationRadiusMeters))m")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textTertiary)
                    }
                }
            }

            if !locationManager.activeNearbyStores.isEmpty {
                Section("Nearby Now") {
                    ForEach(locationManager.activeNearbyStores) { presence in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(presence.storeName)
                                        .font(.shelfSubheadline)
                                    if presence.isInsideGeofence {
                                        Text("HERE")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(ShelfTheme.success)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(ShelfTheme.success.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(presence.subtitle)
                                    .font(.shelfCaption)
                                    .foregroundStyle(ShelfTheme.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text(presence.distanceLabel)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.accent)
                        }
                    }
                }
            }

            Section {
                if locationManager.authorizationStatus == .authorizedWhenInUse {
                    Button("Enable Background Monitoring") {
                        locationManager.requestAlwaysAuthorization()
                    }
                    .foregroundStyle(ShelfTheme.accent)
                }

                if !locationManager.isLocationAvailable {
                    Button("Enable Location Services") {
                        Task { await locationManager.requestPermissions() }
                    }
                    .foregroundStyle(ShelfTheme.accent)
                }
            }
        }
        .navigationTitle("Store Geofencing")
    }

    private func applyDefaultRadius(_ radius: Double) {
        for store in stores.filter(\.isFavorite) {
            store.notificationRadiusMeters = radius
        }
        locationManager.refreshGeofences()
    }
}
