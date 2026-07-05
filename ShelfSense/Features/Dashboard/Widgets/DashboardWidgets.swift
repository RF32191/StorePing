//
//  DashboardWidgets.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

// MARK: - Widget Shell

struct DashboardWidgetShell<Content: View>: View {
    let title: String
    let icon: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(ShelfTheme.accent)

                    Text(title)
                        .font(.shelfHeadline)
                        .foregroundStyle(ShelfTheme.textPrimary)

                    Spacer()

                    if let actionTitle, let action {
                        Button(actionTitle, action: action)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.accent)
                    }
                }

                content()
            }
        }
    }
}

struct WidgetRow: View {
    let title: String
    let subtitle: String
    let trailing: String?
    let icon: String
    var tint: Color = ShelfTheme.accent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.shelfSubheadline)
                    .foregroundStyle(ShelfTheme.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.shelfSubheadline)
                    .foregroundStyle(ShelfTheme.accentSecondary)
            }
        }
    }
}

// MARK: - Individual Widgets

struct TodaysDealsWidget: View {
    let deals: [Deal]

    var body: some View {
        DashboardWidgetShell(title: "Today's Deals", icon: "tag.fill", actionTitle: "See all") {
            if deals.isEmpty {
                emptyState("No deals today")
            } else {
                VStack(spacing: 10) {
                    ForEach(deals.prefix(3), id: \.id) { deal in
                        WidgetRow(
                            title: deal.productName,
                            subtitle: deal.storeName,
                            trailing: Formatters.percentString(deal.discountPercent) + " off",
                            icon: "tag.fill",
                            tint: ShelfTheme.accentSecondary
                        )
                    }
                }
            }
        }
    }
}

struct NearbyStoreAlertsWidget: View {
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        DashboardWidgetShell(title: "Nearby Store Alerts", icon: "location.fill") {
            if locationManager.activeNearbyStores.isEmpty && locationManager.nearbyAlerts.isEmpty {
                VStack(spacing: 8) {
                    if !locationManager.isLocationAvailable {
                        Text("Enable location to get nearby store alerts")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textTertiary)
                    } else if locationManager.isMonitoringActive {
                        Text("Monitoring \(locationManager.monitoredRegionCount) stores locally")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textTertiary)
                    } else {
                        emptyState("No stores nearby")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(locationManager.activeNearbyStores.prefix(3)) { presence in
                        WidgetRow(
                            title: presence.isInsideGeofence ? "At \(presence.storeName)" : "Near \(presence.storeName)",
                            subtitle: presence.subtitle,
                            trailing: presence.distanceLabel,
                            icon: "location.fill",
                            tint: presence.isInsideGeofence ? ShelfTheme.success : ShelfTheme.accent
                        )
                    }

                    if locationManager.activeNearbyStores.isEmpty {
                        ForEach(locationManager.nearbyAlerts.prefix(3)) { alert in
                            WidgetRow(
                                title: alert.title,
                                subtitle: alert.message,
                                trailing: alert.distanceLabel,
                                icon: "location.fill"
                            )
                        }
                    }
                }
            }
        }
    }
}

struct ItemsRunningLowWidget: View {
    let items: [InventoryItem]

    var body: some View {
        DashboardWidgetShell(title: "Running Low", icon: "exclamationmark.triangle.fill") {
            if items.isEmpty {
                emptyState("All stocked up!")
            } else {
                VStack(spacing: 10) {
                    ForEach(items.prefix(4), id: \.id) { item in
                        WidgetRow(
                            title: item.name,
                            subtitle: runOutSubtitle(for: item),
                            trailing: quantityLabel(item),
                            icon: "exclamationmark.triangle.fill",
                            tint: ShelfTheme.warning
                        )
                    }
                }
            }
        }
    }

    private func runOutSubtitle(for item: InventoryItem) -> String {
        if let days = item.daysUntilRunOut {
            return "Est. \(days) days left"
        }
        return "Below minimum"
    }

    private func quantityLabel(_ item: InventoryItem) -> String {
        "\(item.quantity.formatted(.number.precision(.fractionLength(0...1)))) \(item.quantityUnit)"
    }
}

struct ItemsExpiringSoonWidget: View {
    let items: [InventoryItem]

