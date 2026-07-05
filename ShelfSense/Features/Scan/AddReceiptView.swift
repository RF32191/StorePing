//
//  AddReceiptView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddReceiptView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Store.name) private var stores: [Store]

    @State private var storeName = ""
    @State private var purchaseDate = Date()
    @State private var lineItems: [EditableLineItem] = [EditableLineItem()]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isProcessingOCR = false
    @State private var ocrStatus = ""
    @State private var isSaving = false
    @State private var showBusinessSearch = false
    @State private var parsedSubtotal: Double?
    @State private var parsedTax: Double?
    @State private var parsedTotal: Double?
    @State private var parsedDiscounts: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(isProcessingOCR ? "Reading receipt…" : "Choose Receipt Photo", systemImage: "doc.text.viewfinder")
                    }
                    .disabled(isProcessingOCR)

                    if isProcessingOCR {
                        HStack(spacing: 10) {
                            ProgressView().tint(ShelfTheme.copper)
                            Text("Enhancing image & extracting items…")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)
                        }
                    } else if !ocrStatus.isEmpty {
                        Label(ocrStatus, systemImage: "checkmark.seal.fill")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.copperLight)
                    }
                } header: {
                    Text("Scan Receipt")
                } footer: {
                    Text("Tip: lay receipt flat, good lighting, full receipt in frame. We enhance contrast before reading.")
                }

                Section("Store") {
                    TextField("Store name", text: $storeName)

                    Button { showBusinessSearch = true } label: {
                        Label("Find business", systemImage: "magnifyingglass")
                    }

                    if !stores.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(stores, id: \.id) { store in
                                    Button(store.name) {
                                        storeName = store.name
                                        HapticManager.lightImpact()
                                    }
                                    .font(.shelfCaption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(storeName == store.name ? ShelfTheme.accent.opacity(0.2) : ShelfTheme.backgroundSecondary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                }

                if parsedSubtotal != nil || parsedTotal != nil {
                    Section("Receipt Totals") {
                        if let subtotal = parsedSubtotal {
                            LabeledContent("Subtotal", value: Formatters.currencyString(subtotal))
                        }
                        if let tax = parsedTax {
                            LabeledContent("Tax", value: Formatters.currencyString(tax))
                        }
                        if let discounts = parsedDiscounts, discounts > 0 {
                            LabeledContent("Savings", value: Formatters.currencyString(discounts))
                        }
                        if let total = parsedTotal {
                            LabeledContent("Total", value: Formatters.currencyString(total))
                                .foregroundStyle(ShelfTheme.success)
                        }
                        LabeledContent("Line items", value: "\(validLineItems.count)")
                    }
                }

                Section {
                    ForEach($lineItems) { $item in
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Item name", text: $item.name)

                            HStack {
                                TextField("Qty", text: $item.quantity)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 60)
                                TextField("Price", text: $item.price)
                                    .keyboardType(.decimalPad)
                                TextField("Was", text: $item.originalPrice)
                                    .keyboardType(.decimalPad)
                            }

                            Toggle("On sale", isOn: $item.isOnSale)
                            Toggle("Has expiration", isOn: $item.hasExpiration)
                            if item.hasExpiration {
                                DatePicker("Expires", selection: $item.expirationDate, displayedComponents: .date)
                            }

                            if let summary = item.projectionSummary {
                                Text(summary)
                                    .font(.shelfCaption)
                                    .foregroundStyle(ShelfTheme.accentSecondary)
                            }
                        }
                    }
                    .onDelete { indexSet in lineItems.remove(atOffsets: indexSet) }

                    Button { lineItems.append(EditableLineItem()) } label: {
                        Label("Add Line Item", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Items (\(validLineItems.count))")
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveReceipt() }
                        .disabled(storeName.isEmpty || isSaving || validLineItems.isEmpty)
                }
            }
            .sheet(isPresented: $showBusinessSearch) {
                BusinessSearchView()
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task { await processPhoto(newItem) }
            }
        }
    }

    private var validLineItems: [ParsedReceiptLineItem] {
        lineItems.compactMap { $0.parsed }
    }

    private func processPhoto(_ item: PhotosPickerItem) async {
        isProcessingOCR = true
        ocrStatus = ""
        defer { isProcessingOCR = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            ocrStatus = "Could not load the selected image."
            return
        }

        previewImage = image

        do {
            let enhanced = ReceiptOCRService.preprocess(image)
            previewImage = enhanced
            let text = try await ReceiptOCRService.recognizeText(from: enhanced)
            let parsed = ReceiptParser.parse(text)

            if let detectedStore = parsed.storeName, storeName.isEmpty {
                storeName = detectedStore
            }
            if let detectedDate = parsed.purchaseDate {
                purchaseDate = detectedDate
            }

            parsedSubtotal = parsed.subtotal
            parsedTax = parsed.tax
            parsedTotal = parsed.total
            parsedDiscounts = parsed.discounts

            if parsed.lineItems.isEmpty {
                ocrStatus = "No line items detected — add them manually below."
            } else {
                lineItems = parsed.lineItems.map { EditableLineItem(from: $0) }
                let savings = parsed.discounts.map { " · saved \(Formatters.currencyString($0))" } ?? ""
                ocrStatus = "Found \(parsed.lineItems.count) items\(savings). Review before saving."
                HapticManager.success()
            }
        } catch {
            ocrStatus = error.localizedDescription
        }
    }

    private func saveReceipt() {
        isSaving = true
        Task {
            await ReceiptProcessingService.saveReceipt(
                storeName: storeName.trimmingCharacters(in: .whitespaces),
                purchaseDate: purchaseDate,
                lineItems: validLineItems,
                rawOCRText: nil,
                context: modelContext
            )
            await MainActor.run {
                HapticManager.success()
                isSaving = false
                dismiss()
            }
        }
    }
}

