//
//  ItemSearchView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData
import CoreLocation

enum ItemSearchSourceFilter: String, CaseIterable, Identifiable {
    case all
    case amazon
    case walmart
    case target
    case nearby
    case brands
    case pantry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .amazon: "Amazon"
        case .walmart: "Walmart"
        case .target: "Target"
        case .nearby: "Nearby"
        case .brands: "Brands"
        case .pantry: "Pantry"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .amazon: "cart.fill"
        case .walmart: "building.2.fill"
        case .target: "target"
        case .nearby: "location.fill"
        case .brands: "tag.fill"
        case .pantry: "archivebox.fill"
        }
    }
}

struct ItemSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager
    @Environment(PremiumAccessStore.self) private var premiumStore

    @Query(sort: \Store.name) private var stores: [Store]
    @Query private var deals: [Deal]
    @Query private var receipts: [Receipt]
    @Query private var lineItems: [ReceiptLineItem]
    @Query(sort: \InventoryItem.name) private var inventoryItems: [InventoryItem]

    var initialQuery: String = ""

    @State private var searchText = ""
    @State private var results: ItemSearchResults?
    @State private var isSearching = false
    @State private var selectedBrand: String?
    @State private var sourceFilter: ItemSearchSourceFilter = .all
    @State private var sortOption: ItemSearchSort = .bestPrice
    @State private var selectedOffer: ItemSearchOffer?
    @State private var searchTask: Task<Void, Never>?
    @State private var recentSearches: [String] = ItemSearchHistoryStore.recentSearches()
    @State private var recentBrands: [String] = ItemSearchHistoryStore.recentBrands()
    @State private var loadingStage = 0
    @State private var loadingTimer: Timer?
    @State private var showPriceWatchAlert = false
    @State private var priceWatchName = ""
    @State private var searchResultsUnlocked = false

    var body: some View {
        content
            .background(ShelfGradientBackground())
            .navigationTitle("Search & List")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search food, brands, household items…")
        .toolbar {
            if results != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(ItemSearchSort.allCases) { sort in
                                Label(sort.title, systemImage: sort.icon).tag(sort)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
        }
        .alert("Price Watch", isPresented: $showPriceWatchAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Watching \(priceWatchName) — you'll get alerts when deals match.")
        }
        .onSubmit(of: .search) {
            Task { await runSearch() }
        }
        .onChange(of: searchText) { _, newValue in
            scheduleSearch(for: newValue)
        }
        .onAppear {
            if searchText.isEmpty, !initialQuery.isEmpty {
                searchText = initialQuery
                Task { await runSearch() }
            }
        }
        .sheet(item: $selectedOffer) { offer in
            ItemSearchDetailSheet(offer: offer, onPriceWatch: { name in
                priceWatchName = name
                showPriceWatchAlert = true
            }) {
                ShoppingListAddService.add(offer, context: modelContext)
            }
        }
        .animation(ShelfMotion.spring, value: isSearching)
        .animation(ShelfMotion.spring, value: results?.query)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SearchTabShoppingListWidget(searchText: $searchText)
                    .shelfAppear()

                SearchTabGasWidget()
                    .shelfAppear(delay: 0.04)

                if !locationManager.isLocationAvailable {
                    locationBanner
                }

                if isSearching {
                    loadingState
                } else if let results {
                    resultsContent(results)
                } else {
                    discoveryContent
                }
            }
            .padding()
            .shelfScrollBottomInset()
        }
        .shelfScrollContentInsets()
    }

    private var locationBanner: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 10) {
                Image(systemName: "location.slash")
                    .foregroundStyle(ShelfTheme.warning)
                Text("Enable location to find nearby store prices.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
                Spacer()
                Button("Enable") {
                    Task { await locationManager.requestPermissions() }
                }
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.accent)
            }
        }
    }

    private var loadingState: some View {
        ShelfLoadingView(
            message: loadingMessage,
            detail: "Amazon · Walmart · Target · brands · nearby",
            style: .full
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var loadingMessage: String {
        switch loadingStage {
        case 0: "Searching products…"
        case 1: "Comparing prices…"
        default: "Ranking brands & ratings…"
        }
    }

    private var discoveryContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                ShelfInterestBadge(text: "Discover Items", icon: "bag.fill")
                CopperGradientText(text: "What interests you?", font: .shelfTitle)
                Text("Search products, explore brands, and compare prices across stores.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)

                if !premiumStore.isPremium {
                    Text("Free plan: \(premiumStore.remainingUses(for: .priceCheck)) price search left this week")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ShelfTheme.copperLight)
                }
            }
            .shelfAppear()

            if !recentSearches.isEmpty {
                chipSection(title: "Recent searches", items: recentSearches, icon: "clock.arrow.circlepath") { query in
                    searchText = query
                    Task { await runSearch() }
                }
                .shelfAppear(delay: 0.05)
            }

            chipSection(title: "Trending now", items: ItemSearchHistoryStore.popularQueries, icon: "flame.fill") { query in
                searchText = query
                Task { await runSearch() }
            }
            .shelfAppear(delay: 0.1)

            brandGridSection(
                title: recentBrands.isEmpty ? "Explore brands" : "Brands for you",
                brands: recentBrands.isEmpty ? ItemSearchHistoryStore.popularBrands : recentBrands
            )
            .shelfAppear(delay: 0.15)
        }
    }

    @ViewBuilder
    private func resultsContent(_ results: ItemSearchResults) -> some View {
        PremiumBlurGate(
            isUnlocked: $searchResultsUnlocked,
            feature: .priceCheck,
            title: "Price results locked",
            subtitle: "Reveal product matches, store prices, and brand comparisons with Pro or your weekly free search."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                summaryBar(results)

                sourceFilters

                if !results.brands.isEmpty {
                    brandFilters(results.brands)
                }

                if !pricedComparisonRows(from: results).isEmpty {
                    priceComparisonSection(from: results)
                }

                let visible = sortedVisibleOffers(from: results)

                if visible.isEmpty {
                    emptyResultsState
                } else {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, offer in
                        ItemSearchOfferCard(offer: offer) {
                            ShoppingListAddService.add(offer, context: modelContext)
                        }
                        .onTapGesture {
                            guard searchResultsUnlocked || premiumStore.isPremium else {
                                premiumStore.presentPaywall(for: .priceCheck)
                                return
                            }
                            selectedOffer = offer
                            HapticManager.lightImpact()
                        }
                        .shelfStaggered(index: index)
                    }
                }
            }
        }
    }

    private func summaryBar(_ results: ItemSearchResults) -> some View {
        GlassCard(padding: 12, glow: true) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(results.offers.count) results")
                        .font(.shelfHeadline)
                        .foregroundStyle(ShelfTheme.textPrimary)
                    Text("“\(results.query)” · \(results.brands.count) brands")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                }
                Spacer()
                if let cheapest = results.cheapest {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("From")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ShelfTheme.textTertiary)
                        Text(Formatters.currencyString(cheapest.price))
                            .font(.shelfStatSmall)
                            .foregroundStyle(ShelfTheme.success)
                    }
                }
            }
        }
    }

    private var sourceFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ItemSearchSourceFilter.allCases) { filter in
                    CategoryChip(
                        title: filter.title,
                        icon: filter.icon,
                        isSelected: sourceFilter == filter
                    ) {
                        sourceFilter = filter
                        HapticManager.selection()
                    }
                }
            }
        }
    }

    private func brandFilters(_ brands: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter by brand")
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(title: "All brands", icon: "square.grid.2x2", isSelected: selectedBrand == nil) {
                        selectedBrand = nil
                        HapticManager.selection()
                    }

                    ForEach(brands, id: \.self) { brand in
                        CategoryChip(title: brand, icon: "tag.fill", isSelected: selectedBrand == brand) {
                            selectedBrand = brand
                            ItemSearchHistoryStore.recordBrand(brand)
                            HapticManager.selection()
                        }
                    }
                }
            }
        }
    }

    private func priceComparisonSection(from results: ItemSearchResults) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Price comparison", systemImage: "chart.bar.fill")
                .font(.shelfHeadline)
                .foregroundStyle(ShelfTheme.textPrimary)

            GlassCard(padding: 12) {
                VStack(spacing: 10) {
                    ForEach(pricedComparisonRows(from: results).prefix(6)) { offer in
                        HStack {
                            Image(systemName: offer.source.icon)
                                .foregroundStyle(ShelfTheme.accent)
                                .frame(width: 20)
                            Text(offer.storeName)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)
                                .frame(width: 72, alignment: .leading)
                            Text(offer.brand ?? offer.productName)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(Formatters.currencyString(offer.price))
                                .font(.shelfSubheadline)
                                .foregroundStyle(offer.id == results.cheapest?.id ? ShelfTheme.success : ShelfTheme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private var emptyResultsState: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(ShelfTheme.textTertiary)
                Text("No results for this filter")
                    .font(.shelfHeadline)
                Text("Try All sources, a different brand, or a broader search term.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func chipSection(title: String, items: [String], icon: String, action: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button {
                        action(item)
                    } label: {
                        Text(item.capitalized)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ShelfTheme.backgroundSecondary)
                            .overlay {
                                Capsule()
                                    .strokeBorder(ShelfTheme.copper.opacity(0.2), lineWidth: 0.5)
                            }
                            .clipShape(Capsule())
                    }
                    .buttonStyle(ShelfPressButtonStyle())
                }
            }
        }
    }

    private func brandGridSection(title: String, brands: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "tag.fill")
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(brands, id: \.self) { brand in
                    Button {
                        searchText = brand
                        Task { await runSearch() }
                    } label: {
                        HStack {
                            Image(systemName: "building.2.crop.circle")
                                .foregroundStyle(ShelfTheme.heroGradient)
                            Text(brand)
                                .font(.shelfSubheadline)
                                .foregroundStyle(ShelfTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(ShelfTheme.copper.opacity(0.7))
                        }
                        .padding(12)
                        .background(ShelfTheme.cardBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(ShelfTheme.copper.opacity(0.18), lineWidth: 0.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ShelfPressButtonStyle())
                }
            }
        }
    }

    private func sortedVisibleOffers(from results: ItemSearchResults) -> [ItemSearchOffer] {
        ItemSearchService.sort(filteredOffers(from: results), by: sortOption)
    }

    private func filteredOffers(from results: ItemSearchResults) -> [ItemSearchOffer] {
        var list = results.offers

        switch sourceFilter {
        case .all: break
        case .amazon: list = list.filter { $0.source == .amazon }
        case .walmart: list = list.filter { $0.source == .walmart }
        case .target: list = list.filter { $0.source == .target }
        case .nearby: list = list.filter { $0.source == .nearbyStore || $0.source == .savedDeal || $0.source == .receiptHistory }
        case .brands: list = list.filter { $0.source == .openFoodFacts || $0.brand != nil }
        case .pantry: list = list.filter { $0.source == .pantry }
        }

        if let brand = selectedBrand {
            list = list.filter {
                $0.brand?.localizedCaseInsensitiveCompare(brand) == .orderedSame ||
                $0.productName.localizedCaseInsensitiveContains(brand)
            }
        }

        return list
    }

    private func pricedComparisonRows(from results: ItemSearchResults) -> [ItemSearchOffer] {
        filteredOffers(from: results).filter(\.hasPrice)
    }

    private func scheduleSearch(for text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            if trimmed.isEmpty { results = nil }
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        loadingStage = 0
        startLoadingStages()
        searchResultsUnlocked = false

        let coordinate = locationManager.currentLocation?.coordinate
        let fetched = await ItemSearchService.search(
            query: query,
            coordinate: coordinate,
            stores: stores,
            deals: deals,
            receipts: receipts,
            lineItems: lineItems,
            inventoryItems: inventoryItems
        )

        stopLoadingStages()
        withAnimation(ShelfMotion.spring) {
            isSearching = false
            results = fetched
        }

        if premiumStore.isPremium {
            searchResultsUnlocked = true
        } else {
            searchResultsUnlocked = false
        }

        recentSearches = ItemSearchHistoryStore.recentSearches()
        recentBrands = ItemSearchHistoryStore.recentBrands()
        HapticManager.success()
    }

    private func startLoadingStages() {
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { _ in
            Task { @MainActor in
                loadingStage = min(loadingStage + 1, 2)
            }
        }
    }

    private func stopLoadingStages() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        loadingStage = 0
    }
}