    var body: some View {
        DashboardWidgetShell(title: "Expiring Soon", icon: "clock.badge.exclamationmark.fill") {
            if items.isEmpty {
                emptyState("Nothing expiring soon")
            } else {
                VStack(spacing: 10) {
                    ForEach(items.prefix(4), id: \.id) { item in
                        WidgetRow(
                            title: item.name,
                            subtitle: expirySubtitle(for: item),
                            trailing: expiryDays(for: item),
                            icon: "clock.badge.exclamationmark.fill",
                            tint: item.isExpired ? ShelfTheme.danger : ShelfTheme.warning
                        )
                    }
                }
            }
        }
    }

    private func expirySubtitle(for item: InventoryItem) -> String {
        item.brand.isEmpty ? item.category.displayName : item.brand
    }

    private func expiryDays(for item: InventoryItem) -> String? {
        guard let date = item.expirationDate else { return nil }
        let days = Formatters.daysUntil(date)
        if days < 0 { return "Expired" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "\(days)d"
    }
}

struct ShoppingListWidget: View {
    let items: [ShoppingListItem]

    var body: some View {
        DashboardWidgetShell(title: "Shopping List", icon: "checklist", actionTitle: "View all") {
            if items.isEmpty {
                emptyState("List is clear")
            } else {
                VStack(spacing: 10) {
                    ForEach(items.prefix(5), id: \.id) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "circle")
                                .foregroundStyle(ShelfTheme.textTertiary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.shelfSubheadline)
                                    .foregroundStyle(ShelfTheme.textPrimary)

                                if let reason = item.reason {
                                    Text(reason)
                                        .font(.shelfCaption)
                                        .foregroundStyle(ShelfTheme.textSecondary)
                                }
                            }

                            Spacer()

                            Text("\(item.quantity.formatted(.number.precision(.fractionLength(0...1))))")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textTertiary)
                        }
                    }
                }
            }
        }
    }
}

struct MonthlySavingsWidget: View {
    let receipts: [Receipt]
    let deals: [Deal]

    private var totalSavings: Double {
        receipts.reduce(0) { $0 + $1.discounts } + deals.reduce(0) { $0 + $1.savings }
    }

    var body: some View {
        StatCard(
            title: "Monthly Savings",
            value: Formatters.currencyString(totalSavings),
            subtitle: "From deals & coupons",
            icon: "dollarsign.circle.fill",
            tint: ShelfTheme.success
        )
    }
}

struct MoneySpentWidget: View {
    let receipts: [Receipt]

    private var monthlyTotal: Double {
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        return receipts.filter { $0.purchaseDate >= startOfMonth }.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        StatCard(
            title: "Spent This Month",
            value: Formatters.currencyString(monthlyTotal),
            subtitle: "\(receipts.count) receipts tracked",
            icon: "creditcard.fill",
            tint: ShelfTheme.accent
        )
    }
}

struct InventoryValueWidget: View {
    let items: [InventoryItem]

    private var totalValue: Double {
        items.compactMap { item -> Double? in
            guard let price = item.purchasePrice else { return nil }
            return price * item.quantity
        }.reduce(0, +)
    }

    var body: some View {
        StatCard(
            title: "Inventory Value",
            value: Formatters.currencyString(totalValue),
            subtitle: "\(items.count) items tracked",
            icon: "archivebox.fill",
            tint: ShelfTheme.accentSecondary
        )
    }
}

struct RecentReceiptsWidget: View {
    let receipts: [Receipt]

    var body: some View {
        DashboardWidgetShell(title: "Recent Receipts", icon: "doc.text.fill") {
            if receipts.isEmpty {
                emptyState("Scan a receipt to start")
            } else {
                VStack(spacing: 10) {
                    ForEach(receipts.prefix(3), id: \.id) { receipt in
                        WidgetRow(
                            title: receipt.storeName,
                            subtitle: "\(receipt.itemCount) items · \(Formatters.relativeString(from: receipt.purchaseDate))",
                            trailing: Formatters.currencyString(receipt.total),
                            icon: "doc.text.fill"
                        )
                    }
                }
            }
        }
    }
}

struct FavoriteStoresWidget: View {
    let stores: [Store]

    var body: some View {
        DashboardWidgetShell(title: "Favorite Stores", icon: "heart.fill") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(stores, id: \.id) { store in
                        VStack(spacing: 6) {
                            Image(systemName: "storefront.fill")
                                .font(.title3)
                                .foregroundStyle(ShelfTheme.accent)
                                .frame(width: 48, height: 48)
                                .background(ShelfTheme.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text(store.name)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(width: 72)
                    }
                }
            }
        }
    }
}

