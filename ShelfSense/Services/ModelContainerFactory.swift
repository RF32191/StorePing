//
//  ModelContainerFactory.swift
//  ShelfSense
//

import Foundation
import SwiftData

enum ModelContainerFactory {
    static let schema = Schema([
        Household.self,
        HouseholdMember.self,
        InventoryItem.self,
        Store.self,
        Deal.self,
        ShoppingListItem.self,
        Receipt.self,
        ReceiptLineItem.self,
        Budget.self,
        PriceAlert.self,
        PriceHistoryEntry.self,
        Coupon.self,
        WasteEntry.self,
        MealPlanEntry.self,
    ])

    private static let storeFileName = "ShelfSense.store"
    private static let schemaVersion = 4
    private static var cachedContainer: ModelContainer?

    @MainActor
    static func makeSharedContainer() -> ModelContainer {
        if let cachedContainer {
            return cachedContainer
        }

        ensureApplicationSupportDirectoryExists()
        migrateSchemaIfNeeded()

        if let container = openContainer(at: persistentStoreURL) {
            clearRecoveryFlag()
            cachedContainer = container
            return container
        }

        resetAllPersistentStoreFiles()

        if let container = openContainer(at: persistentStoreURL) {
            clearRecoveryFlag()
            cachedContainer = container
            return container
        }

        if let container = openInMemoryContainer() {
            UserDefaults.standard.set(true, forKey: StorageKeys.storeRecoveryUsed)
            cachedContainer = container
            return container
        }

        if let cachedContainer {
            return cachedContainer
        }

        assertionFailure("Unable to open SwiftData store — using in-memory fallback.")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        if let emergency = try? ModelContainer(for: schema, configurations: [config]) {
            cachedContainer = emergency
            return emergency
        }

        cachedContainer = PreviewModelContainer.shared
        return PreviewModelContainer.shared
    }

    static var usedInMemoryFallback: Bool {
        UserDefaults.standard.bool(forKey: StorageKeys.storeRecoveryUsed)
    }

    private static func openContainer(at storeURL: URL) -> ModelContainer? {
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    private static func openInMemoryContainer() -> ModelContainer? {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    private static var applicationSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    private static var persistentStoreURL: URL {
        applicationSupportURL.appendingPathComponent(storeFileName, isDirectory: false)
    }

    private static func ensureApplicationSupportDirectoryExists() {
        let directory = applicationSupportURL
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private static func resetAllPersistentStoreFiles() {
        for name in ["ShelfSense.store", "default.store"] {
            resetStoreFamily(at: applicationSupportURL.appendingPathComponent(name))
        }
    }

    private static func resetStoreFamily(at url: URL) {
        for fileURL in [url, URL(fileURLWithPath: url.path + "-shm"), URL(fileURLWithPath: url.path + "-wal")]
            where FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func clearRecoveryFlag() {
        UserDefaults.standard.set(false, forKey: StorageKeys.storeRecoveryUsed)
    }

    private static func migrateSchemaIfNeeded() {
        let key = StorageKeys.schemaVersion
        let current = UserDefaults.standard.integer(forKey: key)
        guard current < schemaVersion else { return }
        resetAllPersistentStoreFiles()
        UserDefaults.standard.set(schemaVersion, forKey: key)
    }

    static func resetAllStoresOnDisk() {
        cachedContainer = nil
        ensureApplicationSupportDirectoryExists()
        resetAllPersistentStoreFiles()
        UserDefaults.standard.removeObject(forKey: StorageKeys.storeRecoveryUsed)
        UserDefaults.standard.set(schemaVersion, forKey: StorageKeys.schemaVersion)
    }
}

private enum StorageKeys {
    static let storeRecoveryUsed = "modelContainerStoreRecoveryUsed"
    static let schemaVersion = "modelContainerSchemaVersion"
}
