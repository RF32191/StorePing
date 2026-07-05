//
//  DealsView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct DealsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DealEngine.self) private var dealEngine
    @Environment(LocationManager.self) private var locationManager
    @Environment(PremiumAccessStore.self) private var premiumStore

    @Query(sort: \Store.name) private var stores: [Store]
    @Query(sort: \Deal.discountPercent, order: .reverse) private var deals: [Deal]

    @State private var selectedFilter: DealFilter = .all
    @State private var searchText = ""
    @State private var showAddStore = false
    @State private var showBusinessSearch = false
    @State private var showItemSearch = false
    @State private var isRefreshing = false

    enum DealFilter: CaseIterable, Identifiable {
        case all
        case forYou
        case weeklyAds
        case nearbyStores

        var id: String {
            switch self {
            case .all: "All"
            case .forYou: "For You"
            case .weeklyAds: "Weekly Ads"
            case .nearbyStores: "Nearby"
            }
        }

        var title: String { id }
    }

    private var activeDeals: [Deal] {
        deals.filter(\.isActive)
    }

    private var filteredDeals: [Deal] {
        var result = activeDeals

        switch selectedFilter {
        case .all: break
        case .forYou: result = result.filter(\.isRecommended)
        case .weeklyAds: result = result.filter { $0.source == .weeklyAd || $0.source == .chainCatalog }
        case .nearbyStores:
            let nearbyNames = Set(locationManager.activeNearbyStores.map(\.storeName))
            result = result.filter { nearbyNames.contains($0.storeName) }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.productName.localizedCaseInsensitiveContains(searchText) ||
                $0.storeName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var groupedByStore: [(store: Store, deals: [Deal])] {
        stores.compactMap { store in
            let storeDeals = filteredDeals.filter { $0.storeID == store.id || $0.storeName == store.name }
            guard !storeDeals.isEmpty else { return nil }
            return (store, storeDeals)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let summary = dealEngine.lastRefreshSummary {
                        Text(summary)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.success)
                    }

                    filterPicker

                    if stores.isEmpty {
                        noStoresState
                    } else if filteredDeals.isEmpty {
                        emptyState
                    } else if selectedFilter == .all && searchText.isEmpty {
                        ForEach(groupedByStore, id: \.store.id) { group in
                            storeDealSection(store: group.store, deals: group.deals)
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredDeals, id: \.id) { deal in
                                DealCard(deal: deal)
                            }
                        }
                    }
                }
                .padding()
                .shelfScrollBottomInset()
            }
            .shelfScrollContentInsets()
            .background(ShelfGradientBackground())
            .navigationTitle("Deals")
            .searchable(text: $searchText, prompt: "Search deals...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        StoresView()
                    } label: {
                        Image(systemName: "storefront")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            Task { await refreshAllDeals() }
                        } label: {
                            if isRefreshing {
                                ShelfRefreshIndicator()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshing || stores.isEmpty)

                        Button {
                            showItemSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass.circle")
                                .foregroundStyle(ShelfTheme.accent)
                        }

                        Button {
                            showBusinessSearch = true
                        } label: {
                            Image(systemName: "storefront.circle")
                                .foregroundStyle(ShelfTheme.accent)
                        }

                        Button {
                            showAddStore = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ShelfTheme.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddStore) {
                AddStoreView()
            }
            .sheet(isPresented: $showBusinessSearch) {
                BusinessSearchView()
            }
            .sheet(isPresented: $showItemSearch) {
                NavigationStack {
                    ItemSearchView()
                }
            }
            .refreshable {
                await refreshAllDeals()
            }
        }
    }

    private func storeDealSection(store: Store, deals: [Deal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                NavigationLink {
                    StoreDetailView(store: store)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: store.chain.icon)
                            .foregroundStyle(ShelfTheme.accent)
                        Text(store.name)
                            .font(.shelfHeadline)
                            .foregroundStyle(ShelfTheme.textPrimary)
                    }
                }

                Spacer()

                if let last = store.lastDealRefresh {
                    Text(Formatters.relativeString(from: last))
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textTertiary)
                }
            }

            ForEach(deals, id: \.id) { deal in
                DealCard(deal: deal)
            }
        }
    }

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DealFilter.allCases, id: \.self) { filter in
                    CategoryChip(
                        title: filter.title,
                        icon: filterIcon(filter),
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        HapticManager.selection()
                    }
                }
            }
        }
    }

    private func filterIcon(_ filter: DealFilter) -> String {
        switch filter {
        case .all: "tag.fill"
        case .forYou: "sparkles"
        case .weeklyAds: "newspaper.fill"
        case .nearbyStores: "location.fill"
        }
    }

    private var noStoresState: some View {
        GlassCard {
            VStack(spacing: 14) {
                Image(systemName: "storefront.fill")
                    .font(.largeTitle)
                    .foregroundStyle(ShelfTheme.accent)
                Text("Add stores to find deals")
                    .font(.shelfHeadline)
                Text("Each business gets its own weekly ad link, inventory-matched recommendations, and nearby alerts.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Find a Business") {
                    showBusinessSearch = true
                }
                .font(.shelfSubheadline)
                .foregroundStyle(ShelfTheme.accentSecondary)

                Button("Add Manually") {
                    showAddStore = true
                }
                .font(.shelfSubheadline)
                .foregroundStyle(ShelfTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag.slash")
                .font(.largeTitle)
                .foregroundStyle(ShelfTheme.textTertiary)
            Text("No deals match this filter")
                .font(.shelfHeadline)
                .foregroundStyle(ShelfTheme.textSecondary)
            Button("Refresh All Deals") {
                Task { await refreshAllDeals() }
            }
            .font(.shelfSubheadline)
            .foregroundStyle(ShelfTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func refreshAllDeals() async {
        guard premiumStore.consume(.dealRefresh) else { return }
        isRefreshing = true
        await dealEngine.refreshAllStores(context: modelContext)
        QuestStore.shared.increment(.checkDeals)
        isRefreshing = false
        HapticManager.success()
    }
}

struct DealCard: View {
    let deal: Deal

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deal.productName)
                            .font(.shelfHeadline)
                            .foregroundStyle(ShelfTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let brand = deal.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textTertiary)
                        }

                        HStack(spacing: 8) {
                            Text(deal.storeName)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)

                            Label(deal.source.displayName, systemImage: deal.source.icon)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(ShelfTheme.textTertiary)
                        }
                    }

                    Spacer()

                    if deal.source != .weeklyAd && deal.discountPercent > 0 {
                        discountBadge
                    }
                }

                if deal.source == .weeklyAd, let urlString = deal.sourceURL, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Label("Open Weekly Ad", systemImage: "arrow.up.right.square")
                            .font(.shelfSubheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(ShelfTheme.accent.opacity(0.12))
                            .foregroundStyle(ShelfTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    if let notes = deal.notes {
                        Text(notes)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sale")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(ShelfTheme.textTertiary)
                                Text(Formatters.currencyString(deal.salePrice))
                                    .font(.shelfStatSmall)
                                    .foregroundStyle(ShelfTheme.success)
                            }

                            if deal.originalPrice > deal.salePrice {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Was")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(ShelfTheme.textTertiary)
                                    Text(Formatters.currencyString(deal.originalPrice))
                                        .font(.shelfSubheadline)
                                        .strikethrough()
                                        .foregroundStyle(ShelfTheme.textTertiary)
                                }
                            }

                            Spacer()

                            if deal.savings > 0 {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("You save")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(ShelfTheme.textTertiary)
                                    Text(Formatters.currencyString(deal.savings))
                                        .font(.shelfSubheadline)
                                        .foregroundStyle(ShelfTheme.accentSecondary)
                                }
                            }
                        }
                    }

                    if let notes = deal.notes {
                        Text(notes)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }

                    HStack(spacing: 8) {
                        if deal.isTrending {
                            tagLabel("Trending", icon: "flame.fill", color: ShelfTheme.warning)
                        }
                        if deal.isRecommended {
                            tagLabel("For You", icon: "sparkles", color: ShelfTheme.accent)
                        }
                    }
                }
            }
        }
    }

    private var discountBadge: some View {
        Text(Formatters.percentString(deal.discountPercent))
            .font(.shelfSubheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ShelfTheme.success)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func tagLabel(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    DealsView()
        .environment(DealEngine.shared)
        .environment(LocationManager.shared)
        .modelContainer(PreviewModelContainer.shared)
}
