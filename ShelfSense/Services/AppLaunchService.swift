//
//  AppLaunchService.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum AppLaunchService {
    private static var didStart = false

    @MainActor
    static func configure(container: ModelContainer) {
        guard !didStart else { return }
        didStart = true

        AppDataBridge.configure(container: container)
        DealRefreshScheduler.shared.configure(container: container)
        CloudKitHouseholdService.shared.configure(container: container)

        Task(priority: .background) {
            await runDeferredStartup(using: container)
        }

        Task(priority: .utility) {
            await yieldToUI()
            QuestStore.shared.refreshIfNeeded()
            DealRefreshScheduler.shared.scheduleBackgroundRefresh()
            DealRefreshScheduler.shared.startForegroundTimer()
        }
    }

    @MainActor
    private static func runDeferredStartup(using container: ModelContainer) async {
        let context = container.mainContext

        await yieldToUI()

        LegacyDataCleaner.removeLegacySampleDataIfNeeded(context: context)
        HouseholdBootstrapService.bootstrap(context: context)
        RestockService.syncShoppingList(context: context)

        if let deals = try? context.fetch(FetchDescriptor<Deal>()) {
            PlayerLevelStore.shared.syncDealSavings(deals)
        }

        await yieldToUI()
        WidgetSnapshotSyncService.sync(context: context)

        LocationManager.shared.configure(context: context)

        // Wait until the home screen has mounted.
        try? await Task.sleep(for: .seconds(6))

        await CloudKitHouseholdService.shared.refreshAccountStatus()
        await LocationManager.shared.requestPermissions()

        await DealEngine.shared.refreshStaleStores(context: context, maxStores: 1)

        evaluatePriceAlerts(context: context)
        await CloudKitHouseholdService.shared.syncSharedData(context: context)
        WidgetSnapshotSyncService.sync(context: context)
    }

    @MainActor
    private static func yieldToUI() async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))
    }

    @MainActor
    private static func evaluatePriceAlerts(context: ModelContext) {
        let deals = (try? context.fetch(FetchDescriptor<Deal>())) ?? []
        let alerts = (try? context.fetch(FetchDescriptor<PriceAlert>())) ?? []
        PriceAlertService.evaluate(deals: deals, alerts: alerts)
        try? context.save()
    }
}
