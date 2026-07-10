//
//  ProfileView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerLevelStore.self) private var playerStore
    @Environment(PremiumAccessStore.self) private var premiumStore
    @Query private var budgets: [Budget]
    @Query private var stores: [Store]
    @Query private var deals: [Deal]
    @State private var showResetDatabaseAlert = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                profileHeader
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                Section {
                    PlayerLevelCard(playerStore: playerStore)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                if !premiumStore.isPremium {
                    Section {
                        Button {
                            premiumStore.beginStoreServicesIfNeeded()
                            showPaywall = true
                        } label: {
                            Label("Upgrade to \(AppBrand.proName)", systemImage: "crown.fill")
                                .foregroundStyle(ShelfTheme.copperLight)
                        }
                    }
                }

                Section("Arcade Stats") {
                    LabeledContent("Rank", value: playerStore.rank.title)
                    LabeledContent("Total XP", value: "\(playerStore.totalXP)")
                    LabeledContent("Lifetime saved", value: Formatters.currencyString(playerStore.lifetimeSavings))
                    LabeledContent("Active deal savings", value: Formatters.currencyString(activeDealSavings))
                    NavigationLink { AchievementsView() } label: {
                        Label("Achievements", systemImage: "rosette")
                    }
                }

                Section("Household") {
                    NavigationLink { FamilySharingView() } label: {
                        Label("Family Sharing", systemImage: "person.2.fill")
                    }
                    NavigationLink { NotificationSettingsView() } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    NavigationLink { GeofencingSettingsView() } label: {
                        Label("Store Geofencing", systemImage: "location.fill")
                    }
                }

                Section("Finance") {
                    ForEach(budgets, id: \.id) { budget in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(budget.name)
                                    .font(.shelfSubheadline)
                                Text("\(Formatters.currencyString(budget.currentSpent)) of \(Formatters.currencyString(budget.monthlyLimit))")
                                    .font(.shelfCaption)
                                    .foregroundStyle(ShelfTheme.textSecondary)
                            }
                            Spacer()
                            CircularProgressView(progress: budget.progress, tint: budget.isNearLimit ? ShelfTheme.warning : ShelfTheme.accent)
                                .frame(width: 36, height: 36)
                        }
                    }

                    NavigationLink { SpendingAnalyticsView() } label: {
                        Label("Spending Analytics", systemImage: "chart.bar.fill")
                    }
                }

                Section("Stores & Deals") {
                    NavigationLink { BusinessSearchView() } label: {
                        Label("Find Businesses", systemImage: "magnifyingglass")
                    }
                    NavigationLink { StoresView() } label: {
                        Label("Manage Stores", systemImage: "storefront.fill")
                    }

                    ForEach(stores.filter(\.isFavorite), id: \.id) { store in
                        NavigationLink {
                            StoreDetailView(store: store)
                        } label: {
                            HStack {
                                Image(systemName: store.chain.icon)
                                    .foregroundStyle(ShelfTheme.accent)
                                Text(store.name)
                                Spacer()
                                Text("\(Int(store.notificationRadiusMeters))m")
                                    .font(.shelfCaption)
                                    .foregroundStyle(ShelfTheme.textTertiary)
                            }
                        }
                    }
                }

                Section("Security & Privacy") {
                    Label("Face ID Enabled", systemImage: "faceid")
                    Label("Encrypted Cloud Backup", systemImage: "lock.shield.fill")
                    Label("Privacy-First Architecture", systemImage: "hand.raised.fill")
                    Label("Location Stays On Device", systemImage: "location.fill.viewfinder")
                }

                if ModelContainerFactory.usedInMemoryFallback {
                    Section {
                        Text("Local storage had to be reset temporarily. Force quit and reopen \(AppBrand.name), or use Reset Local Database below.")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.warning)
                    }
                }

                Section("Troubleshooting") {
                    Button("Reset Local Database", role: .destructive) {
                        showResetDatabaseAlert = true
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text(AppBrand.name)
                                .font(.shelfSubheadline)
                                .foregroundStyle(ShelfTheme.textSecondary)
                            Text("Version 1.0")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textTertiary)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(ShelfGradientBackground())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .shelfScrollBottomInset()
            .shelfScrollContentInsets()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset Local Database?", isPresented: $showResetDatabaseAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    ModelContainerFactory.resetAllStoresOnDisk()
                }
            } message: {
                Text("This deletes local inventory, lists, and receipts on this device. Force quit \(AppBrand.name), then open it again.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(premiumStore: premiumStore)
            }
        }
    }

    private var activeDealSavings: Double {
        deals.filter(\.isActive).reduce(0) { $0 + $1.savings }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ShelfTheme.copperGradient.opacity(0.25))
                    .frame(width: 92, height: 92)
                Image(systemName: playerStore.rank.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(ShelfTheme.heroGradient)
            }

            Text("Level \(playerStore.level)")
                .font(.shelfTitle)
                .foregroundStyle(ShelfTheme.copperLight)

            Text(playerStore.rank.title)
                .font(.shelfHeadline)
                .foregroundStyle(ShelfTheme.textPrimary)

            Text(AppBrand.saverTitle)
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.accentSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(ShelfTheme.accentSecondary.opacity(0.15))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(ShelfTheme.backgroundTertiary, lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(ShelfTheme.textSecondary)
        }
    }
}

#Preview {
    ProfileView()
        .environment(PlayerLevelStore.shared)
        .environment(PremiumAccessStore.shared)
        .modelContainer(PreviewModelContainer.shared)
}
