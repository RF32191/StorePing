//
//  BarcodeScanResultView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct BarcodeScanResultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let barcode: String

    @State private var product: ProductBrandOption?
    @State private var isLoading = true
    @State private var destination: ScanDestination = .inventory

    enum ScanDestination: String, CaseIterable {
        case inventory, list

        var title: String {
            switch self {
            case .inventory: "Inventory"
            case .list: "Shopping List"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ShelfLoadingView(message: "Looking up barcode…", detail: barcode, style: .inline)
                } else if let product {
                    ScrollView {
                        VStack(spacing: 16) {
                            BrandOptionCard(option: product, isSelected: true) {}

                            if let score = product.nutriScore {
                                Label("Nutri-Score: \(score)", systemImage: "leaf.fill")
                                    .font(.shelfCaption).foregroundStyle(ShelfTheme.success)
                            }

                            if !product.allergens.isEmpty {
                                VStack(alignment: .leading) {
                                    Text("Allergens").font(.shelfCaption).foregroundStyle(ShelfTheme.warning)
                                    Text(product.allergens.joined(separator: ", "))
                                        .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                                }
                            }

                            if UserPreferencesStore.containsAllergen(product.allergens) {
                                Label("Contains your allergens!", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(ShelfTheme.warning)
                            }

                            Picker("Add to", selection: $destination) {
                                ForEach(ScanDestination.allCases, id: \.self) { dest in
                                    Text(dest.title).tag(dest)
                                }
                            }
                            .pickerStyle(.segmented)

                            Button {
                                saveProduct(product)
                            } label: {
                                Label("Add to \(destination.title)", systemImage: "plus.circle.fill")
                                    .font(.shelfHeadline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ShelfTheme.copperGradient.opacity(0.3))
                                    .foregroundStyle(ShelfTheme.copperLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView("Product not found", systemImage: "barcode.viewfinder",
                                           description: Text("Try adding manually"))
                }
            }
            .background(ShelfGradientBackground())
            .navigationTitle("Scan Result")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task { await lookup() }
        }
    }

    private func lookup() async {
        product = await ProductNutritionService.lookupBarcode(barcode)
        isLoading = false
    }

    private func saveProduct(_ product: ProductBrandOption) {
        switch destination {
        case .inventory:
            let item = InventoryItem(
                name: product.productName,
                brand: product.brand ?? "",
                barcode: product.barcode
            )
            modelContext.insert(item)
        case .list:
            let item = ShoppingListItem(
                name: product.productName,
                brand: product.brand,
                barcode: product.barcode,
                caloriesPer100g: product.calories,
                carbsPer100g: product.carbs,
                proteinPer100g: product.protein,
                fatPer100g: product.fat,
                fiberPer100g: product.fiber,
                sodiumPer100g: product.sodium,
                servingSize: product.servingSize
            )
            modelContext.insert(item)
        }
        HapticManager.success()
        dismiss()
    }
}
