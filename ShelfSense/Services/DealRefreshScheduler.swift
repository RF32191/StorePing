//
//  DealRefreshScheduler.swift
//  ShelfSense
//

import BackgroundTasks
import Foundation
import SwiftData

@MainActor
final class DealRefreshScheduler {
    static let shared = DealRefreshScheduler()
    static let taskIdentifier = "Fermoselle.ShelfSense.dealrefresh"

    private let refreshInterval: TimeInterval = 12 * 60 * 60
    private var foregroundTimer: Timer?
    private weak var modelContainer: ModelContainer?

    private init() {}

    func configure(container: ModelContainer) {
        modelContainer = container
    }

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await self.handleBackgroundRefresh(task: refreshTask)
            }
        }
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    func startForegroundTimer() {
        foregroundTimer?.invalidate()
        foregroundTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performRefresh(reason: "Scheduled refresh")
            }
        }
    }

    func refreshIfNeeded() async {
        guard let context = modelContainer?.mainContext else { return }
        let stores = (try? context.fetch(FetchDescriptor<Store>())) ?? []
        guard stores.contains(where: \.needsDealRefresh) else { return }
        await DealEngine.shared.refreshStaleStores(context: context, maxStores: 2)
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) async {
        scheduleBackgroundRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        await performRefresh(reason: "Background refresh")
        task.setTaskCompleted(success: true)
    }

    private func performRefresh(reason: String) async {
        guard let context = modelContainer?.mainContext else { return }
        await DealEngine.shared.refreshStaleStores(context: context, maxStores: 4)
    }
}
