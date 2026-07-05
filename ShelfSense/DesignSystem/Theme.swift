//
//  Theme.swift
//  ShelfSense
//

import SwiftUI
import UIKit

enum ShelfTheme {
    // Copper brand palette (matches app icon)
    static let accent = Color("AccentTeal")
    static let accentSecondary = Color("AccentGold")
    static let copper = Color(red: 0.757, green: 0.498, blue: 0.231)
    static let copperLight = Color(red: 0.910, green: 0.651, blue: 0.357)
    static let copperGlow = Color(red: 0.950, green: 0.710, blue: 0.420)

    static let success = Color(red: 0.42, green: 0.78, blue: 0.58)
    static let warning = Color(red: 0.910, green: 0.651, blue: 0.357)
    static let danger = Color(red: 0.91, green: 0.36, blue: 0.31)

    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")
    static let backgroundTertiary = Color("BackgroundTertiary")
    static let cardBackground = Color("CardBackground")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")
    static let separator = Color("ShelfSeparator")

    static let cornerRadiusSmall: CGFloat = 12
    static let cornerRadiusMedium: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 24

    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20

    static var copperGradient: LinearGradient {
        LinearGradient(
            colors: [copperLight, copper, Color(red: 0.55, green: 0.32, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [copperGlow.opacity(0.9), accent, copper.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func configureAppearance() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor(ShelfTheme.backgroundSecondary)
        tabBar.shadowColor = UIColor(ShelfTheme.separator)
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let navBar = UINavigationBarAppearance()
        navBar.configureWithOpaqueBackground()
        navBar.backgroundColor = UIColor(ShelfTheme.backgroundPrimary)
        navBar.titleTextAttributes = [.foregroundColor: UIColor(ShelfTheme.textPrimary)]
        navBar.largeTitleTextAttributes = [.foregroundColor: UIColor(ShelfTheme.textPrimary)]
        UINavigationBar.appearance().standardAppearance = navBar
        UINavigationBar.appearance().scrollEdgeAppearance = navBar
        UINavigationBar.appearance().compactAppearance = navBar

        UISearchBar.appearance().tintColor = UIColor(ShelfTheme.accent)
    }
}

extension Font {
    static let shelfLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let shelfTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let shelfHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let shelfSubheadline = Font.system(.subheadline, design: .rounded, weight: .medium)
    static let shelfBody = Font.system(.body, design: .default)
    static let shelfCaption = Font.system(.caption, design: .rounded)
    static let shelfStat = Font.system(.title, design: .rounded, weight: .bold)
    static let shelfStatSmall = Font.system(.title3, design: .rounded, weight: .bold)
    static let shelfBrand = Font.system(.title3, design: .rounded, weight: .heavy)
}

extension View {
    func shelfBackground() -> some View {
        self.background(ShelfTheme.backgroundPrimary.ignoresSafeArea())
    }

    func shelfCardStyle(padding: CGFloat = ShelfTheme.cardPadding) -> some View {
        self
            .padding(padding)
            .background(ShelfTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ShelfTheme.cornerRadiusMedium, style: .continuous))
    }

    func copperGlow(radius: CGFloat = 8) -> some View {
        shadow(color: ShelfTheme.copper.opacity(0.35), radius: radius, y: 2)
    }
}

struct ShelfGradientBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ShelfTheme.backgroundPrimary
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    ShelfTheme.copper.opacity(animate ? 0.14 : 0.08),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    ShelfTheme.copperLight.opacity(animate ? 0.10 : 0.05),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.2),
                    Color.clear,
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct CopperGradientText: View {
    let text: String
    var font: Font = .shelfLargeTitle

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(ShelfTheme.heroGradient)
    }
}

struct ShelfInterestBadge: View {
    let text: String
    var icon: String = "sparkles"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
        }
        .foregroundStyle(ShelfTheme.copperLight)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(ShelfTheme.copper.opacity(0.16))
        .overlay {
            Capsule()
                .strokeBorder(ShelfTheme.copper.opacity(0.35), lineWidth: 0.5)
        }
        .clipShape(Capsule())
    }
}
