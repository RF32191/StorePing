//
//  ShelfSenseWidgets.swift
//  ShelfSenseWidget
//

import WidgetKit
import SwiftUI

// MARK: - Theme

private enum WidgetColors {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let card = Color(red: 0.12, green: 0.11, blue: 0.10)
    static let copper = Color(red: 0.72, green: 0.45, blue: 0.20)
    static let copperLight = Color(red: 0.85, green: 0.65, blue: 0.42)
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)
    static let success = Color(red: 0.45, green: 0.78, blue: 0.52)
}

private struct WidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [WidgetColors.background, WidgetColors.card],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
    }
}

// MARK: - Provider

struct ShelfSenseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShelfSenseWidgetEntry {
        ShelfSenseWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShelfSenseWidgetEntry) -> Void) {
        completion(ShelfSenseWidgetEntry(date: Date(), snapshot: WidgetSharedDataStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShelfSenseWidgetEntry>) -> Void) {
        let entry = ShelfSenseWidgetEntry(date: Date(), snapshot: WidgetSharedDataStore.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct ShelfSenseWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - Shopping List

struct ShoppingListWidget: Widget {
    let kind = "ShoppingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShelfSenseTimelineProvider()) { entry in
            ShoppingListWidgetView(snapshot: entry.snapshot)
                .modifier(WidgetBackground())
        }
        .configurationDisplayName("Shopping List")
        .description("Your active list items at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ShoppingListWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundStyle(WidgetColors.copperLight)
                Text("Shopping List")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.textPrimary)
                Spacer()
                Text("\(snapshot.shoppingListCount)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.background)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(WidgetColors.copper))
            }

            if snapshot.shoppingListItems.isEmpty {
                Spacer()
                Text("List is empty")
                    .font(.caption)
                    .foregroundStyle(WidgetColors.textSecondary)
                Spacer()
            } else {
                ForEach(snapshot.shoppingListItems.prefix(family == .systemSmall ? 3 : 5), id: \.self) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .strokeBorder(WidgetColors.textSecondary, lineWidth: 1)
                            .frame(width: 10, height: 10)
                        Text(item)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WidgetColors.textPrimary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if snapshot.estimatedListTotal > 0 {
                    Text("Est. \(snapshot.estimatedListTotal, format: .currency(code: "USD"))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WidgetColors.success)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Level Badge

struct LevelBadgeWidget: Widget {
    let kind = "LevelBadgeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShelfSenseTimelineProvider()) { entry in
            LevelBadgeWidgetView(snapshot: entry.snapshot)
                .modifier(WidgetBackground())
        }
        .configurationDisplayName("Level & Savings")
        .description("Your arcade level and lifetime savings.")
        .supportedFamilies([.systemSmall])
    }
}

struct LevelBadgeWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: snapshot.rankIcon)
                .font(.title2)
                .foregroundStyle(WidgetColors.copperLight)

            Text("Lv \(snapshot.level)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(WidgetColors.copperLight)

            Text(snapshot.rankTitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetColors.textSecondary)
                .lineLimit(1)

            ProgressView(value: snapshot.xpProgress)
                .tint(WidgetColors.copper)

            Text(snapshot.lifetimeSavings, format: .currency(code: "USD"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(WidgetColors.success)

            Text("saved")
                .font(.system(size: 9))
                .foregroundStyle(WidgetColors.textSecondary)
        }
        .padding(14)
    }
}

// MARK: - Expiring Soon

struct ExpiringSoonWidget: Widget {
    let kind = "ExpiringSoonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShelfSenseTimelineProvider()) { entry in
            ExpiringSoonWidgetView(snapshot: entry.snapshot)
                .modifier(WidgetBackground())
        }
        .configurationDisplayName("Expiring Soon")
        .description("Pantry items to use up before they go bad.")
        .supportedFamilies([.systemSmall])
    }
}

struct ExpiringSoonWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(WidgetColors.copper)
                Text("Expiring")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.textPrimary)
                Spacer()
                if snapshot.expiringCount > 0 {
                    Text("\(snapshot.expiringCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(WidgetColors.copperLight)
                }
            }

            if snapshot.expiringItems.isEmpty {
                Spacer()
                Label("All good!", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(WidgetColors.success)
                Spacer()
            } else {
                ForEach(snapshot.expiringItems.prefix(3), id: \.self) { item in
                    Text(item)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WidgetColors.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
    }
}

// MARK: - Daily Quests

struct DailyQuestsWidget: Widget {
    let kind = "DailyQuestsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShelfSenseTimelineProvider()) { entry in
            DailyQuestsWidgetView(snapshot: entry.snapshot)
                .modifier(WidgetBackground())
        }
        .configurationDisplayName("Daily Quests")
        .description("Quest progress and streak.")
        .supportedFamilies([.systemMedium])
    }
}

