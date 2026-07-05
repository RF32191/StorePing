//
//  NotificationSettingsView.swift
//  ShelfSense
//

import SwiftUI

struct NotificationSettingsView: View {
    @Environment(LocationManager.self) private var locationManager
    @AppStorage("notifyLowStock") private var notifyLowStock = true
    @AppStorage("notifyExpiring") private var notifyExpiring = true
    @AppStorage("notifyDeals") private var notifyDeals = true
    @AppStorage("notifyBudget") private var notifyBudget = true
    @AppStorage("notifyFamily") private var notifyFamily = true
    @AppStorage("smartPrioritization") private var smartPrioritization = true

    var body: some View {
        @Bindable var locationManager = locationManager

        List {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(ShelfTheme.accent)
                    Text("All notifications are generated and delivered locally on your device.")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                }
            }

            Section {
                Toggle("Smart Prioritization", isOn: $smartPrioritization)
            } footer: {
                Text("AI filters notifications to avoid spam and only alerts you when it matters.")
            }

            Section("Inventory Alerts") {
                Toggle("Low Stock Reminders", isOn: $notifyLowStock)
                Toggle("Expiration Warnings", isOn: $notifyExpiring)
            }

            Section("Shopping Alerts") {
                Toggle("Nearby Store Deals", isOn: $locationManager.notifyGeofence)
                Toggle("Price Drops & Deals", isOn: $notifyDeals)
                Toggle("Price Target Alerts", isOn: priceAlertsBinding)
                Toggle("Budget Warnings", isOn: $notifyBudget)
            }

            Section("Household") {
                Toggle("Family Activity", isOn: $notifyFamily)
            }

            Section("Timing") {
                NavigationLink {
                    ExpirationTimingView()
                } label: {
                    Label("Expiration Reminders", systemImage: "clock.fill")
                }
            }
        }
        .navigationTitle("Notifications")
    }

    private var priceAlertsBinding: Binding<Bool> {
        Binding(
            get: { PriceAlertService.notifyPriceAlerts },
            set: { PriceAlertService.notifyPriceAlerts = $0 }
        )
    }
}

struct ExpirationTimingView: View {
    @AppStorage("expireOneMonth") private var expireOneMonth = true
    @AppStorage("expireOneWeek") private var expireOneWeek = true
    @AppStorage("expireOneDay") private var expireOneDay = true
    @AppStorage("expireExpired") private var expireExpired = true

    var body: some View {
        List {
            Toggle("One month remaining", isOn: $expireOneMonth)
            Toggle("One week remaining", isOn: $expireOneWeek)
            Toggle("One day remaining", isOn: $expireOneDay)
            Toggle("Expired items", isOn: $expireExpired)
        }
        .navigationTitle("Expiration Timing")
    }
}
