//
//  StoresView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct StoresView: View {
    @Query(sort: \Store.name) private var stores: [Store]
    @Environment(DealEngine.self) private var dealEngine
    @Environment(\.modelContext) private var modelContext

    @State private var showAddStore = false
    @State private var showBusinessSearch = false
    @State private var isRefreshing = false

    var body: some View {
        List {
            if stores.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "storefront")
                            .font(.largeTitle)
                            .foregroundStyle(ShelfTheme.textTertiary)
                        Text("Add your favorite stores")
                            .font(.shelfHeadline)
                        Text("\(AppBrand.name) will track weekly ads, match deals to your inventory, and alert you when you're nearby.")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(stores, id: \.id) { store in
                        NavigationLink {
                            StoreDetailView(store: store)
                        } label: {
                            StoreRow(store: store)
                        }
                    }
                    .onDelete(perform: deleteStores)
                } header: {
                    Text("Your Stores")
                } footer: {
                    Text("Each store refreshes deals from its weekly ad link and your inventory every 12 hours.")
                }
            }
        }
        .navigationTitle("Stores")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showBusinessSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
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

            if !stores.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .sheet(isPresented: $showAddStore) {
            AddStoreView()
        }
        .sheet(isPresented: $showBusinessSearch) {
            BusinessSearchView()
        }
    }

    private func refreshAll() async {
        isRefreshing = true
        await dealEngine.refreshAllStores(context: modelContext)
        isRefreshing = false
        HapticManager.success()
    }

    private func deleteStores(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(stores[index])
        }
        LocationManager.shared.refreshGeofences()
    }
}

struct StoreRow: View {
    let store: Store

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: store.chain.icon)
                .foregroundStyle(ShelfTheme.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.shelfSubheadline)

                HStack(spacing: 6) {
                    if store.isFavorite {
                        Text("Favorite")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ShelfTheme.accent.opacity(0.15))
                            .foregroundStyle(ShelfTheme.accent)
                            .clipShape(Capsule())
                    }

                    if store.needsDealRefresh {
                        Text("Update deals")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ShelfTheme.warning.opacity(0.15))
                            .foregroundStyle(ShelfTheme.warning)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}