// MARK: - Detail sheet

struct ItemSearchDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let offer: ItemSearchOffer
    var onPriceWatch: ((String) -> Void)?
    var onAddToList: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let imageURL = offer.imageURL {
                        AsyncImage(url: imageURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFit()
                                    .frame(maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }

                    Text(offer.productName)
                        .font(.shelfTitle)
                        .foregroundStyle(ShelfTheme.textPrimary)

                    if let badge = DietBadgeService.badge(for: offer) {
                        Label(badge.title, systemImage: badge.icon)
                            .font(.shelfCaption)
                            .foregroundStyle(badge.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(badge.color.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 12) {
                        Label(offer.storeName, systemImage: offer.source.icon)
                        if let brand = offer.brand {
                            Text("·")
                            Text(brand)
                                .foregroundStyle(ShelfTheme.accentSecondary)
                        }
                    }
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)

                    if let rating = offer.rating {
                        RatingStarsView(
                            rating: rating,
                            reviewCount: offer.reviewCount,
                            style: offer.source == .openFoodFacts ? .nutriScore : .stars
                        )
                    }

                    if offer.hasPrice {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(Formatters.currencyString(offer.price))
                                .font(.shelfStat)
                                .foregroundStyle(ShelfTheme.success)
                            if let original = offer.originalPrice, original > offer.price {
                                Text(Formatters.currencyString(original))
                                    .strikethrough()
                                    .foregroundStyle(ShelfTheme.textTertiary)
                            }
                            if offer.savings > 0 {
                                Text("Save \(Formatters.currencyString(offer.savings))")
                                    .foregroundStyle(ShelfTheme.accentSecondary)
                            }
                        }
                    }

                    if let notes = offer.notes {
                        Text(notes)
                            .font(.shelfBody)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }

                    if let url = offer.productURL {
                        Link(destination: url) {
                            Label("Open listing", systemImage: "arrow.up.right.square")
                                .font(.shelfSubheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(ShelfTheme.copper.opacity(0.15))
                                .foregroundStyle(ShelfTheme.copperLight)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    if let onAddToList {
                        Button(action: onAddToList) {
                            Label("Add to Shopping List", systemImage: "cart.badge.plus")
                                .font(.shelfHeadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(ShelfTheme.copperGradient.opacity(0.35))
                                .foregroundStyle(ShelfTheme.copperLight)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(ShelfPressButtonStyle())
                    }

                    if offer.hasPrice {
                        Button {
                            let alert = PriceAlert(
                                productName: offer.productName,
                                brand: offer.brand,
                                targetPrice: offer.price,
                                storeName: offer.storeName,
                                lastKnownPrice: offer.price
                            )
                            modelContext.insert(alert)
                            try? modelContext.save()
                            onPriceWatch?(offer.productName)
                            HapticManager.success()
                        } label: {
                            Label("Watch This Price", systemImage: "bell.badge.fill")
                                .font(.shelfSubheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(ShelfTheme.backgroundTertiary)
                                .foregroundStyle(ShelfTheme.copperLight)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding()
            }
            .background(ShelfGradientBackground())
            .navigationTitle("Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

struct ItemSearchOfferCard: View {
    let offer: ItemSearchOffer
    var onAddToList: (() -> Void)?

    var body: some View {
        GlassCard(padding: 12) {
            HStack(alignment: .top, spacing: 12) {
                productImage

                VStack(alignment: .leading, spacing: 6) {
                    Text(offer.productName)
                        .font(.shelfSubheadline)
                        .foregroundStyle(ShelfTheme.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        if let brand = offer.brand {
                            Text(brand)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.accentSecondary)
                        }
                        Label(offer.storeName, systemImage: offer.source.icon)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                        if let badge = DietBadgeService.badge(for: offer) {
                            Image(systemName: badge.icon)
                                .font(.caption2)
                                .foregroundStyle(badge.color)
                        }
                    }

                    if let rating = offer.rating {
                        RatingStarsView(
                            rating: rating,
                            reviewCount: offer.reviewCount,
                            style: offer.source == .openFoodFacts ? .nutriScore : .stars
                        )
                    }

                    if offer.hasPrice {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(Formatters.currencyString(offer.price))
                                .font(.shelfStatSmall)
                                .foregroundStyle(ShelfTheme.success)

                            if let original = offer.originalPrice, original > offer.price {
                                Text(Formatters.currencyString(original))
                                    .font(.shelfCaption)
                                    .strikethrough()
                                    .foregroundStyle(ShelfTheme.textTertiary)
                            }

                            if offer.savings > 0 {
                                Text("Save \(Formatters.currencyString(offer.savings))")
                                    .font(.shelfCaption)
                                    .foregroundStyle(ShelfTheme.accentSecondary)
                            }
                        }
                    }

                    if let distance = offer.distanceMeters {
                        Text(formatDistance(distance))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ShelfTheme.textTertiary)
                    }

                    if let notes = offer.notes {
                        Text(notes)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textTertiary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: 8) {
                    if let onAddToList {
                        Button(action: onAddToList) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(ShelfTheme.copperLight)
                        }
                        .buttonStyle(.plain)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(ShelfTheme.textTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var productImage: some View {
        if let imageURL = offer.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    sourceIcon
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            sourceIcon
        }
    }

    private var sourceIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ShelfTheme.copper.opacity(0.25), ShelfTheme.copper.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
            Image(systemName: offer.source.icon)
                .foregroundStyle(ShelfTheme.heroGradient)
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m away", meters)
        }
        return String(format: "%.1f mi away", meters / 1609.34)
    }
}

struct RatingStarsView: View {
    enum Style { case stars, nutriScore }

    let rating: Double
    let reviewCount: Int?
    var style: Style = .stars

    var body: some View {
        HStack(spacing: 4) {
            if style == .nutriScore {
                Text("Nutri-Score")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ShelfTheme.textTertiary)
            } else {
                HStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: starName(for: index))
                            .font(.system(size: 10))
                            .foregroundStyle(ShelfTheme.warning)
                    }
                }
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ShelfTheme.textSecondary)
            }

            if let count = reviewCount {
                Text("(\(count.formatted()))")
                    .font(.system(size: 10))
                    .foregroundStyle(ShelfTheme.textTertiary)
            }
        }
    }

    private func starName(for index: Int) -> String {
        let threshold = Double(index + 1)
        if rating >= threshold { return "star.fill" }
        if rating >= threshold - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

#Preview {
    NavigationStack {
        ItemSearchView()
    }
    .environment(LocationManager.shared)
    .modelContainer(PreviewModelContainer.shared)
}
