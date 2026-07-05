//
//  FinanceHubViews.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct PriceHistoryView: View {
    @Query(sort: \PriceHistoryEntry.recordedAt, order: .reverse) private var entries: [PriceHistoryEntry]
    @State private var search = ""

    private var grouped: [(name: String, count: Int, latest: Double, lowest: Double)] {
        let filtered = search.isEmpty ? entries : entries.filter {
            $0.productName.localizedCaseInsensitiveContains(search)
        }
        return PriceHistoryService.groupedProducts(filtered)
    }

    var body: some View {
        List {
            if grouped.isEmpty {
                ContentUnavailableView("No price history", systemImage: "chart.line.uptrend.xyaxis",
                                       description: Text("Prices are recorded when deals refresh"))
            } else {
                ForEach(grouped, id: \.name) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.shelfSubheadline)
                        HStack {
                            Text("Latest \(Formatters.currencyString(item.latest))")
                            Text("·")
                            Text("Low \(Formatters.currencyString(item.lowest))")
                                .foregroundStyle(ShelfTheme.success)
                            Spacer()
                            Text("\(item.count) records")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textTertiary)
                        }
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search products")
        .navigationTitle("Price History")
    }
}

struct TripOptimizerView: View {
    @Query private var listItems: [ShoppingListItem]
    @Query private var deals: [Deal]
    @Query private var stores: [Store]

    private var plans: [StoreTripPlan] {
        TripOptimizerService.optimize(listItems: listItems, deals: deals, stores: stores)
    }

    private var split: (plans: [StoreTripPlan], uncovered: Int) {
        TripOptimizerService.bestSplit(plans: plans, totalItems: listItems.filter { !$0.isCompleted }.count)
    }

    var body: some View {
        List {
            Section {
                Text("Find the best store(s) for your shopping list based on deals and estimated prices.")
                    .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
            }

            if plans.isEmpty {
                ContentUnavailableView("Nothing to optimize", systemImage: "map", description: Text("Add list items and saved stores"))
            } else {
                if split.uncovered > 0 {
                    Section {
                        Label("\(split.uncovered) item(s) not covered — may need another store", systemImage: "exclamationmark.triangle")
                            .font(.shelfCaption).foregroundStyle(ShelfTheme.warning)
                    }
                }

                if plans.count > 1 {
                    Section("Trip + Gas Estimate") {
                        let extraStores = plans.count - 1
                        let miles = Double(extraStores) * 5
                        let gasCost = VehicleSettingsStore.tripFuelCost(miles: miles, pricePerGallon: GasPriceService.regionalAverage)
                        LabeledContent("Extra stops", value: "\(extraStores)")
                        LabeledContent("Est. miles", value: "~\(Int(miles))")
                        LabeledContent("Est. gas", value: Formatters.currencyString(gasCost))
                        LabeledContent("Vehicle MPG", value: String(format: "%.0f", VehicleSettingsStore.mpg))
                    }
                }

                ForEach(plans) { plan in
                    Section(plan.storeName) {
                        LabeledContent("Items matched", value: "\(plan.itemCount)")
                        LabeledContent("Est. total", value: Formatters.currencyString(plan.estimatedTotal))
                        if plan.dealSavings > 0 {
                            LabeledContent("Deal savings", value: Formatters.currencyString(plan.dealSavings))
                        }
                        ForEach(plan.items, id: \.id) { item in
                            Text(item.name).font(.shelfCaption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Trip Optimizer")
    }
}

struct CouponWalletView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Coupon.createdAt, order: .reverse) private var coupons: [Coupon]
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                Button { showAdd = true } label: {
                    Label("Add coupon", systemImage: "plus.circle.fill")
                }
            }

            if coupons.isEmpty {
                ContentUnavailableView("No coupons", systemImage: "ticket", description: Text("Save digital coupons and loyalty offers"))
            } else {
                ForEach(coupons.filter(\.isActive), id: \.id) { coupon in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(coupon.title).font(.shelfSubheadline)
                        Text(coupon.storeName).font(.shelfCaption).foregroundStyle(ShelfTheme.copperLight)
                        Text(coupon.discountDescription).font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                        if let exp = coupon.expiresAt {
                            Text("Expires \(exp.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 10)).foregroundStyle(ShelfTheme.textTertiary)
                        }
                    }
                    .swipeActions {
                        Button("Used") { coupon.isUsed = true }
                        Button("Delete", role: .destructive) { modelContext.delete(coupon) }
                    }
                }
            }
        }
        .navigationTitle("Coupon Wallet")
        .sheet(isPresented: $showAdd) { AddCouponSheet() }
    }
}

struct AddCouponSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var store = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Store", text: $store)
                TextField("Discount details", text: $description)
            }
            .navigationTitle("Add Coupon")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        modelContext.insert(Coupon(title: title, storeName: store, discountDescription: description))
                        dismiss()
                    }
                    .disabled(title.isEmpty || store.isEmpty)
                }
            }
        }
    }
}

struct BudgetCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(budgets, id: \.id) { budget in
                VStack(alignment: .leading, spacing: 6) {
                    Text(budget.name).font(.shelfSubheadline)
                    ProgressView(value: budget.progress)
                        .tint(budget.isNearLimit ? ShelfTheme.warning : ShelfTheme.copper)
                    Text("\(Formatters.currencyString(budget.currentSpent)) of \(Formatters.currencyString(budget.monthlyLimit))")
                        .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                }
            }
            .onDelete { offsets in offsets.forEach { modelContext.delete(budgets[$0]) } }

            Button { showAdd = true } label: {
                Label("Add category budget", systemImage: "plus")
            }
        }
        .navigationTitle("Budget Categories")
        .sheet(isPresented: $showAdd) {
            AddBudgetSheet()
        }
    }
}

struct AddBudgetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Groceries"
    @State private var limit = "500"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Category name", text: $name)
                TextField("Monthly limit", text: $limit).keyboardType(.decimalPad)
            }
            .navigationTitle("New Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let value = Double(limit) {
                            modelContext.insert(Budget(name: name, monthlyLimit: value))
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SavingsStreakView: View {
    @Query private var budgets: [Budget]
    @Query private var deals: [Deal]

    private var streak: Int { UserPreferencesStore.savingsStreakWeeks }
    private var savings: Double { deals.filter(\.isActive).reduce(0) { $0 + $1.savings } }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(ShelfTheme.heroGradient)
                    Text("\(streak) week streak")
                        .font(.shelfTitle)
                    Text("Keep shopping smart to extend your streak!")
                        .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Section("Stats") {
                LabeledContent("Active deal savings", value: Formatters.currencyString(savings))
                LabeledContent("Budgets tracked", value: "\(budgets.count)")
            }

            Section {
                Button("Log week under budget") {
                    UserPreferencesStore.savingsStreakWeeks += 1
                    HapticManager.success()
                }
            }
        }
        .navigationTitle("Savings Streak")
    }
}
