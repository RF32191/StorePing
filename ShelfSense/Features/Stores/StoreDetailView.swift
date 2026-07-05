//
//  StoreDetailView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct StoreDetailView: View {
    @Bindable var store: Store
    @Environment(\.modelContext) private var modelContext
    @Environment(DealEngine.self) private var dealEngine

    @Query private var allDeals: [Deal]
    @State private var showAddDeal = false
    @State private var isRefreshing = false

    private var storeDeals: [Deal] {
        allDeals
            .filter { ($0.storeID == store.id || $0.storeName == store.name) && $0.isActive }
            .sorted { $0.discountPercent > $1.discountPercent }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                storeHeader

                actionButtons

                if storeDeals.isEmpty {
                    emptyDeals
                } else {
                    ForEach(storeDeals, id: \.id) { deal in
                        DealCard(deal: deal)
                    }
                }
            }
            .padding()
        }
        .background(ShelfGradientBackground())
        .navigationTitle(store.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddDeal = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ShelfTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showAddDeal) {
            AddDealView(store: store)
        }
        .refreshable {
            await refreshDeals()
        }
    }

    private var storeHeader: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: store.chain.icon)
                        .font(.title2)
                        .foregroundStyle(ShelfTheme.accent)
                    VStack(alignment: .leading) {
                        Text(store.chain.displayName)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                        if let address = store.address {
                            Text(address)
                                .font(.shelfSubheadline)
                        }
                    }
                    Spacer()
                    if store.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(ShelfTheme.danger)
                    }
                }

                if let last = store.lastDealRefresh {
                    Text("Deals updated \(Formatters.relativeString(from: last))")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textTertiary)
                } else {
                    Text("Deals not refreshed yet")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textTertiary)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                Task { await refreshDeals() }
            } label: {
                Label(isRefreshing ? "Updating…" : "Refresh Deals", systemImage: "arrow.clockwise")
                    .font(.shelfCaption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ShelfTheme.accent.opacity(0.12))
                    .foregroundStyle(ShelfTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(isRefreshing)

            if let urlString = store.weeklyAdURL ?? store.chain.weeklyAdURL?.absoluteString,
               let url = URL(string: urlString) {
                Link(destination: url) {
                    Label("Weekly Ad", systemImage: "newspaper.fill")
                        .font(.shelfCaption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ShelfTheme.accentSecondary.opacity(0.12))
                        .foregroundStyle(ShelfTheme.accentSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            Button {
                AppleMapsNavigation.openDirections(to: store)
            } label: {
                Label("Directions", systemImage: "map.fill")
                    .font(.shelfCaption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ShelfTheme.backgroundSecondary)
                    .foregroundStyle(ShelfTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var emptyDeals: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "tag.slash")
                    .font(.title2)
                    .foregroundStyle(ShelfTheme.textTertiary)
                Text("No deals yet")
                    .font(.shelfHeadline)
                Text("Tap Refresh to pull the weekly ad link, or add deals you spot in-store.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func refreshDeals() async {
        isRefreshing = true
        await dealEngine.refreshStore(store, context: modelContext)
        isRefreshing = false
        HapticManager.success()
    }
}
