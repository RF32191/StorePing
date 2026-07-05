//
//  BusinessSearchView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData
import CoreLocation

struct BusinessSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager
    @Environment(DealEngine.self) private var dealEngine
    @Environment(PremiumAccessStore.self) private var premiumStore

    @Query(sort: \Store.name) private var savedStores: [Store]

    @Binding var gpsUnlocked: Bool

    @State private var searchText = ""
    @State private var results: [BusinessSearchResult] = []
    @State private var isSearching = false
    @State private var searchNearMe = false
    @State private var searchAnywhere = true
    @State private var statusMessage = "Search for any store by name — nationwide or near you."

    init(gpsUnlocked: Binding<Bool> = .constant(true)) {
        _gpsUnlocked = gpsUnlocked
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Search near my location", isOn: $searchNearMe)
                        .onChange(of: searchNearMe) { _, enabled in
                            if enabled { searchAnywhere = false }
                        }

                    if !searchNearMe {
                        Toggle("Search anywhere (no location limit)", isOn: $searchAnywhere)
                    }

                    if searchNearMe && !locationManager.isLocationAvailable {
                        Button("Enable Location") {
                            Task { await locationManager.requestPermissions() }
                        }
                        .font(.shelfSubheadline)
                        .foregroundStyle(ShelfTheme.accent)
                    }
                } footer: {
                    Text(statusMessage)
                        .font(.shelfCaption)
                }

                if isSearching {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if results.isEmpty && !searchText.isEmpty {
                    Section {
                        Text("No businesses found. Try a different name or disable “near me”.")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }
                } else if !results.isEmpty {
                    Section {
                        PremiumBlurGate(
                            isUnlocked: $gpsUnlocked,
                            feature: .gpsCheck,
                            title: "Business results locked",
                            subtitle: "Reveal store names, addresses, and distances with Pro or your weekly Near Me check.",
                            cornerRadius: 12
                        ) {
                            VStack(spacing: 0) {
                                ForEach(results) { result in
                                    BusinessSearchRow(
                                        result: result,
                                        isSaved: isSaved(result),
                                        canSave: gpsUnlocked || premiumStore.isPremium,
                                        onSave: { Task { await save(result) } }
                                    )
                                    if result.id != results.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Any store — Target, local shop, pharmacy…")
            .navigationTitle("Find Businesses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Search") {
                        Task { await runSearch() }
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty && !searchNearMe)
                }
            }
            .onSubmit(of: .search) {
                Task { await runSearch() }
            }
            .task {
                if premiumStore.isPremium {
                    gpsUnlocked = true
                }
                if searchNearMe, locationManager.isLocationAvailable {
                    await loadNearby()
                }
            }
            .onChange(of: searchNearMe) { _, enabled in
                if enabled, locationManager.isLocationAvailable {
                    Task { await loadNearby() }
                }
            }
            .onChange(of: premiumStore.isPremium) { _, isPremium in
                if isPremium { gpsUnlocked = true }
            }
        }
    }

    private func isSaved(_ result: BusinessSearchResult) -> Bool {
        savedStores.contains {
            $0.name.localizedCaseInsensitiveCompare(result.name) == .orderedSame ||
            ($0.latitude == result.latitude && $0.longitude == result.longitude)
        }
    }

    private func runSearch() async {
        isSearching = true
        defer { isSearching = false }

        let coordinate = searchNearMe ? locationManager.currentLocation?.coordinate : nil

        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            if searchNearMe {
                await loadNearby()
            } else {
                statusMessage = "Enter a store name to search anywhere."
                results = []
            }
            return
        }

        results = await BusinessSearchService.search(
            query: searchText,
            near: coordinate,
            searchAnywhere: searchAnywhere || !searchNearMe
        )
        statusMessage = "Found \(results.count) result\(results.count == 1 ? "" : "s") for “\(searchText)”."
        applyResultsAccess()
    }

    private func loadNearby() async {
        guard let coordinate = locationManager.currentLocation?.coordinate else {
            statusMessage = "Turn on location or enter a business name to search."
            results = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        results = await BusinessSearchService.searchNearby(coordinate: coordinate)
        statusMessage = "Showing \(results.count) businesses near you."
        applyResultsAccess()
    }

    private func applyResultsAccess() {
        if premiumStore.isPremium {
            gpsUnlocked = true
        }
    }

    private func save(_ result: BusinessSearchResult) async {
        guard gpsUnlocked || premiumStore.isPremium else {
            premiumStore.presentPaywall(for: .gpsCheck)
            return
        }
        guard !isSaved(result) else { return }

        let store = Store(
            name: result.name,
            chain: result.chain,
            address: result.address,
            latitude: result.latitude,
            longitude: result.longitude,
            isFavorite: true,
            websiteURL: result.websiteURL
        )
        modelContext.insert(store)
        await dealEngine.refreshStore(store, context: modelContext)
        LocationManager.shared.refreshGeofences()
        HapticManager.success()
    }
}

private struct BusinessSearchRow: View {
    let result: BusinessSearchResult
    let isSaved: Bool
    let canSave: Bool
    let onSave: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.chain.icon)
                .foregroundStyle(ShelfTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.shelfSubheadline)

                Text(result.address)
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
                    .lineLimit(2)

                if let distance = result.distanceMeters {
                    Text(formatDistance(distance))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ShelfTheme.textTertiary)
                }
            }

            Spacer()

            if isSaved {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.success)
            } else if canSave {
                Button("Save", action: onSave)
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.accent)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m away", meters)
        }
        return String(format: "%.1f mi away", meters / 1609.34)
    }
}

#Preview {
    BusinessSearchView()
        .environment(LocationManager.shared)
        .environment(DealEngine.shared)
        .environment(PremiumAccessStore.shared)
        .modelContainer(PreviewModelContainer.shared)
}
