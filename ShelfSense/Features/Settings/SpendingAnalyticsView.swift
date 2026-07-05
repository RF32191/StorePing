//
//  SpendingAnalyticsView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData
import Charts

struct SpendingAnalyticsView: View {
    @Query(sort: \Receipt.purchaseDate, order: .reverse) private var receipts: [Receipt]
    @Query private var budgets: [Budget]
    @Query private var inventoryItems: [InventoryItem]

    private var monthlySpending: Double {
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        return receipts.filter { $0.purchaseDate >= startOfMonth }.reduce(0) { $0 + $1.total }
    }

    private var totalSavings: Double {
        receipts.reduce(0) { $0 + $1.discounts }
    }

    private var storeBreakdown: [(store: String, amount: Double)] {
        Dictionary(grouping: receipts, by: \.storeName)
            .map { (store: $0.key, amount: $0.value.reduce(0) { $0 + $1.total }) }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    StatCard(
                        title: "This Month",
                        value: Formatters.currencyString(monthlySpending),
                        icon: "creditcard.fill"
                    )
                    StatCard(
                        title: "Saved",
                        value: Formatters.currencyString(totalSavings),
                        icon: "dollarsign.circle.fill",
                        tint: ShelfTheme.success
                    )
                }

                if !storeBreakdown.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Store")
                                .font(.shelfHeadline)

                            Chart(storeBreakdown, id: \.store) { item in
                                BarMark(
                                    x: .value("Amount", item.amount),
                                    y: .value("Store", item.store)
                                )
                                .foregroundStyle(ShelfTheme.accent.gradient)
                                .cornerRadius(4)
                            }
                            .frame(height: CGFloat(storeBreakdown.count) * 40)
                            .chartXAxis {
                                AxisMarks(format: .currency(code: "USD").precision(.fractionLength(0)))
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Budget Progress")
                            .font(.shelfHeadline)

                        ForEach(budgets, id: \.id) { budget in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(budget.name)
                                        .font(.shelfSubheadline)
                                    Spacer()
                                    Text(Formatters.currencyString(budget.currentSpent))
                                        .font(.shelfCaption)
                                        .foregroundStyle(ShelfTheme.textSecondary)
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(ShelfTheme.backgroundTertiary).frame(height: 8)
                                        Capsule()
                                            .fill(budget.isNearLimit ? ShelfTheme.warning : ShelfTheme.accent)
                                            .frame(width: geo.size.width * budget.progress, height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                }

                if totalSavings > 0 || !receipts.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Insights")
                                .font(.shelfHeadline)

                            if totalSavings > 0 {
                                insightRow("You saved \(Formatters.currencyString(totalSavings)) from discounts this month", icon: "sparkles")
                            }

                            insightRow("Track receipts and add stores to unlock deal recommendations", icon: "storefront.fill")
                        }
                    }
                }
            }
            .padding()
        }
        .background(ShelfGradientBackground())
        .navigationTitle("Spending Analytics")
    }

    private func insightRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(ShelfTheme.accentSecondary)
                .frame(width: 24)
            Text(text)
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.textSecondary)
        }
    }
}