struct RecommendedPurchasesWidget: View {
    let deals: [Deal]

    var body: some View {
        DashboardWidgetShell(title: "Recommended", icon: "sparkles") {
            VStack(spacing: 10) {
                ForEach(deals.prefix(3), id: \.id) { deal in
                    WidgetRow(
                        title: deal.productName,
                        subtitle: "Save \(Formatters.currencyString(deal.savings)) at \(deal.storeName)",
                        trailing: nil,
                        icon: "sparkles",
                        tint: ShelfTheme.accentSecondary
                    )
                }
            }
        }
    }
}

struct PriceDropsWidget: View {
    let deals: [Deal]

    var body: some View {
        DashboardWidgetShell(title: "Price Drops", icon: "arrow.down.circle.fill") {
            VStack(spacing: 10) {
                ForEach(deals, id: \.id) { deal in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(deal.productName)
                                .font(.shelfSubheadline)
                            Text(deal.storeName)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Formatters.currencyString(deal.salePrice))
                                .font(.shelfSubheadline)
                                .foregroundStyle(ShelfTheme.success)
                            Text(Formatters.currencyString(deal.originalPrice))
                                .font(.shelfCaption)
                                .strikethrough()
                                .foregroundStyle(ShelfTheme.textTertiary)
                        }
                    }
                }
            }
        }
    }
}

struct AIRecommendationsWidget: View {
    let recommendations: [AIRecommendation]

    var body: some View {
        DashboardWidgetShell(title: "AI Recommendations", icon: "brain.head.profile.fill") {
            if recommendations.isEmpty {
                emptyState("Add stores and inventory to get personalized deal picks")
            } else {
                VStack(spacing: 12) {
                    ForEach(recommendations.prefix(2)) { rec in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(rec.title)
                                    .font(.shelfSubheadline)
                                    .foregroundStyle(ShelfTheme.textPrimary)
                                Spacer()
                                if let savings = rec.savingsEstimate {
                                    Text("Save \(Formatters.currencyString(savings))")
                                        .font(.shelfCaption)
                                        .foregroundStyle(ShelfTheme.success)
                                }
                            }

                            Text(rec.message)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(rec.confidenceLabel)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(ShelfTheme.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ShelfTheme.backgroundTertiary)
                                .clipShape(Capsule())
                        }
                        .padding(12)
                        .background(ShelfTheme.backgroundSecondary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
}

struct NotificationsWidget: View {
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        DashboardWidgetShell(title: "Notifications", icon: "bell.fill") {
            if locationManager.nearbyAlerts.isEmpty {
                emptyState("Location alerts appear when you're near saved stores")
            } else {
                VStack(spacing: 10) {
                    ForEach(locationManager.nearbyAlerts.prefix(4)) { alert in
                        WidgetRow(
                            title: alert.title,
                            subtitle: alert.message,
                            trailing: Formatters.relativeString(from: alert.timestamp),
                            icon: "location.fill"
                        )
                    }
                }
            }
        }
    }
}

struct FamilyActivityWidget: View {
    @Query(sort: \ShoppingListItem.createdAt, order: .reverse) private var listItems: [ShoppingListItem]
    @Query(sort: \MealPlanEntry.createdAt, order: .reverse) private var mealPlans: [MealPlanEntry]
    @Query private var members: [HouseholdMember]

    private var activity: [FamilyActivityItem] {
        CloudKitHouseholdService.shared.recentActivity(
            from: listItems,
            mealPlans: mealPlans,
            members: members
        )
    }

    var body: some View {
        DashboardWidgetShell(title: "Family Activity", icon: "person.2.fill") {
            if activity.isEmpty {
                emptyState("Invite family in More → Family Sharing")
            } else {
                VStack(spacing: 10) {
                    ForEach(activity) { item in
                        WidgetRow(
                            title: "\(item.memberName) \(item.action) \(item.itemName)",
                            subtitle: Formatters.relativeString(from: item.timestamp),
                            trailing: nil,
                            icon: "person.fill",
                            tint: ShelfTheme.copper
                        )
                    }
                }
            }
        }
    }
}

struct ShoppingStreakWidget: View {
    let receipts: [Receipt]

    private var streakDays: Int {
        guard !receipts.isEmpty else { return 0 }
        let uniqueDays = Set(receipts.map {
            Calendar.current.startOfDay(for: $0.purchaseDate)
        })
        return uniqueDays.count
    }

    var body: some View {
        GlassCard {
            if streakDays == 0 {
                HStack(spacing: 12) {
                    Image(systemName: "flame")
                        .foregroundStyle(ShelfTheme.textTertiary)
                    Text("Scan receipts to track shopping activity")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                }
            } else {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [ShelfTheme.accentSecondary, ShelfTheme.warning],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)

                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(streakDays) Shopping Days")
                            .font(.shelfHeadline)
                            .foregroundStyle(ShelfTheme.textPrimary)

                        Text("Based on your scanned receipts")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }

                    Spacer()
                }
            }
        }
    }
}

