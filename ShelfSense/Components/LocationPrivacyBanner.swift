//
//  LocationPrivacyBanner.swift
//  ShelfSense
//

import SwiftUI
import CoreLocation

struct LocationPrivacyBanner: View {
    let locationManager: LocationManager
    var compact: Bool = false

    var body: some View {
        GlassCard(padding: compact ? 12 : 14) {
            VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                HStack(spacing: 10) {
                    Image(systemName: locationManager.isLocationAvailable ? "location.fill" : "location.slash.fill")
                        .font(compact ? .body : .title3)
                        .foregroundStyle(locationManager.isLocationAvailable ? ShelfTheme.success : ShelfTheme.warning)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(locationManager.isLocationAvailable ? "GPS Active" : "Enable Location")
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.textPrimary)

                        Text(locationManager.statusDescription)
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }

                    Spacer()

                    if locationManager.isMonitoringActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ShelfTheme.success)
                                .frame(width: 8, height: 8)
                            Text("Live")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(ShelfTheme.success)
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                        .foregroundStyle(ShelfTheme.accent)
                    Text("All location data stays on your device. Nothing is sent to servers.")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textTertiary)
                }

                if !compact && !locationManager.isLocationAvailable {
                    Button {
                        Task { await locationManager.requestPermissions() }
                    } label: {
                        Text("Turn On Location")
                            .font(.shelfSubheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(ShelfTheme.accent.opacity(0.15))
                            .foregroundStyle(ShelfTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                if !compact && locationManager.isLocationAvailable && !locationManager.isAlwaysAuthorized {
                    Button {
                        locationManager.requestAlwaysAccess()
                    } label: {
                        Text("Allow Always Access")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.accentSecondary)
                    }
                }
            }
        }
    }
}
