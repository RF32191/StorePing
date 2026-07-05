//
//  InventoryDetailView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct InventoryDetailView: View {
    @Bindable var item: InventoryItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                quantitySection
                detailsSection

                if let notes = item.notes, !notes.isEmpty {
                    detailCard(title: "Notes", value: notes)
                }

                if let days = item.daysUntilRunOut {
                    predictionCard(days: days)
                }
            }
            .padding()
        }
        .background(ShelfGradientBackground())
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    item.isFavorite.toggle()
                    HapticManager.selection()
                } label: {
                    Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(item.isFavorite ? ShelfTheme.danger : ShelfTheme.textSecondary)
                }
            }
        }
    }

    private var headerSection: some View {
        GlassCard {
            HStack(spacing: 16) {
                Image(systemName: item.category.icon)
                    .font(.largeTitle)
                    .foregroundStyle(ShelfTheme.accent)
                    .frame(width: 64, height: 64)
                    .background(ShelfTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.shelfTitle)
                        .foregroundStyle(ShelfTheme.textPrimary)

                    if !item.brand.isEmpty {
                        Text(item.brand)
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }

                    Text(item.category.displayName)
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textTertiary)
                }
            }
        }
    }

    private var quantitySection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Quantity",
                value: item.quantity.formatted(.number.precision(.fractionLength(0...2))),
                subtitle: item.quantityUnit,
                icon: "number.circle.fill"
            )

            if let price = item.purchasePrice {
                StatCard(
                    title: "Price",
                    value: Formatters.currencyString(price),
                    subtitle: "Last paid",
                    icon: "dollarsign.circle.fill",
                    tint: ShelfTheme.accentSecondary
                )
            }
        }
    }

    private var detailsSection: some View {
        VStack(spacing: 10) {
            if let store = item.storeName {
                detailCard(title: "Store", value: store, icon: "storefront.fill")
            }

            if let location = item.storageLocation {
                detailCard(title: "Location", value: location, icon: "mappin.circle.fill")
            }

            if let purchaseDate = item.purchaseDate {
                detailCard(title: "Purchased", value: purchaseDate.formatted(date: .abbreviated, time: .omitted), icon: "calendar")
            }

            if let expirationDate = item.expirationDate {
                detailCard(
                    title: "Expires",
                    value: expirationDate.formatted(date: .abbreviated, time: .omitted),
                    icon: "clock.badge.exclamationmark.fill"
                )
            }

            detailCard(title: "Minimum Qty", value: "\(item.minimumQuantity.formatted()) \(item.quantityUnit)", icon: "exclamationmark.triangle.fill")
        }
    }

    private func detailCard(title: String, value: String, icon: String? = nil) -> some View {
        GlassCard(padding: 12) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(ShelfTheme.accent)
                        .frame(width: 24)
                }

                Text(title)
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)

                Spacer()

                Text(value)
                    .font(.shelfSubheadline)
                    .foregroundStyle(ShelfTheme.textPrimary)
            }
        }
    }

    private func predictionCard(days: Int) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.title2)
                    .foregroundStyle(ShelfTheme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Prediction")
                        .font(.shelfSubheadline)
                        .foregroundStyle(ShelfTheme.textPrimary)

                    Text("You'll likely run out in \(days) day\(days == 1 ? "" : "s")")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                }
            }
        }
    }
}