struct BudgetProgressWidget: View {
    let budgets: [Budget]

    var body: some View {
        DashboardWidgetShell(title: "Budget Progress", icon: "chart.pie.fill") {
            VStack(spacing: 14) {
                ForEach(budgets.prefix(3), id: \.id) { budget in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(budget.name)
                                .font(.shelfSubheadline)
                            Spacer()
                            Text("\(Formatters.currencyString(budget.currentSpent)) / \(Formatters.currencyString(budget.monthlyLimit))")
                                .font(.shelfCaption)
                                .foregroundStyle(budget.isNearLimit ? ShelfTheme.warning : ShelfTheme.textSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(ShelfTheme.backgroundTertiary)
                                    .frame(height: 6)

                                Capsule()
                                    .fill(budget.isNearLimit ? ShelfTheme.warning : ShelfTheme.accent)
                                    .frame(width: geo.size.width * budget.progress, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }
}

struct DailyQuestsWidget: View {
    @State private var questStore = QuestStore.shared

    var body: some View {
        DashboardWidgetShell(title: "Daily Quests", icon: "flag.checkered") {
            let quests = questStore.allQuests.filter { !$0.definition.isWeekly }
            if quests.isEmpty {
                emptyState("No quests today")
            } else {
                VStack(spacing: 10) {
                    ForEach(quests.prefix(3)) { quest in
                        HStack {
                            Image(systemName: quest.definition.icon)
                                .foregroundStyle(quest.isComplete ? ShelfTheme.success : ShelfTheme.copper)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(quest.definition.title).font(.shelfSubheadline).lineLimit(1)
                                ProgressView(value: quest.progress).tint(ShelfTheme.copper)
                            }
                            Text("+\(quest.definition.xpReward)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ShelfTheme.copperGlow)
                        }
                    }
                    Text("\(questStore.streakDays)-day streak")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textTertiary)
                }
            }
        }
        .onAppear { questStore.refreshIfNeeded() }
    }
}

struct CouponMatchesWidget: View {
    @Query private var coupons: [Coupon]
    @Query private var listItems: [ShoppingListItem]

    private var matches: [CouponMatch] {
        CouponMatchService.matches(coupons: coupons.filter(\.isActive), listItems: listItems)
    }

    var body: some View {
        DashboardWidgetShell(title: "Coupon Matches", icon: "ticket.fill") {
            if matches.isEmpty {
                emptyState("No coupon matches")
            } else {
                VStack(spacing: 10) {
                    ForEach(matches.prefix(3)) { match in
                        WidgetRow(
                            title: match.matchedItemName,
                            subtitle: match.couponTitle,
                            trailing: Formatters.currencyString(match.estimatedSavings),
                            icon: "ticket.fill",
                            tint: ShelfTheme.success
                        )
                    }
                }
            }
        }
    }
}

struct RestockPredictionsWidget: View {
    @Query private var inventory: [InventoryItem]
    @Query private var receipts: [Receipt]
    @Query private var lineItems: [ReceiptLineItem]

    private var predictions: [RestockPrediction] {
        RestockPredictionService.predictions(from: inventory, receipts: receipts, lineItems: lineItems)
    }

    var body: some View {
        DashboardWidgetShell(title: "Restock Soon", icon: "clock.arrow.circlepath") {
            if predictions.isEmpty {
                emptyState("All stocked up")
            } else {
                VStack(spacing: 10) {
                    ForEach(predictions.prefix(3)) { prediction in
                        WidgetRow(
                            title: prediction.itemName,
                            subtitle: "By \(prediction.suggestedDate.formatted(date: .abbreviated, time: .omitted))",
                            trailing: nil,
                            icon: "cart.badge.plus"
                        )
                    }
                }
            }
        }
    }
}

@ViewBuilder
private func emptyState(_ message: String) -> some View {
    Text(message)
        .font(.shelfCaption)
        .foregroundStyle(ShelfTheme.textTertiary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
}
