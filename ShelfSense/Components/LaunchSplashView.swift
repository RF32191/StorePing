//
//  LaunchSplashView.swift
//  ShelfSense
//

import SwiftUI

enum LaunchBackdrop {
    static let copperLight = Color(red: 0.910, green: 0.651, blue: 0.357)
    static let base = Color(red: 0.11, green: 0.10, blue: 0.095)

    static var view: some View {
        ZStack {
            base
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.11, blue: 0.09),
                    base,
                    Color(red: 0.08, green: 0.08, blue: 0.085),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

/// Instant first frame — hardcoded colors, no SwiftData, no asset dependencies.
struct LaunchSplashView: View {
    var message: String = AppBrand.name

    var body: some View {
        ZStack {
            LaunchBackdrop.view

            VStack(spacing: 20) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(LaunchBackdrop.copperLight)

                ProgressView()
                    .controlSize(.large)
                    .tint(LaunchBackdrop.copperLight)

                Text(message)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))

                Text("Loading your pantry…")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
    }
}

/// Lightweight home placeholder shown before heavy dashboard queries mount.
struct HomeLaunchShellView: View {
    var body: some View {
        ZStack {
            LaunchBackdrop.view

            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "house.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(LaunchBackdrop.copperLight)

                Text("Setting up Home…")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))

                ProgressView()
                    .tint(LaunchBackdrop.copperLight)

                Spacer()
                Spacer()
            }
        }
    }
}
