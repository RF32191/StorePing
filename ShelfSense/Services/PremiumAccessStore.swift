//
//  PremiumAccessStore.swift
//  ShelfSense
//

import Foundation
import Observation
import StoreKit

enum PremiumFeature: String, CaseIterable, Identifiable, Sendable {
    case priceCheck
    case gpsCheck
    case barcodeScan
    case receiptScan
    case dealRefresh
    case mealPlanner
    case aiAssistant
    case spinWheel
    case tripOptimizer
    case geofencing
    case familySharing
    case cheapestCart
    case couponMatcher
    case priceHistory
    case pantryReport
    case receiptSplit
    case cookWithPantry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .priceCheck: "Price Search"
        case .gpsCheck: "GPS Near Me"
        case .barcodeScan: "Barcode Scan"
        case .receiptScan: "Receipt Scan"
        case .dealRefresh: "Deal Refresh"
        case .mealPlanner: "Meal Planner"
        case .aiAssistant: "AI Assistant"
        case .spinWheel: "Spin Wheel"
        case .tripOptimizer: "Trip Optimizer"
        case .geofencing: "Store Geofencing"
        case .familySharing: "Family Sharing"
        case .cheapestCart: "Cheapest Cart"
        case .couponMatcher: "Coupon Matcher"
        case .priceHistory: "Price History"
        case .pantryReport: "Pantry Report"
        case .receiptSplit: "Split Receipt"
        case .cookWithPantry: "Cook With Pantry"
        }
    }

    /// One free use per calendar week for these features.
    var weeklyFreeLimit: Int? {
        switch self {
        case .priceCheck, .gpsCheck, .barcodeScan, .receiptScan: 1
        default: nil
        }
    }

    var isFullyGated: Bool {
        weeklyFreeLimit == nil
    }

    var icon: String {
        switch self {
        case .priceCheck: "magnifyingglass"
        case .gpsCheck: "location.fill"
        case .barcodeScan: "barcode.viewfinder"
        case .receiptScan: "doc.text.viewfinder"
        case .dealRefresh: "arrow.clockwise"
        case .mealPlanner: "calendar"
        case .aiAssistant: "sparkles"
        case .spinWheel: "arrow.trianglehead.clockwise"
        case .tripOptimizer: "map.fill"
        case .geofencing: "bell.badge.fill"
        case .familySharing: "person.2.fill"
        case .cheapestCart: "cart.fill"
        case .couponMatcher: "ticket.fill"
        case .priceHistory: "chart.line.uptrend.xyaxis"
        case .pantryReport: "doc.richtext.fill"
        case .receiptSplit: "person.2.wave.2.fill"
        case .cookWithPantry: "refrigerator.fill"
        }
    }
}

enum PremiumAccessReason: Equatable {
    case weeklyLimitReached(PremiumFeature)
    case premiumRequired(PremiumFeature)
}

@Observable
@MainActor
final class PremiumAccessStore {
    static let shared = PremiumAccessStore()

    /// App Store Connect product ID (Reference Name: 48, Apple ID: 6787725652)
    static let unlockProductID = "Store.ping.Unlock"

    /// Manual lifetime unlock credentials (owner/comp access).
    private static let manualUnlockUsername = "ShelfSense"
    private static let manualUnlockPassword = "1994696969969696969696767676769"

    private static let premiumKey = "premiumAccessUnlocked"
    private static let usagePrefix = "premiumWeeklyUsage."

    private(set) var isPremium = false
    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    private(set) var purchaseInFlight = false
    private(set) var lastError: String?

    var paywallPresented = false
    var paywallReason: PremiumAccessReason?

    private var didStartStoreServices = false

    private init() {
        isPremium = UserDefaults.standard.bool(forKey: Self.premiumKey)
    }

    var unlockProduct: Product? {
        products.first { $0.id == Self.unlockProductID }
    }

    /// Short label for the top-bar crown chip.
    var crownBadgeText: String {
        if isPremium { return "PRO" }
        let remaining = weeklyLimitedFeatures.map { remainingUses(for: $0) }.reduce(0, +)
        return remaining > 0 ? "\(remaining)/wk" : "Unlock"
    }

    var weeklyLimitedFeatures: [PremiumFeature] {
        PremiumFeature.allCases.filter { $0.weeklyFreeLimit != nil }
    }

    var fullyGatedFeatures: [PremiumFeature] {
        PremiumFeature.allCases.filter(\.isFullyGated)
    }

