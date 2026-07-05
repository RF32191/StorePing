//
//  StoreHubViews.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct InStoreModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager
    @Query private var listItems: [ShoppingListItem]
    @Query private var deals: [Deal]
    @Query private var members: [HouseholdMember]

    @State private var showFoundConfetti = false
    @State private var filterAssigned: String?

    private var activeList: [ShoppingListItem] {
        var items = listItems.filter { !$0.isCompleted }
        if let filterAssigned {
            items = items.filter { $0.assignedTo == filterAssigned }
        }
        return items
    }

    private var nearbyStore: String? {
        locationManager.activeNearbyStores.first?.storeName
    }

    private var storeDeals: [Deal] {
        guard let store = nearbyStore else { return [] }
        return deals.filter { $0.storeName == store && $0.isActive }
    }

    private var assigneeFilters: [String] {
        let names = Set(listItems.compactMap(\.assignedTo).filter { !$0.isEmpty })
        return Array(names).sorted()
    }

    var body: some View {
        List {
            Section {
                if let store = nearbyStore {
                    Label("You're at \(store)", systemImage: "location.fill")
                        .foregroundStyle(ShelfTheme.copperLight)
                } else {
                    Label("No nearby store detected", systemImage: "location.slash")
                        .foregroundStyle(ShelfTheme.textSecondary)
                }
            }

            if !assigneeFilters.isEmpty {
                Section("Filter by person") {
                    Picker("Assigned", selection: $filterAssigned) {
                        Text("Everyone").tag(Optional<String>.none)
                        ForEach(assigneeFilters, id: \.self) { name in
                            Text(name).tag(Optional(name))
                        }
                    }
                }
            }

            Section("Checklist (\(activeList.count))") {
                ForEach(activeList, id: \.id) { item in
                    Button {
                        markFound(item)
                    } label: {
                        HStack {
                            Image(systemName: "circle")
                                .foregroundStyle(ShelfTheme.textTertiary)
                            VStack(alignment: .leading) {
                                Text(item.name).font(.shelfSubheadline)
                                    .foregroundStyle(ShelfTheme.textPrimary)
                                if let assigned = item.assignedTo {
                                    Text(assigned).font(.shelfCaption).foregroundStyle(ShelfTheme.copper)
                                }
                            }
                            Spacer()
                            if let deal = storeDeals.first(where: { $0.productName.lowercased().contains(item.name.lowercased()) }) {
                                Text(Formatters.currencyString(deal.salePrice))
                                    .font(.shelfCaption).foregroundStyle(ShelfTheme.success)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if !storeDeals.isEmpty {
                Section("Deals Here") {
                    ForEach(storeDeals.prefix(8), id: \.id) { deal in
                        HStack {
                            Text(deal.productName).font(.shelfCaption)
                            Spacer()
                            Text(Formatters.currencyString(deal.salePrice))
                                .font(.shelfCaption).foregroundStyle(ShelfTheme.success)
                        }
                    }
                }
            }
        }
        .navigationTitle("In-Store Mode")
        .overlay {
            ConfettiView(isActive: $showFoundConfetti)
        }
    }

    private func markFound(_ item: ShoppingListItem) {
        item.isCompleted = true
        QuestStore.shared.increment(.completeListItems)
        PlayerLevelStore.shared.recordActionXP(10, reason: "Found in store")
        HapticManager.success()
        try? modelContext.save()

        if activeList.count <= 1 {
            showFoundConfetti = true
            PlayerLevelStore.shared.recordActionXP(50, reason: "In-store haul complete")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showFoundConfetti = false
            }
        }
    }
}

struct StoreComparisonView: View {
    @Environment(LocationManager.self) private var locationManager
    @Query private var stores: [Store]
    @Query private var deals: [Deal]
    @Query private var listItems: [ShoppingListItem]

    private var comparisons: [(store: Store, dealCount: Int, listMatches: Int)] {
        stores.map { store in
            let storeDeals = deals.filter { $0.storeName == store.name && $0.isActive }
            let matches = listItems.filter { item in
                !item.isCompleted && storeDeals.contains { $0.productName.lowercased().contains(item.name.lowercased()) }
            }
            return (store, storeDeals.count, matches.count)
        }
        .sorted { $0.dealCount > $1.dealCount }
    }

    var body: some View {
        List {
            Section {
                Text("Compare saved stores by active deals and how many list items match.")
                    .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
            }

            if comparisons.isEmpty {
                ContentUnavailableView("No stores saved", systemImage: "storefront")
            } else {
                ForEach(comparisons, id: \.store.id) { item in
                    HStack {
                        Image(systemName: item.store.chain.icon)
                            .foregroundStyle(ShelfTheme.copper)
                        VStack(alignment: .leading) {
                            Text(item.store.name).font(.shelfSubheadline)
                            if let presence = locationManager.activeNearbyStores.first(where: { $0.storeName == item.store.name }) {
                                Text(presence.distanceLabel).font(.shelfCaption).foregroundStyle(ShelfTheme.success)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(item.dealCount) deals").font(.shelfCaption)
                            Text("\(item.listMatches) list matches").font(.system(size: 10)).foregroundStyle(ShelfTheme.textTertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Store Comparison")
    }
}
