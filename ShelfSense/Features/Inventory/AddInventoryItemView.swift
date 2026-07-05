//
//  AddInventoryItemView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct AddInventoryItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var category: InventoryCategory = .groceries
    @State private var quantity: Double = 1
    @State private var quantityUnit = "units"
    @State private var minimumQuantity: Double = 1
    @State private var storeName = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Name", text: $name)
                    TextField("Brand", text: $brand)

                    Picker("Category", selection: $category) {
                        ForEach(InventoryCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Quantity") {
                    Stepper(value: $quantity, in: 0...999, step: 0.5) {
                        Text("\(quantity.formatted()) \(quantityUnit)")
                    }

                    TextField("Unit (e.g. gallon, count)", text: $quantityUnit)

                    Stepper(value: $minimumQuantity, in: 0...100, step: 0.5) {
                        Text("Minimum: \(minimumQuantity.formatted())")
                    }
                }

                Section("Optional") {
                    TextField("Store", text: $storeName)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveItem() {
        let item = InventoryItem(
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces),
            category: category,
            quantity: quantity,
            quantityUnit: quantityUnit.isEmpty ? "units" : quantityUnit,
            storeName: storeName.isEmpty ? nil : storeName,
            minimumQuantity: minimumQuantity,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(item)
        HapticManager.success()
        dismiss()
    }
}
