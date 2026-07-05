//
//  GPSView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct GPSView: View {
    @Environment(LocationManager.self) private var locationManager
    @Environment(PremiumAccessStore.self) private var premiumStore
    @Query(sort: \Store.name) private var stores: [Store]
    @Query(sort: \Deal.discountPercent, order: .reverse) private var deals: [Deal]

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var selectedStoreID: UUID?
    @State private var showBusinessSearch = false
    @State private var gpsSessionActive = false
    @State private var gpsContentUnlocked = false

    private var favoriteStores: [Store] {
        stores.filter(\.isFavorite)
    }

    private var nearbyPresences: [NearbyStorePresence] {
        locationManager.activeNearbyStores
    }

    private var closestNearbyStore: NearbyStorePresence? {
        nearbyPresences.first
    }

    var body: some View {
        @Bindable var locationManager = locationManager

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShelfTheme.sectionSpacing) {
                    permissionSection
                    LocationPrivacyBanner(locationManager: locationManager, compact: true)

                    if !premiumStore.isPremium {
                        Text("Free plan: \(premiumStore.remainingUses(for: .gpsCheck)) Near Me check left this week")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ShelfTheme.copperLight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PremiumBlurGate(
                        isUnlocked: $gpsContentUnlocked,
                        feature: .gpsCheck,
                        title: "Near Me locked",
                        subtitle: "Reveal live map pins, nearby stores, deals, and business search results with Pro or your weekly free check."
                    ) {
                        VStack(alignment: .leading, spacing: ShelfTheme.sectionSpacing) {
                            mapSection

                            if let closest = closestNearbyStore, let store = store(for: closest.id) {
                                nearbyHighlightSection(presence: closest, store: store)
                            }

                            if !nearbyPresences.isEmpty {
                                nearbyStoresSection
                            }

                            savedLocationsSection

                            Button {
                                showBusinessSearch = true
                            } label: {
                                Label("Find & Save Businesses", systemImage: "magnifyingglass")
                                    .font(.shelfSubheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ShelfTheme.accent.opacity(0.12))
                                    .foregroundStyle(ShelfTheme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .shelfScrollBottomInset()
            }
            .shelfScrollContentInsets()
            .background(ShelfGradientBackground())
            .navigationTitle("Near Me")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBusinessSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ShelfTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showBusinessSearch) {
                BusinessSearchView(gpsUnlocked: $gpsContentUnlocked)
            }
            .onAppear {
                if premiumStore.isPremium {
                    gpsContentUnlocked = true
                }
                startGPSIfAllowed()
            }
            .onChange(of: premiumStore.isPremium) { _, isPremium in
                if isPremium { gpsContentUnlocked = true }
            }
            .onDisappear {
                if gpsSessionActive {
                    locationManager.stopForegroundLocation()
                    gpsSessionActive = false
                }
            }
            .onChange(of: locationManager.currentLocation) { _, _ in
                updateMapPosition()
            }
            .onChange(of: locationManager.activeNearbyStores.count) { _, _ in
                updateMapPosition()
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        Map(position: $mapPosition, selection: $selectedStoreID) {
            if let userLocation = locationManager.currentLocation {
                Annotation("You", coordinate: userLocation.coordinate) {
                    ZStack {
                        Circle()
                            .fill(ShelfTheme.accent.opacity(0.25))
                            .frame(width: 44, height: 44)
                        Circle()
                            .fill(ShelfTheme.accent)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }

            ForEach(favoriteStores, id: \.id) { store in
                if let coordinate = storeCoordinate(store) {
                    Annotation(store.name, coordinate: coordinate) {
                        StoreMapPin(
                            store: store,
                            isNearby: nearbyPresences.contains { $0.id == store.id },
                            isInside: nearbyPresences.first(where: { $0.id == store.id })?.isInsideGeofence ?? false
                        )
                    }
                    .tag(store.id)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: ShelfTheme.cornerRadiusLarge, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if locationManager.isMonitoringActive {
                Label("Live GPS", systemImage: "location.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(10)
            }
        }
    }

    // MARK: - Permissions

    @ViewBuilder
    private var permissionSection: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined, .denied, .restricted:
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Location Access Required", systemImage: "location.slash.fill")
                        .font(.shelfHeadline)
                        .foregroundStyle(ShelfTheme.warning)

                    Text("Allow location access to see nearby stores, deals, and get directions. All processing stays on your device.")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)

                    Button {
                        Task { await locationManager.requestPermissions() }
                    } label: {
                        Text("Enable Location")
                            .font(.shelfSubheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(ShelfTheme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

        case .authorizedWhenInUse:
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Upgrade to Always Allow", systemImage: "location.circle.fill")
                            .font(.shelfHeadline)
                            .foregroundStyle(ShelfTheme.accentSecondary)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ShelfTheme.success)
                    }

                    Text("You're using While Using the App. Allow Always so \(AppBrand.name) can alert you when you drive near Costco, Target, and other saved stores — even when the app is closed.")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)

                    Button {
                        locationManager.requestAlwaysAccess()
                    } label: {
                        Label("Allow Always", systemImage: "location.fill.viewfinder")
                            .font(.shelfSubheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(ShelfTheme.accentSecondary.opacity(0.2))
                            .foregroundStyle(ShelfTheme.accentSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

        case .authorizedAlways:
            GlassCard(padding: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(ShelfTheme.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Always Allow Enabled")
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.textPrimary)
                        Text("Background store alerts active · local only")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }
                    Spacer()
                }
            }

        @unknown default:
            EmptyView()
        }
    }

    // MARK: - Nearby Highlight

    private func nearbyHighlightSection(presence: NearbyStorePresence, store: Store) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(presence.isInsideGeofence ? "You're here" : "Nearby")
                                .font(.shelfCaption)
                                .foregroundStyle(presence.isInsideGeofence ? ShelfTheme.success : ShelfTheme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    (presence.isInsideGeofence ? ShelfTheme.success : ShelfTheme.accent).opacity(0.15)
                                )
                                .clipShape(Capsule())

                            Text(presence.distanceLabel)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textTertiary)
                        }

                        Text(store.name)
                            .font(.shelfTitle)
                            .foregroundStyle(ShelfTheme.textPrimary)

                        Text(presence.subtitle)
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "storefront.fill")
                        .font(.title)
                        .foregroundStyle(ShelfTheme.accent)
                        .frame(width: 52, height: 52)
                        .background(ShelfTheme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                let storeDeals = dealsForStore(store)
                if !storeDeals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deals at \(store.name)")
                            .font(.shelfHeadline)
                            .foregroundStyle(ShelfTheme.textPrimary)

                        ForEach(storeDeals.prefix(4), id: \.id) { deal in
                            GPSDealRow(deal: deal)
                        }
                    }
                }

                directionsButton(for: store, prominent: true)
            }
        }
    }

    // MARK: - Nearby List

    private var nearbyStoresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Selected Locations Nearby")

            ForEach(nearbyPresences) { presence in
                if let store = store(for: presence.id) {
                    NearbyStoreCard(
                        presence: presence,
                        store: store,
                        deals: dealsForStore(store)
                    )
                }
            }
        }
    }

    // MARK: - Saved Locations

    private var savedLocationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your Saved Locations")

            if favoriteStores.isEmpty {
                Text("Favorite stores in Profile to track them here.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textTertiary)
            } else {
                ForEach(favoriteStores, id: \.id) { store in
                    SavedStoreRow(
                        store: store,
                        presence: nearbyPresences.first { $0.id == store.id },
                        deals: dealsForStore(store)
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func store(for id: UUID) -> Store? {
        stores.first { $0.id == id }
    }

    private func storeCoordinate(_ store: Store) -> CLLocationCoordinate2D? {
        guard let lat = store.latitude, let lon = store.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func dealsForStore(_ store: Store) -> [Deal] {
        deals.filter { ($0.storeID == store.id || $0.storeName == store.name) && $0.isActive }
    }

    private func startGPSIfAllowed() {
        guard locationManager.isLocationAvailable || locationManager.authorizationStatus == .notDetermined else { return }
        gpsSessionActive = true
        updateMapPosition()
        locationManager.startForegroundLocation()
    }

    private func updateMapPosition() {
        var coordinates: [CLLocationCoordinate2D] = []

        if let user = locationManager.currentLocation {
            coordinates.append(user.coordinate)
        }

        for store in favoriteStores {
            if let coordinate = storeCoordinate(store) {
                coordinates.append(coordinate)
            }
        }

        guard !coordinates.isEmpty else { return }

        if coordinates.count == 1, let only = coordinates.first {
            mapPosition = .region(MKCoordinateRegion(
                center: only,
                latitudinalMeters: 2000,
                longitudinalMeters: 2000
            ))
        } else {
            mapPosition = .automatic
        }
    }

    @ViewBuilder
    private func directionsButton(for store: Store, prominent: Bool) -> some View {
        Button {
            AppleMapsNavigation.openDirections(to: store)
        } label: {
            Label("Get Directions in Apple Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .font(prominent ? .shelfSubheadline : .shelfCaption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, prominent ? 14 : 10)
                .background(prominent ? ShelfTheme.accent : ShelfTheme.accent.opacity(0.12))
                .foregroundStyle(prominent ? .white : ShelfTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(store.latitude == nil || store.longitude == nil)
    }
}

// MARK: - Subviews

struct StoreMapPin: View {
    let store: Store
    let isNearby: Bool
    let isInside: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "storefront.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(8)
                .background(isInside ? ShelfTheme.success : (isNearby ? ShelfTheme.accent : ShelfTheme.textSecondary))
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))

            Text(store.name)
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
}

struct GPSDealRow: View {
    let deal: Deal

    var body: some View {
        HStack(spacing: 10) {
            Text(Formatters.percentString(deal.discountPercent))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ShelfTheme.success)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(deal.productName)
                    .font(.shelfSubheadline)
                    .foregroundStyle(ShelfTheme.textPrimary)
                    .lineLimit(1)

                Text("Save \(Formatters.currencyString(deal.savings)) · \(Formatters.currencyString(deal.salePrice))")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
            }

            Spacer()
        }
        .padding(10)
        .background(ShelfTheme.backgroundSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct NearbyStoreCard: View {
    let presence: NearbyStorePresence
    let store: Store
    let deals: [Deal]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(store.name)
                                .font(.shelfHeadline)
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
                        .font(.shelfSubheadline)
                        .foregroundStyle(ShelfTheme.accent)
                }

                if !deals.isEmpty {
                    ForEach(deals.prefix(3), id: \.id) { deal in
                        GPSDealRow(deal: deal)
                    }
                } else {
                    Text("No active deals listed for this store.")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textTertiary)
                }

                Button {
                    AppleMapsNavigation.openDirections(to: store)
                } label: {
                    Label("Directions", systemImage: "map.fill")
                        .font(.shelfCaption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ShelfTheme.accent.opacity(0.12))
                        .foregroundStyle(ShelfTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}

struct SavedStoreRow: View {
    let store: Store
    let presence: NearbyStorePresence?
    let deals: [Deal]

    var body: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(presence != nil ? ShelfTheme.accent : ShelfTheme.textTertiary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name)
                        .font(.shelfSubheadline)
                        .foregroundStyle(ShelfTheme.textPrimary)

                    if let presence {
                        Text("\(presence.distanceLabel) away · \(deals.count) deal\(deals.count == 1 ? "" : "s")")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    } else if store.latitude == nil {
                        Text("Waiting for GPS")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textTertiary)
                    } else {
                        Text("\(deals.count) deal\(deals.count == 1 ? "" : "s") · \(Int(store.notificationRadiusMeters))m alert radius")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textTertiary)
                    }
                }

                Spacer()

                Button {
                    AppleMapsNavigation.openDirections(to: store)
                } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .foregroundStyle(ShelfTheme.accent)
                }
                .disabled(store.latitude == nil || store.longitude == nil)
            }
        }
    }
}

#Preview {
    GPSView()
        .environment(LocationManager.shared)
        .modelContainer(PreviewModelContainer.shared)
}
