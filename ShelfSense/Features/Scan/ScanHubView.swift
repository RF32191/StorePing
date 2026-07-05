//
//  ScanHubView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData
import AVFoundation

struct ScanHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumAccessStore.self) private var premiumStore

    @State private var selectedMode: ScanMode = .barcode
    @State private var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var showAddItem = false
    @State private var showAddReceipt = false
    @State private var isScanning = false
    @State private var scannedBarcode: String?
    @State private var showScanResult = false

    enum ScanMode: String, CaseIterable {
        case barcode = "Barcode"
        case receipt = "Receipt"

        var icon: String {
            switch self {
            case .barcode: "barcode.viewfinder"
            case .receipt: "doc.text.viewfinder"
            }
        }

        var description: String {
            switch self {
            case .barcode: "Scan any product barcode — nutrition, allergens, add to inventory or list"
            case .receipt: "Scan receipts to update inventory and discover in-store deals"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Scan Mode", selection: $selectedMode) {
                        ForEach(ScanMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if selectedMode == .barcode && isScanning && cameraPermission == .authorized {
                        BarcodeScannerView { barcode in
                            scannedBarcode = barcode
                            isScanning = false
                            showScanResult = true
                        }
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: ShelfTheme.cornerRadiusLarge, style: .continuous))
                        .padding(.horizontal)
                    } else {
                        scanPreview
                    }

                    VStack(spacing: 8) {
                        Text(selectedMode.rawValue + " Scanner")
                            .font(.shelfTitle)
                            .foregroundStyle(ShelfTheme.textPrimary)
                        Text(selectedMode.description)
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    if !premiumStore.isPremium {
                        Text("Free plan: \(premiumStore.remainingUses(for: selectedMode == .barcode ? .barcodeScan : .receiptScan)) scan left this week")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ShelfTheme.copperLight)
                    }

                    if cameraPermission != .authorized {
                        Button("Enable Camera") { requestCameraAccess() }
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.accent)
                    } else if selectedMode == .barcode {
                        Button(isScanning ? "Stop Scanning" : "Start Barcode Scan") {
                            if isScanning {
                                isScanning = false
                            } else if premiumStore.consume(.barcodeScan) {
                                isScanning = true
                            }
                        }
                        .font(.shelfHeadline)
                        .foregroundStyle(ShelfTheme.copperLight)
                    }

                    featureList
                    actionButtons
                }
                .padding(.top)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(ShelfGradientBackground())
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddInventoryItemView()
                    .modelContainer(modelContext.container)
            }
            .sheet(isPresented: $showAddReceipt) {
                AddReceiptView()
                    .modelContainer(modelContext.container)
            }
            .sheet(isPresented: $showScanResult) {
                if let scannedBarcode {
                    BarcodeScanResultView(barcode: scannedBarcode)
                        .modelContainer(modelContext.container)
                }
            }
            .onAppear {
                cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
            }
            .onChange(of: selectedMode) { _, _ in
                isScanning = false
            }
        }
    }

    private var scanPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ShelfTheme.cornerRadiusLarge, style: .continuous)
                .fill(ShelfTheme.backgroundSecondary)
                .frame(height: 240)
                .overlay {
                    RoundedRectangle(cornerRadius: ShelfTheme.cornerRadiusLarge, style: .continuous)
                        .strokeBorder(ShelfTheme.accent.opacity(0.4), lineWidth: 2)
                }

            VStack(spacing: 16) {
                Image(systemName: selectedMode.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(ShelfTheme.accent)
                    .symbolEffect(.pulse)

                Text(cameraPermission == .authorized ? "Tap Start to scan" : "Camera access required")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
            }
        }
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button { showAddItem = true } label: {
                Label("Add Item Manually", systemImage: "plus.circle.fill")
                    .font(.shelfSubheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ShelfTheme.backgroundSecondary)
                    .foregroundStyle(ShelfTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if selectedMode == .receipt {
                Button {
                    if premiumStore.consume(.receiptScan) {
                        showAddReceipt = true
                    }
                } label: {
                    Label("Scan or Enter Receipt", systemImage: "doc.text.viewfinder")
                        .font(.shelfSubheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ShelfTheme.accent.opacity(0.15))
                        .foregroundStyle(ShelfTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(.horizontal)
    }

    private var featureList: some View {
        VStack(spacing: 12) {
            if selectedMode == .barcode {
                featureRow(icon: "leaf.fill", title: "Nutrition & Nutri-Score", subtitle: "Calories, carbs, allergens from Open Food Facts")
                featureRow(icon: "plus.circle.fill", title: "Inventory or List", subtitle: "Add scanned products instantly")
            } else {
                featureRow(icon: "text.viewfinder", title: "OCR extraction", subtitle: "Store, date, items, prices, and totals")
                featureRow(icon: "tag.fill", title: "Deal discovery", subtitle: "Sale items become store-specific deals")
            }
        }
        .padding(.horizontal)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(ShelfTheme.accent).frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.shelfSubheadline).foregroundStyle(ShelfTheme.textPrimary)
                    Text(subtitle).font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                }
                Spacer()
            }
        }
    }

    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermission = granted ? .authorized : .denied
            }
        }
    }
}

#Preview {
    ScanHubView()
        .environment(PremiumAccessStore.shared)
        .modelContainer(PreviewModelContainer.shared)
}
