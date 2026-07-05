//
//  SearchTabWidgets.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct SearchTabShoppingListWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingListItem.priority, order: .reverse) private var items: [ShoppingListItem]

    @Binding var searchText: String

    @State private var quickAddText = ""
    @State private var isExpanded = true
    @State private var showFullList = false
    @State private var showListCompleteConfetti = false
    @FocusState private var quickAddFocused: Bool

    private var activeItems: [ShoppingListItem] {
        items.filter { !$0.isCompleted }
    }

    private var estimatedTotal: Double {
        activeItems.compactMap(\.estimatedPrice).reduce(0, +)
    }

    var body: some View {
        GlassCard(glow: true) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(ShelfMotion.spring) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Label("Shopping List", systemImage: "cart.fill")
                            .font(.shelfHeadline)
                            .foregroundStyle(ShelfTheme.textPrimary)
                        Spacer()
                        Text("\(activeItems.count)")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.copperLight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ShelfTheme.copper.opacity(0.2))
                            .clipShape(Capsule())
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(ShelfTheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    HStack(spacing: 8) {
                        TextField("Quick add item…", text: $quickAddText)
                            .textFieldStyle(.roundedBorder)
                            .focused($quickAddFocused)
                            .submitLabel(.done)
                            .onSubmit { submitQuickAdd() }

                        Button {
                            submitQuickAdd()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(quickAddText.isEmpty ? ShelfTheme.textTertiary : ShelfTheme.copperLight)
                        }
                        .disabled(quickAddText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if activeItems.isEmpty {
                        Text("Search below and tap + on any result, or type above.")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(activeItems.prefix(5), id: \.id) { item in
                                HStack(spacing: 10) {
                                    Button {
                                        toggleItem(item)
                                    } label: {
                                        Image(systemName: "circle")
                                            .foregroundStyle(ShelfTheme.textTertiary)
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        searchText = item.name
                                        HapticManager.selection()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .font(.shelfSubheadline)
                                                .foregroundStyle(ShelfTheme.textPrimary)
                                                .lineLimit(1)
                                            HStack(spacing: 6) {
                                                if let brand = item.brand, !brand.isEmpty {
                                                    Text(brand)
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(ShelfTheme.copperLight)
                                                }
                                                if let assigned = item.assignedTo {
                                                    Text(assigned)
                                                        .font(.system(size: 9))
                                                        .foregroundStyle(ShelfTheme.copper)
                                                }
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()

                                    if let price = item.estimatedPrice {
                                        Text(Formatters.currencyString(price))
                                            .font(.shelfCaption)
                                            .foregroundStyle(ShelfTheme.textSecondary)
                                    }
                                }
                            }

                            if activeItems.count > 5 {
                                Button("View all \(activeItems.count) items") {
                                    showFullList = true
                                }
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.copperLight)
                            }
                        }

                        HStack {
                            Text("Est. total")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)
                            Spacer()
                            Text(Formatters.currencyString(estimatedTotal))
                                .font(.shelfSubheadline)
                                .foregroundStyle(ShelfTheme.success)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .sheet(isPresented: $showFullList) {
            NavigationStack {
                ShoppingListView()
            }
        }
        .overlay {
            ConfettiView(isActive: $showListCompleteConfetti)
        }
    }

    private func submitQuickAdd() {
        ShoppingListAddService.add(name: quickAddText, context: modelContext)
        quickAddText = ""
        quickAddFocused = false
    }

    private func toggleItem(_ item: ShoppingListItem) {
        withAnimation(.spring(response: 0.25)) {
            item.isCompleted = true
        }
        QuestStore.shared.increment(.completeListItems)
        PlayerLevelStore.shared.recordActionXP(8, reason: "List item done")
        HapticManager.selection()

        let remaining = items.filter { !$0.isCompleted }.count
        if remaining == 0 && !items.isEmpty {
            showListCompleteConfetti = true
            SpinWheelCelebration.playWin()
            PlayerLevelStore.shared.recordActionXP(50, reason: "List complete!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                showListCompleteConfetti = false
            }
        }

        try? modelContext.save()
        WidgetSnapshotSyncService.sync(context: modelContext)
    }
}

struct SearchTabGasWidget: View {
    @Environment(LocationManager.self) private var locationManager

    @State private var stations: [GasStationQuote] = []
    @State private var isLoading = false
    @State private var tripMiles = "25"
    @State private var isExpanded = false

    private var tripEstimate: (cheapest: GasStationQuote?, cost: Double, gallons: Double)? {
        guard let miles = Double(tripMiles), miles > 0 else { return nil }
        return GasPriceService.tripEstimate(miles: miles, stations: stations)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(ShelfMotion.spring) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Label("Gas Near You", systemImage: "fuelpump.fill")
                            .font(.shelfHeadline)
                            .foregroundStyle(ShelfTheme.textPrimary)
                        Spacer()
                        if let cheapest = stations.min(by: { $0.pricePerGallon < $1.pricePerGallon }) {
                            Text(Formatters.currencyString(cheapest.pricePerGallon) + "/gal")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.success)
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(ShelfTheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                Text("\(VehicleSettingsStore.vehicleName) · \(Formatters.decimalString(VehicleSettingsStore.mpg)) MPG")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)

                if isExpanded {
                    if isLoading {
                        ProgressView()
                            .tint(ShelfTheme.copper)
                    } else if stations.isEmpty {
                        Text("Enable location to compare nearby gas prices.")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    } else {
                        ForEach(stations.prefix(5)) { station in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.brand)
                                        .font(.shelfSubheadline)
                                        .foregroundStyle(ShelfTheme.textPrimary)
                                    if let distance = station.distanceLabel {
                                        Text(distance)
                                            .font(.system(size: 10))
                                            .foregroundStyle(ShelfTheme.textTertiary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Formatters.currencyString(station.pricePerGallon))
                                        .font(.shelfSubheadline)
                                        .foregroundStyle(ShelfTheme.success)
                                    Text(station.isUserReported ? "Your price" : "Est.")
                                        .font(.system(size: 9))
                                        .foregroundStyle(ShelfTheme.textTertiary)
                                }
                            }
                        }
                    }

                    Divider().overlay(ShelfTheme.separator)

                    HStack {
                        Text("Trip miles")
                            .font(.shelfCaption)
                        TextField("25", text: $tripMiles)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 64)
                    }

                    if let estimate = tripEstimate, let cheapest = estimate.cheapest {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trip estimate via \(cheapest.brand)")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)
                            HStack {
                                Text("\(Formatters.decimalString(estimate.gallons)) gal")
                                Text("·")
                                Text(Formatters.currencyString(estimate.cost))
                                    .foregroundStyle(ShelfTheme.copperLight)
                            }
                            .font(.shelfSubheadline)
                        }
                    }
                }
            }
        }
        .task { await loadStations() }
        .onChange(of: locationManager.currentLocation) { _, _ in
            Task { await loadStations() }
        }
    }

    private func loadStations() async {
        guard let coordinate = locationManager.currentLocation?.coordinate else { return }
        isLoading = true
        stations = await GasPriceService.nearbyStations(near: coordinate)
        isLoading = false
    }
}
