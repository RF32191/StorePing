//
//  AddDealView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct AddDealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(DealEngine.self) private var dealEngine

    let store: Store

    @State private var productName = ""
    @State private var brand = ""
    @State private var originalPrice = ""
    @State private var salePrice = ""
    @State private var notes = ""
    @State private var hasExpiration = true
    @State private var expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Product name", text: $productName)
                    TextField("Brand (optional)", text: $brand)
                }

                Section("Pricing") {
                    TextField("Original price", text: $originalPrice)
                        .keyboardType(.decimalPad)
                    TextField("Sale price", text: $salePrice)
                        .keyboardType(.decimalPad)
                }

                Section("Details") {
                    Toggle("Expires", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Expiration", selection: $expiresAt, displayedComponents: .date)
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Deal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveDeal() }
                        .disabled(productName.isEmpty || salePrice.isEmpty)
                }
            }
        }
    }

    private func saveDeal() {
        guard let sale = Double(salePrice) else { return }
        let original = Double(originalPrice) ?? sale

        dealEngine.addManualDeal(
            productName: productName.trimmingCharacters(in: .whitespaces),
            brand: brand.isEmpty ? nil : brand,
            store: store,
            originalPrice: original,
            salePrice: sale,
            expiresAt: hasExpiration ? expiresAt : nil,
            notes: notes.isEmpty ? nil : notes,
            context: modelContext
        )
        HapticManager.success()
        dismiss()
    }
}
