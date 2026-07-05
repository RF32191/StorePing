//
//  AlertsCenterView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct AlertsCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager

    @Query(sort: \PriceAlert.createdAt, order: .reverse) private var priceAlerts: [PriceAlert]
    @State private var showAddPriceAlert = false

    var body: some View {
        @Bindable var locationManager = locationManager

        List {
            Section {
                LocationPrivacyBanner(locationManager: locationManager, compact: true)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("GPS Store Alerts") {
                Toggle("Geofence alerts", isOn: $locationManager.geofencingEnabled)
                Toggle("Notify when nearby", isOn: $locationManager.notifyGeofence)

                LabeledContent("Status", value: locationManager.statusDescription)

                if locationManager.activeNearbyStores.isEmpty {
                    Text("No stores nearby right now. Save favorite stores and enable Always location for background alerts.")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                } else {
                    ForEach(locationManager.activeNearbyStores) { presence in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(presence.storeName)
                                    .font(.shelfSubheadline)
                                Text(presence.subtitle)
                                    .font(.shelfCaption)
                                    .foregroundStyle(ShelfTheme.textSecondary)
                            }
                            Spacer()
                            Text(presence.distanceLabel)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.copperLight)
                        }
                    }
                }
            }

            Section("Recent GPS Alerts") {
                if locationManager.nearbyAlerts.isEmpty {
                    Text("Alerts appear when you approach saved stores with deals or low-stock items.")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                } else {
                    ForEach(locationManager.nearbyAlerts.prefix(10)) { alert in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.title)
                                .font(.shelfSubheadline)
                            Text(alert.message)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)
                            Text(Formatters.relativeString(from: alert.timestamp))
                                .font(.system(size: 10))
                                .foregroundStyle(ShelfTheme.textTertiary)
                        }
                    }
                }
            }

            Section {
                Toggle("Price drop alerts", isOn: priceAlertsEnabled)
                Button {
                    showAddPriceAlert = true
                } label: {
                    Label("Add price alert", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Price Alerts")
            } footer: {
                Text("Get notified when an item drops to your target price at any saved store.")
            }

            if !priceAlerts.isEmpty {
                Section("Watching") {
                    ForEach(priceAlerts, id: \.id) { alert in
                        PriceAlertRow(alert: alert)
                    }
                    .onDelete(perform: deleteAlerts)
                }
            }
        }
        .navigationTitle("Alerts")
        .sheet(isPresented: $showAddPriceAlert) {
            AddPriceAlertView()
        }
    }

    private var priceAlertsEnabled: Binding<Bool> {
        Binding(
            get: { PriceAlertService.notifyPriceAlerts },
            set: { PriceAlertService.notifyPriceAlerts = $0 }
        )
    }

    private func deleteAlerts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(priceAlerts[index])
        }
    }
}

struct PriceAlertRow: View {
    @Bindable var alert: PriceAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(alert.productName)
                    .font(.shelfSubheadline)
                Spacer()
                Toggle("", isOn: $alert.isEnabled)
                    .labelsHidden()
            }

            HStack(spacing: 8) {
                if let brand = alert.brand {
                    Text(brand)
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.copperLight)
                }
                Text("Target \(Formatters.currencyString(alert.targetPrice))")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
            }

            if let price = alert.lastKnownPrice {
                Text("Last seen \(Formatters.currencyString(price))")
                    .font(.system(size: 10))
                    .foregroundStyle(ShelfTheme.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddPriceAlertView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var productName = ""
    @State private var brand = ""
    @State private var targetPrice = ""
    @State private var storeName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Item name", text: $productName)
                    TextField("Brand (optional)", text: $brand)
                }
                Section("Alert") {
                    TextField("Target price", text: $targetPrice)
                        .keyboardType(.decimalPad)
                    TextField("Store (optional)", text: $storeName)
                }
            }
            .navigationTitle("Price Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(productName.isEmpty || Double(targetPrice) == nil)
                }
            }
        }
    }

    private func save() {
        guard let price = Double(targetPrice) else { return }
        let alert = PriceAlert(
            productName: productName.trimmingCharacters(in: .whitespaces),
            brand: brand.isEmpty ? nil : brand,
            targetPrice: price,
            storeName: storeName.isEmpty ? nil : storeName
        )
        modelContext.insert(alert)
        HapticManager.success()
        dismiss()
    }
}
