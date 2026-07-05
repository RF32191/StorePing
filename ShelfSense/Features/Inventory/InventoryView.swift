//
//  InventoryView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @State private var searchText = ""
    @State private var selectedCategory: InventoryCategory?
    @State private var showAddItem = false
    @State private var sortOption: InventorySort = .name

    enum InventorySort: String, CaseIterable {
        case name = "Name"
        case category = "Category"
        case quantity = "Quantity"
        case expiration = "Expiration"
    }

    private var filteredItems: [InventoryItem] {
        var result = items

        if let selectedCategory {
            result = result.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.brand.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .name:
            result.sort { $0.name < $1.name }
        case .category:
            result.sort { $0.category.displayName < $1.category.displayName }
        case .quantity:
            result.sort { $0.quantity < $1.quantity }
        case .expiration:
            result.sort {
                ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCards

                    categoryFilter

                    if filteredItems.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredItems, id: \.id) { item in
                                NavigationLink {
                                    InventoryDetailView(item: item)
                                } label: {
                                    InventoryItemRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
                .shelfScrollBottomInset()
            }
            .shelfScrollContentInsets()
            .background(ShelfGradientBackground())
            .navigationTitle("Inventory")
            .searchable(text: $searchText, prompt: "Search pantry, fridge, supplies...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(InventorySort.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddItem = true
                        HapticManager.lightImpact()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(ShelfTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddInventoryItemView()
            }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            miniStat(value: "\(items.count)", label: "Items", icon: "archivebox.fill")
            miniStat(value: "\(items.filter { $0.isLowStock }.count)", label: "Low", icon: "exclamationmark.triangle.fill", tint: ShelfTheme.warning)
            miniStat(value: "\(items.filter { $0.isExpiringSoon }.count)", label: "Expiring", icon: "clock.fill", tint: ShelfTheme.danger)
        }
    }

    private func miniStat(value: String, label: String, icon: String, tint: Color = ShelfTheme.accent) -> some View {
        GlassCard(padding: 12) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.caption)
                Text(value)
                    .font(.shelfStatSmall)
                    .foregroundStyle(ShelfTheme.textPrimary)
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(ShelfTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", icon: "square.grid.2x2", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                    HapticManager.selection()
                }

                ForEach(InventoryCategory.allCases) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        HapticManager.selection()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundStyle(ShelfTheme.textTertiary)

            Text("No items found")
                .font(.shelfHeadline)
                .foregroundStyle(ShelfTheme.textSecondary)

            Text("Scan a barcode or add items manually")
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

struct InventoryItemRow: View {
    let item: InventoryItem

    var body: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ShelfTheme.accent.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: item.category.icon)
                        .foregroundStyle(ShelfTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.textPrimary)

                        if item.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(ShelfTheme.danger)
                        }
                    }

                    HStack(spacing: 8) {
                        if !item.brand.isEmpty {
                            Text(item.brand)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)
                        }

                        if item.isLowStock {
                            statusBadge("Low", color: ShelfTheme.warning)
                        }

                        if item.isExpiringSoon {
                            statusBadge("Expiring", color: ShelfTheme.danger)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(item.quantity.formatted(.number.precision(.fractionLength(0...1))))")
                        .font(.shelfSubheadline)
                        .foregroundStyle(ShelfTheme.textPrimary)

                    Text(item.quantityUnit)
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(ShelfTheme.textTertiary)
            }
        }
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    InventoryView()
        .modelContainer(PreviewModelContainer.shared)
}