struct DailyQuestsWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Daily Quests", systemImage: "flag.checkered")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.textPrimary)

                Text("\(snapshot.questsCompleted)/\(snapshot.questsTotal) complete")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetColors.copperLight)

                Text("\(snapshot.questStreak)-day streak")
                    .font(.caption)
                    .foregroundStyle(WidgetColors.textSecondary)

                Spacer(minLength: 0)

                Text("Open \(AppBrand.name) to claim XP")
                    .font(.system(size: 9))
                    .foregroundStyle(WidgetColors.textSecondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(WidgetColors.card, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: questProgress)
                    .stroke(WidgetColors.copper, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(questProgress * 100))%")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.copperLight)
                    Text("done")
                        .font(.system(size: 8))
                        .foregroundStyle(WidgetColors.textSecondary)
                }
            }
            .frame(width: 72, height: 72)
        }
        .padding(14)
    }

    private var questProgress: Double {
        guard snapshot.questsTotal > 0 else { return 0 }
        return Double(snapshot.questsCompleted) / Double(snapshot.questsTotal)
    }
}

// MARK: - Dashboard (Large)

struct ShelfSenseDashboardWidget: Widget {
    let kind = "ShelfSenseDashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShelfSenseTimelineProvider()) { entry in
            ShelfSenseDashboardWidgetView(snapshot: entry.snapshot)
                .modifier(WidgetBackground())
        }
        .configurationDisplayName(AppBrand.dashboardWidgetTitle)
        .description("List, level, expiring items, and quests in one view.")
        .supportedFamilies([.systemLarge])
    }
}

struct ShelfSenseDashboardWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppBrand.name)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.copperLight)
                    Text("Lv \(snapshot.level) · \(snapshot.rankTitle)")
                        .font(.caption)
                        .foregroundStyle(WidgetColors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(snapshot.lifetimeSavings, format: .currency(code: "USD"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WidgetColors.success)
                    Text("lifetime saved")
                        .font(.system(size: 9))
                        .foregroundStyle(WidgetColors.textSecondary)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                dashSection(title: "List", icon: "cart.fill", count: snapshot.shoppingListCount) {
                    ForEach(snapshot.shoppingListItems.prefix(4), id: \.self) { item in
                        Text("• \(item)").font(.system(size: 11)).lineLimit(1)
                    }
                    if snapshot.shoppingListItems.isEmpty {
                        Text("Empty").font(.caption2).foregroundStyle(WidgetColors.textSecondary)
                    }
                }

                dashSection(title: "Expiring", icon: "clock.badge.exclamationmark", count: snapshot.expiringCount) {
                    ForEach(snapshot.expiringItems.prefix(3), id: \.self) { item in
                        Text("• \(item)").font(.system(size: 11)).lineLimit(1)
                    }
                    if snapshot.expiringItems.isEmpty {
                        Text("None").font(.caption2).foregroundStyle(WidgetColors.textSecondary)
                    }
                }
            }

            HStack {
                Label("\(snapshot.questsCompleted)/\(snapshot.questsTotal) quests", systemImage: "flag.checkered")
                Spacer()
                Text("\(snapshot.questStreak)d streak")
                Spacer()
                Text(snapshot.monthlySavings, format: .currency(code: "USD"))
                    .foregroundStyle(WidgetColors.success)
                + Text(" this mo.")
                    .foregroundStyle(WidgetColors.textSecondary)
            }
            .font(.system(size: 10, weight: .medium))
        }
        .padding(16)
    }

    @ViewBuilder
    private func dashSection<Content: View>(
        title: String,
        icon: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2).foregroundStyle(WidgetColors.copper)
                Text(title).font(.system(size: 11, weight: .bold)).foregroundStyle(WidgetColors.textPrimary)
                Text("(\(count))").font(.caption2).foregroundStyle(WidgetColors.textSecondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                content()
            }
            .foregroundStyle(WidgetColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(WidgetColors.card.opacity(0.8)))
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    ShoppingListWidget()
} timeline: {
    ShelfSenseWidgetEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .systemSmall) {
    LevelBadgeWidget()
} timeline: {
    ShelfSenseWidgetEntry(date: .now, snapshot: .placeholder)
}
