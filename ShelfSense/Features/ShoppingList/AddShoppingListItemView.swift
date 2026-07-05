//
//  AddShoppingListItemView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct AddShoppingListItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var itemName = ""
    @State private var brandOptions: [ProductBrandOption] = []
    @State private var selectedOption: ProductBrandOption?
    @State private var isSearching = false
    @State private var quantity: Double = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you need?")
                            .font(.shelfHeadline)
                            .foregroundStyle(ShelfTheme.textPrimary)

                        TextField("e.g. milk, bread, detergent", text: $itemName)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.search)
                            .onSubmit { Task { await searchBrands() } }

                        Button {
                            Task { await searchBrands() }
                        } label: {
                            Label(isSearching ? "Searching…" : "Find brands & nutrition", systemImage: "magnifyingglass")
                                .font(.shelfSubheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(ShelfTheme.copper.opacity(0.15))
                                .foregroundStyle(ShelfTheme.copperLight)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(itemName.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                    }

                    if isSearching {
                        ShelfLoadingView(message: "Finding brands…", detail: "Pulling nutrition and prices", style: .inline)
                    }

                    if !brandOptions.isEmpty {
                        Text("Choose a brand")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)

                        ForEach(brandOptions) { option in
                            BrandOptionCard(
                                option: option,
                                isSelected: selectedOption?.id == option.id
                            ) {
                                selectedOption = option
                                HapticManager.selection()
                            }
                        }
                    }

                    if selectedOption != nil {
                        Stepper(value: $quantity, in: 1...99, step: 1) {
                            Text("Quantity: \(Int(quantity))")
                                .font(.shelfSubheadline)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .background(ShelfGradientBackground())
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveItem() }
                        .disabled(itemName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func searchBrands() async {
        let query = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        selectedOption = nil
        brandOptions = await ProductNutritionService.brandOptions(for: query)
        isSearching = false

        if brandOptions.count == 1 {
            selectedOption = brandOptions.first
        }
    }

    private func saveItem() {
        let trimmed = itemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let option = selectedOption
        let item = ShoppingListItem(
            name: option?.productName ?? trimmed,
            brand: option?.brand,
            quantity: quantity,
            estimatedPrice: option?.estimatedPrice,
            barcode: option?.barcode,
            caloriesPer100g: option?.calories,
            carbsPer100g: option?.carbs,
            proteinPer100g: option?.protein,
            fatPer100g: option?.fat,
            fiberPer100g: option?.fiber,
            sodiumPer100g: option?.sodium,
            servingSize: option?.servingSize
        )
        modelContext.insert(item)
        HapticManager.success()
        dismiss()
    }
}

struct BrandOptionCard: View {
    let option: ProductBrandOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            GlassCard(padding: 12) {
                HStack(alignment: .top, spacing: 12) {
                    if let url = option.imageURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "leaf.fill")
                                    .foregroundStyle(ShelfTheme.copper)
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(option.productName)
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.textPrimary)
                            .multilineTextAlignment(.leading)

                        if let brand = option.brand {
                            Text(brand)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.copperLight)
                        }

                        if let nutrition = nutritionSummary {
                            Text(nutrition)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(ShelfTheme.textSecondary)
                        }

                        if let score = option.nutriScore {
                            Text("Nutri-Score \(score)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(ShelfTheme.success)
                        }

                        if UserPreferencesStore.containsAllergen(option.allergens) {
                            Label("Allergen warning", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(ShelfTheme.warning)
                        }

                        if let price = option.estimatedPrice {
                            Text(Formatters.currencyString(price))
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.success)
                        }

                        Text(option.sourceLabel)
                            .font(.system(size: 9))
                            .foregroundStyle(ShelfTheme.textTertiary)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? ShelfTheme.copperLight : ShelfTheme.textTertiary)
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: ShelfTheme.cornerRadiusMedium, style: .continuous)
                        .strokeBorder(ShelfTheme.copper, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(ShelfPressButtonStyle())
    }

    private var nutritionSummary: String? {
        var parts: [String] = []
        if let cal = option.calories { parts.append("\(Int(cal)) cal") }
        if let carbs = option.carbs { parts.append("\(Formatters.decimalString(carbs))g carbs") }
        if let protein = option.protein { parts.append("\(Formatters.decimalString(protein))g protein") }
        if let fat = option.fat { parts.append("\(Formatters.decimalString(fat))g fat") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