private struct EditableLineItem: Identifiable {
    let id = UUID()
    var name = ""
    var quantity = "1"
    var price = ""
    var originalPrice = ""
    var isOnSale = false
    var hasExpiration = false
    var expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    init() {}

    init(from parsed: ParsedReceiptLineItem) {
        name = parsed.productName
        quantity = String(format: "%.0f", parsed.quantity)
        price = String(format: "%.2f", parsed.unitPrice)
        if let original = parsed.originalPrice {
            originalPrice = String(format: "%.2f", original)
        }
        isOnSale = parsed.isOnSale
        if let expirationDate = parsed.expirationDate {
            hasExpiration = true
            self.expirationDate = expirationDate
        }
    }

    var parsed: ParsedReceiptLineItem? {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let unitPrice = Double(price),
              let qty = Double(quantity), qty > 0 else { return nil }

        let original = Double(originalPrice)
        let onSale = isOnSale || (original != nil && original! > unitPrice)
        let discount = onSale ? max(0, (original ?? unitPrice) - unitPrice) : 0
        let category = InventoryProjection.inferredCategory(for: name)

        return ParsedReceiptLineItem(
            productName: name.trimmingCharacters(in: .whitespaces),
            quantity: qty,
            unitPrice: unitPrice,
            lineTotal: qty * unitPrice,
            originalPrice: original,
            discountAmount: discount,
            isOnSale: onSale,
            quantityUnit: "units",
            expirationDate: hasExpiration ? expirationDate : nil,
            category: category
        )
    }

    var projectionSummary: String? {
        guard let parsed else { return nil }
        let category = parsed.category ?? InventoryProjection.inferredCategory(for: parsed.productName)
        let temp = InventoryItem(
            name: parsed.productName,
            category: category,
            quantity: parsed.quantity,
            expirationDate: parsed.expirationDate,
            typicalUsageRate: InventoryProjection.inferredUsageRate(quantity: parsed.quantity, category: category)
        )
        return InventoryProjection.runOutSummary(for: temp)
    }
}

#Preview {
    AddReceiptView()
        .modelContainer(PreviewModelContainer.shared)
}