    /// StoreKit is deferred until the paywall opens to reduce launch memory and watchdog pressure.
    func beginStoreServicesIfNeeded() {
        guard !didStartStoreServices else { return }
        didStartStoreServices = true
        Task { await refreshProducts() }
        Task { await listenForTransactions() }
        Task { await syncEntitlementsFromAppStore() }
    }

    func refreshProducts() async {
        isLoadingProducts = true
        lastError = nil
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: [Self.unlockProductID])
            if products.isEmpty {
                lastError = "StorePing Pro is temporarily unavailable. Please try again in a moment."
            }
        } catch {
            lastError = "Couldn’t reach the App Store. Check your connection and try again."
        }
    }

    /// Single entry point for the paywall CTA: loads the product if needed, then purchases.
    /// Guarantees the button always does something, even before products finish loading.
    func purchaseUnlock() async {
        if isPremium {
            dismissPaywall()
            return
        }

        if unlockProduct == nil {
            beginStoreServicesIfNeeded()
            await refreshProducts()
        }

        guard let product = unlockProduct else {
            if lastError == nil {
                lastError = "Couldn’t reach the App Store. Check your connection and try again."
            }
            HapticManager.warning()
            return
        }

        await purchase(product)
    }

    func canUse(_ feature: PremiumFeature) -> Bool {
        if isPremium { return true }
        if feature.isFullyGated { return false }
        guard let limit = feature.weeklyFreeLimit else { return true }
        return usageCount(for: feature) < limit
    }

    func remainingUses(for feature: PremiumFeature) -> Int {
        if isPremium { return .max }
        guard let limit = feature.weeklyFreeLimit else { return 0 }
        return max(0, limit - usageCount(for: feature))
    }

    @discardableResult
    func consume(_ feature: PremiumFeature) -> Bool {
        guard canUse(feature) else {
            presentPaywall(for: feature)
            return false
        }
        guard !isPremium, feature.weeklyFreeLimit != nil else { return true }
        let key = usageKey(for: feature)
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
        return true
    }

    func presentPaywall(for feature: PremiumFeature) {
        if feature.isFullyGated || usageCount(for: feature) >= (feature.weeklyFreeLimit ?? 0) {
            paywallReason = feature.isFullyGated
                ? .premiumRequired(feature)
                : .weeklyLimitReached(feature)
        } else {
            paywallReason = .premiumRequired(feature)
        }
        paywallPresented = true
        beginStoreServicesIfNeeded()
        HapticManager.warning()
    }

    func dismissPaywall() {
        paywallPresented = false
        paywallReason = nil
    }

    func purchase(_ product: Product) async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await applyEntitlement(from: transaction)
                await transaction.finish()
                dismissPaywall()
                HapticManager.success()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            try await AppStore.sync()
            await syncEntitlementsFromAppStore()
            if isPremium {
                dismissPaywall()
                HapticManager.success()
            } else {
                lastError = "No \(AppBrand.proName) purchase found for this Apple ID."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Redeems a lifetime unlock with the owner username/password. Returns true on success.
    @discardableResult
    func redeemManualUnlock(username: String, password: String) -> Bool {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard user == Self.manualUnlockUsername, pass == Self.manualUnlockPassword else {
            lastError = "Incorrect username or password."
            HapticManager.warning()
            return false
        }

        lastError = nil
        unlockPremium()
        dismissPaywall()
        HapticManager.success()
        return true
    }

    #if DEBUG
    func unlockForTesting() {
        unlockPremium()
        dismissPaywall()
    }
    #endif

    private func unlockPremium() {
        isPremium = true
        UserDefaults.standard.set(true, forKey: Self.premiumKey)
    }

    private func syncEntitlementsFromAppStore() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                await applyEntitlement(from: transaction)
            }
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await applyEntitlement(from: transaction)
                await transaction.finish()
            }
        }
    }

    private func applyEntitlement(from transaction: Transaction) async {
        guard transaction.productID == Self.unlockProductID else { return }
        if transaction.revocationDate == nil {
            unlockPremium()
        } else {
            isPremium = false
            UserDefaults.standard.set(false, forKey: Self.premiumKey)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }

    private func usageCount(for feature: PremiumFeature) -> Int {
        UserDefaults.standard.integer(forKey: usageKey(for: feature))
    }

    private func usageKey(for feature: PremiumFeature) -> String {
        let calendar = Calendar.current
        let week = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        return Self.usagePrefix + feature.rawValue + ".\(year).\(week)"
    }
}
