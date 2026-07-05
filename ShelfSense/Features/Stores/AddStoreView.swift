//
//  AddStoreView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct AddStoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(DealEngine.self) private var dealEngine

    @State private var name = ""
    @State private var selectedChain: StoreChain = .target
    @State private var address = ""
    @State private var websiteURL = ""
    @State private var dealsPageURL = ""
    @State private var isFavorite = true
    @State private var radius: Double = 500
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Business") {
                    Picker("Chain", selection: $selectedChain) {
                        ForEach(StoreChain.allCases) { chain in
                            Label(chain.displayName, systemImage: chain.icon).tag(chain)
                        }
                    }
                    .onChange(of: selectedChain) { _, chain in
                        if name.isEmpty || StoreChain.allCases.map(\.displayName).contains(name) {
                            name = chain == .custom ? "" : chain.displayName
                        }
                    }

                    TextField("Store name", text: $name)

                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(2...4)

                    TextField("Website (optional)", text: $websiteURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    TextField("Deals page URL (optional)", text: $dealsPageURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section("Alerts") {
                    Toggle("Favorite store", isOn: $isFavorite)

                    Stepper(value: $radius, in: 100...2000, step: 50) {
                        Text("Geofence radius: \(Int(radius))m")
                    }
                }

                if selectedChain.weeklyAdURL != nil || !dealsPageURL.isEmpty {
                    Section("Deals") {
                        if selectedChain.weeklyAdURL != nil {
                            Label("Chain deals page will sync automatically", systemImage: "newspaper.fill")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)
                        }
                        if selectedChain == .custom {
                            Text("Add a website or deals URL to pull online promotions for this store.")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveStore() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func saveStore() async {
        isSaving = true
        let store = Store(
            name: name.trimmingCharacters(in: .whitespaces),
            chain: selectedChain,
            address: address.isEmpty ? nil : address,
            isFavorite: isFavorite,
            notificationRadiusMeters: radius,
            dealsPageURL: dealsPageURL.isEmpty ? nil : dealsPageURL,
            websiteURL: websiteURL.isEmpty ? nil : websiteURL
        )
        modelContext.insert(store)
        await StoreGeocoder.geocode(store: store)
        await dealEngine.refreshStore(store, context: modelContext)
        LocationManager.shared.refreshGeofences()
        HapticManager.success()
        dismiss()
    }
}
