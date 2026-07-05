//
//  MainTabView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case search
    case gps
    case inventory
    case deals
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Home"
        case .search: "Search"
        case .gps: "Near Me"
        case .inventory: "Inventory"
        case .deals: "Deals"
        case .more: "More"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "house.fill"
        case .search: "cart.circle.fill"
        case .gps: "location.fill"
        case .inventory: "archivebox.fill"
        case .deals: "tag.fill"
        case .more: "ellipsis.circle.fill"
        }
    }
}

private enum MainSheet: String, Identifiable {
    case profile
    case scan
    case paywall

    var id: String { rawValue }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: AppTab = .dashboard
    @State private var dashboardLayout = DashboardLayoutStore()
    @State private var playerStore = PlayerLevelStore.shared
    @State private var tutorialStore = TutorialStore.shared
    @State private var premiumStore = PremiumAccessStore.shared
    @State private var activeSheet: MainSheet?
    @State private var dashboardReady = false
    @State private var visitedTabs: Set<AppTab> = [.dashboard]

    var body: some View {
        VStack(spacing: 0) {
            AppGlobalTopBar(
                premiumStore: premiumStore,
                playerStore: playerStore,
                tutorialStore: tutorialStore,
                reservesHomeLeadingSpace: selectedTab == .dashboard,
                onScan: { activeSheet = .scan },
                onShowPaywall: {
                    premiumStore.beginStoreServicesIfNeeded()
                    activeSheet = .paywall
                },
                onShowProfile: { activeSheet = .profile }
            )
            .background {
                ShelfTheme.backgroundPrimary.opacity(0.72)
                    .background(.ultraThinMaterial)
            }

            ZStack {
                activeTabContent

                VStack {
                    if playerStore.showXPGainToast, let xp = playerStore.recentXPGain {
                        XPGainToast(amount: xp)
                            .padding(.top, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                }
                .animation(ShelfMotion.spring, value: playerStore.showXPGainToast)

                if tutorialStore.isPresented {
                    TutorialWalkthroughView(tutorialStore: tutorialStore) { tab in
                        selectedTab = tab
                        visitedTabs.insert(tab)
                    }
                    .transition(.opacity)
                    .zIndex(20)
                }

                if let event = playerStore.activeLevelUp {
                    LevelUpOverlayView(event: event) {
                        playerStore.dismissLevelUp()
                    }
                    .zIndex(30)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background {
            LaunchBackdrop.view.ignoresSafeArea()
        }
        .environment(LocationManager.shared)
        .environment(DealEngine.shared)
        .environment(playerStore)
        .environment(tutorialStore)
        .environment(premiumStore)
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .onChange(of: premiumStore.paywallPresented) { _, shouldShow in
            guard shouldShow else { return }
            activeSheet = .paywall
        }
        .onChange(of: activeSheet) { _, sheet in
            if sheet != .paywall, premiumStore.paywallPresented {
                premiumStore.dismissPaywall()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                dashboardReady = true
            }

            if !tutorialStore.hasCompletedTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    tutorialStore.present()
                }
            }
        }
        .onChange(of: selectedTab) { _, tab in
            visitedTabs.insert(tab)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: MainSheet) -> some View {
        Group {
            switch sheet {
            case .profile:
                ProfileView()
            case .scan:
                ScanHubView()
            case .paywall:
                PaywallView(premiumStore: premiumStore)
            }
        }
        .modelContainer(modelContext.container)
        .environment(playerStore)
        .environment(premiumStore)
        .environment(tutorialStore)
        .environment(LocationManager.shared)
        .environment(DealEngine.shared)
    }

    @ViewBuilder
    private var activeTabContent: some View {
        switch selectedTab {
        case .dashboard:
            if dashboardReady {
                DashboardView(layoutStore: dashboardLayout)
            } else {
                HomeLaunchShellView()
            }
        case .search:
            if visitedTabs.contains(.search) {
                NavigationStack { ItemSearchView() }
            }
        case .gps:
            if visitedTabs.contains(.gps) {
                GPSView()
            }
        case .inventory:
            if visitedTabs.contains(.inventory) {
                InventoryView()
            }
        case .deals:
            if visitedTabs.contains(.deals) {
                DealsView()
            }
        case .more:
            if visitedTabs.contains(.more) {
                MoreView(layoutStore: dashboardLayout)
            }
        }
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Divider().background(ShelfTheme.backgroundTertiary)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        guard selectedTab != tab else { return }
                        selectedTab = tab
                        visitedTabs.insert(tab)
                        HapticManager.selection()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? ShelfTheme.accentSecondary : ShelfTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .background {
            ShelfTheme.backgroundSecondary
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
