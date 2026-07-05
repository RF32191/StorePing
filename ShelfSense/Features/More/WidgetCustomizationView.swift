//
//  WidgetCustomizationView.swift
//  ShelfSense
//

import SwiftUI

struct WidgetCustomizationView: View {
    @Bindable var layoutStore: DashboardLayoutStore

    @State private var mpgText = String(format: "%.0f", VehicleSettingsStore.mpg)
    @State private var vehicleName = VehicleSettingsStore.vehicleName
    @State private var tankText = String(format: "%.0f", VehicleSettingsStore.tankGallons)
    @State private var gasAverageText = String(format: "%.2f", GasPriceService.regionalAverage)

    var body: some View {
        List {
            Section {
                Text("Choose which home widgets appear and drag to reorder.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
            }

            Section {
                TextField("Vehicle name", text: $vehicleName)
                    .onChange(of: vehicleName) { _, value in
                        VehicleSettingsStore.vehicleName = value
                    }

                HStack {
                    Text("MPG")
                    Spacer()
                    TextField("28", text: $mpgText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .onChange(of: mpgText) { _, value in
                            if let mpg = Double(value), mpg > 0 {
                                VehicleSettingsStore.mpg = mpg
                            }
                        }
                }

                HStack {
                    Text("Tank (gal)")
                    Spacer()
                    TextField("14", text: $tankText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .onChange(of: tankText) { _, value in
                            if let tank = Double(value), tank > 0 {
                                VehicleSettingsStore.tankGallons = tank
                            }
                        }
                }

                HStack {
                    Text("Regional gas avg ($/gal)")
                    Spacer()
                    TextField("3.65", text: $gasAverageText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .onChange(of: gasAverageText) { _, value in
                            if let avg = Double(value), avg > 0 {
                                GasPriceService.regionalAverage = avg
                            }
                        }
                }

                Text("Used for gas price estimates and trip cost predictions on the Search tab.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
            } header: {
                Text("Your Vehicle")
            }

            Section("Visible on Home") {
                ForEach(layoutStore.widgetOrder) { widget in
                    HStack(spacing: 12) {
                        Image(systemName: widget.icon)
                            .foregroundStyle(ShelfTheme.copper)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(widget.title)
                                .font(.shelfSubheadline)
                            Text(layoutStore.isVisible(widget) ? "Shown" : "Hidden")
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textTertiary)
                        }

                        Spacer()

                        Button {
                            layoutStore.toggleVisibility(widget)
                        } label: {
                            Image(systemName: layoutStore.isVisible(widget) ? "eye.fill" : "eye.slash")
                                .foregroundStyle(layoutStore.isVisible(widget) ? ShelfTheme.copperLight : ShelfTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove { source, destination in
                    layoutStore.move(from: source, to: destination)
                }
            }

            Section {
                Button("Reset to default") {
                    layoutStore.resetToDefault()
                }
                .foregroundStyle(ShelfTheme.copperLight)
            }
        }
        .navigationTitle("Home Widgets")
        .environment(\.editMode, .constant(.active))
    }
}
