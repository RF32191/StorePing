//
//  ShelfSenseApp.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

@main
struct ShelfSenseApp: App {
    @UIApplicationDelegateAdaptor(ShelfSenseAppDelegate.self) private var appDelegate

    @State private var locationManager = LocationManager.shared
    @State private var dealEngine = DealEngine.shared
    @State private var container: ModelContainer?

    var body: some Scene {
        WindowGroup {
            ZStack {
                LaunchBackdrop.view

                if let container {
                    MainTabView()
                        .modelContainer(container)
                        .transition(.opacity)
                } else {
                    LaunchSplashView()
                }
            }
            .animation(.easeOut(duration: 0.25), value: container != nil)
            .preferredColorScheme(.dark)
            .environment(locationManager)
            .environment(dealEngine)
            .task {
                await loadContainerIfNeeded()
            }
        }
    }

    @MainActor
    private func loadContainerIfNeeded() async {
        guard container == nil else { return }

        // Paint splash first — avoids launch watchdog kills.
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(32))

        let loaded = ModelContainerFactory.makeSharedContainer()

        await Task.yield()
        ShelfTheme.configureAppearance()
        container = loaded

        // Defer non-critical services until the first frame is on screen.
        Task(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(400))
            DealRefreshScheduler.shared.registerBackgroundTask()
            AppLaunchService.configure(container: loaded)
        }
    }
}
