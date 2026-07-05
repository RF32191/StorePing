//
//  DashboardView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager
    @Environment(PlayerLevelStore.self) private var playerStore
    @Environment(PremiumAccessStore.self) private var premiumStore
    @Bindable var layoutStore: DashboardLayoutStore
    @Query private var inventoryItems: [InventoryItem]
    @Query private var deals: [Deal]
    @Query private var listItems: [ShoppingListItem]
    @Query private var receipts: [Receipt]
    @Query private var stores: [Store]
    @Query private var budgets: [Budget]

    @State private var showProfile = false
    @State private var showItemSearch = false
    @State private var searchText = ""
    @State private var renderedWidgetCount = 2
    @State private var showLocationBanner = false

    init(layoutStore: DashboardLayoutStore) {
        self.layoutStore = layoutStore

        var inventoryDescriptor = FetchDescriptor<InventoryItem>(sortBy: [SortDescriptor(\.name)])
        inventoryDescriptor.fetchLimit = 80
        _inventoryItems = Query(inventoryDescriptor)

        var dealDescriptor = FetchDescriptor<Deal>(sortBy: [SortDescriptor(\.discountPercent, order: .reverse)])
        dealDescriptor.fetchLimit = 40
        _deals = Query(dealDescriptor)

        var listDescriptor = FetchDescriptor<ShoppingListItem>()
        listDescriptor.fetchLimit = 50
        _listItems = Query(listDescriptor)

        var receiptDescriptor = FetchDescriptor<Receipt>(sortBy: [SortDescriptor(\.purchaseDate, order: .reverse)])
        receiptDescriptor.fetchLimit = 24
        _receipts = Query(receiptDescriptor)

        var storeDescriptor = FetchDescriptor<Store>(sortBy: [SortDescriptor(\.name)])
        storeDescriptor.fetchLimit = 40
        _stores = Query(storeDescriptor)

        var budgetDescriptor = FetchDescriptor<Budget>()
        budgetDescriptor.fetchLimit = 12
        _budgets = Query(budgetDescriptor)
    }

    private var visibleWidgets: [DashboardWidgetType] {
        Array(layoutStore.visibleWidgetOrder.prefix(renderedWidgetCount))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if layoutStore.isEditing {
                    List {
                        Section {
                            editModeBanner
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        Section("Widgets") {
                            ForEach(layoutStore.widgetOrder) { widgetType in
                                HStack(spacing: 10) {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundStyle(ShelfTheme.textTertiary)
                                    Image(systemName: widgetType.icon)
                                        .foregroundStyle(ShelfTheme.accent)
                                    Text(widgetType.title)
                                        .font(.shelfSubheadline)
                                        .foregroundStyle(layoutStore.isVisible(widgetType) ? ShelfTheme.textPrimary : ShelfTheme.textTertiary)
                                    Spacer()
                                    Button {
                                        layoutStore.toggleVisibility(widgetType)
                                    } label: {
                                        Image(systemName: layoutStore.isVisible(widgetType) ? "eye.fill" : "eye.slash")
                                            .foregroundStyle(layoutStore.isVisible(widgetType) ? ShelfTheme.copperLight : ShelfTheme.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .onMove { source, destination in
                                layoutStore.move(from: source, to: destination)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .shelfScrollBottomInset()
                    .shelfScrollContentInsets()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: ShelfTheme.sectionSpacing) {
                            headerSection

                            if showLocationBanner {
                                LocationPrivacyBanner(locationManager: locationManager, compact: true)
                            }

                            LazyVStack(spacing: 16) {
                                ForEach(visibleWidgets) { widgetType in
                                    DashboardWidgetContainer(
                                        widgetType: widgetType,
                                        isEditing: false,
                                        inventoryItems: inventoryItems,
                                        deals: deals,
                                        listItems: listItems,
                                        receipts: receipts,
                                        stores: stores,
                                        budgets: budgets
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .shelfScrollBottomInset()
                    }
                    .shelfScrollContentInsets()
                    .onAppear {
                        expandWidgetsProgressively()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            showLocationBanner = true
                        }
                    }
                }
            }
            .background(ShelfGradientBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showProfile = true
                        HapticManager.lightImpact()
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(ShelfTheme.accent)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showItemSearch = true
                            HapticManager.lightImpact()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.body.weight(.semibold))
                        }

                        Button {
                            withAnimation(.spring(response: 0.35)) {
                                layoutStore.isEditing.toggle()
                            }
                            HapticManager.selection()
                        } label: {
                            Text(layoutStore.isEditing ? "Done" : "Edit")
                                .font(.shelfSubheadline)
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .modelContainer(modelContext.container)
                    .environment(playerStore)
                    .environment(premiumStore)
                    .environment(LocationManager.shared)
                    .environment(DealEngine.shared)
            }
            .sheet(isPresented: $showItemSearch) {
                NavigationStack {
                    ItemSearchView()
                }
            }
        }
    }

    private func expandWidgetsProgressively() {
        let total = layoutStore.visibleWidgetOrder.count
        guard renderedWidgetCount < total else { return }

        Task { @MainActor in
            while renderedWidgetCount < total {
                try? await Task.sleep(for: .milliseconds(120))
                renderedWidgetCount = min(renderedWidgetCount + 2, total)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShelfInterestBadge(text: "Item Discovery", icon: "sparkles")

            Text(greeting)
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.textSecondary)

            CopperGradientText(text: AppBrand.name)

            Text("Track what you love · compare prices · shop smarter")
                .font(.shelfSubheadline)
                .foregroundStyle(ShelfTheme.textTertiary)
        }
        .padding(.top, 8)
    }

    private var editModeBanner: some View {
        GlassCard(padding: 12) {
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(ShelfTheme.accent)

                Text("Drag to reorder · tap eye to show/hide")
                    .font(.shelfSubheadline)
                    .foregroundStyle(ShelfTheme.textSecondary)

                Spacer()

                Button("Reset") {
                    layoutStore.resetToDefault()
                }
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.accentSecondary)
            }
        }
    }
}

#Preview {
    DashboardView(layoutStore: DashboardLayoutStore())
        .environment(LocationManager.shared)
        .modelContainer(PreviewModelContainer.shared)
}
