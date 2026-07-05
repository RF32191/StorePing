//
//  CloudKitHouseholdService.swift
//  ShelfSense
//

import CloudKit
import Foundation
import Observation
import SwiftData

enum CloudKitSyncStatus: Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case error(String)

    var title: String {
        switch self {
        case .checking: "Checking iCloud…"
        case .available: "iCloud sync active"
        case .noAccount: "Sign in to iCloud"
        case .restricted: "iCloud restricted"
        case .temporarilyUnavailable: "iCloud temporarily unavailable"
        case .error(let message): message
        }
    }

    var icon: String {
        switch self {
        case .available: "icloud.fill"
        case .noAccount: "icloud.slash"
        case .restricted, .temporarilyUnavailable, .error: "exclamationmark.icloud"
        default: "icloud"
        }
    }
}

@Observable
@MainActor
final class CloudKitHouseholdService {
    static let shared = CloudKitHouseholdService()

    private(set) var syncStatus: CloudKitSyncStatus = .checking
    private(set) var isShareActive = false
    private(set) var lastSyncMessage: String?

    private var modelContainer: ModelContainer?
    private let ckContainer = CKContainer(identifier: CloudKitConfig.containerIdentifier)

    private static let householdRecordType = "HouseholdRoot"
    private static let listItemRecordType = "SharedListItem"
    private static let mealPlanRecordType = "SharedMealPlanEntry"
    private static let householdRecordID = CKRecord.ID(recordName: "primary-household")

    private init() {}

    func configure(container: ModelContainer) {
        modelContainer = container
    }

    func refreshAccountStatus() async {
        syncStatus = .checking
        do {
            let status = try await ckContainer.accountStatus()
            switch status {
            case .available: syncStatus = .available
            case .noAccount: syncStatus = .noAccount
            case .restricted: syncStatus = .restricted
            case .couldNotDetermine, .temporarilyUnavailable: syncStatus = .temporarilyUnavailable
            @unknown default: syncStatus = .temporarilyUnavailable
            }
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    func prepareShare(for household: Household, context: ModelContext) async throws -> (CKShare, CKContainer) {
        let database = ckContainer.privateCloudDatabase
        let root = try await fetchOrCreateHouseholdRoot(in: database, household: household)
        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = household.name as CKRecordValue
        share.publicPermission = .none

        let listItems = householdListItems(household: household, context: context)
        let mealPlans = householdMealPlans(household: household, context: context)

        var toSave: [CKRecord] = [root, share]
        toSave.append(contentsOf: listRecords(for: listItems, household: household))
        toSave.append(contentsOf: mealPlanRecords(for: mealPlans, household: household))
        _ = try await database.modifyRecords(saving: toSave, deleting: [])

        household.isSharingEnabled = true
        isShareActive = true
        lastSyncMessage = "Invite family — they'll see shared lists and meal plans."
        try context.save()

        return (share, ckContainer)
    }

    func acceptShare(metadata: CKShare.Metadata) async throws {
        try await ckContainer.accept(metadata)
        isShareActive = true
        lastSyncMessage = "Joined household — syncing shared data…"

        if let modelContainer {
            let context = ModelContext(modelContainer)
            if let household = HouseholdBootstrapService.fetchPrimaryHousehold(context: context) {
                household.isSharingEnabled = true
            }
            try await pullSharedData(into: context)
            try context.save()
        }
    }

    func syncSharedData(context: ModelContext) async {
        guard syncStatus == .available else { return }
        guard let household = HouseholdBootstrapService.fetchPrimaryHousehold(context: context) else { return }

        if household.isSharingEnabled {
            isShareActive = true
        }

        do {
            try await pushLocalData(household: household, context: context)
            try await pullSharedData(into: context)
            lastSyncMessage = "Household synced \(Date().formatted(date: .omitted, time: .shortened))"
        } catch {
            noteSyncMessage("Sync issue: \(error.localizedDescription)")
        }
    }

    func noteSyncMessage(_ message: String) {
        lastSyncMessage = message
    }

    func recentActivity(
        from listItems: [ShoppingListItem],
        mealPlans: [MealPlanEntry],
        members: [HouseholdMember]
    ) -> [FamilyActivityItem] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let fallbackMember = members.first(where: \.isCurrentUser)?.name ?? "Someone"

        let listActivity = listItems
            .filter { $0.createdAt >= weekAgo }
            .map { item in
                FamilyActivityItem(
                    memberName: item.assignedTo ?? fallbackMember,
                    action: item.isCompleted ? "checked off" : "added",
                    itemName: item.name,
                    timestamp: item.createdAt
                )
            }

        let mealActivity = mealPlans
            .filter { $0.createdAt >= weekAgo }
            .map { entry in
                FamilyActivityItem(
                    memberName: fallbackMember,
                    action: entry.isCompleted ? "finished" : "planned",
                    itemName: "\(entry.recipeName) (\(entry.mealType.title))",
                    timestamp: entry.createdAt
                )
            }

        return (listActivity + mealActivity)
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(6)
            .map { $0 }
    }

    // MARK: - CloudKit mirror

    private func fetchOrCreateHouseholdRoot(in database: CKDatabase, household: Household) async throws -> CKRecord {
        do {
            return try await database.record(for: Self.householdRecordID)
        } catch {
            let record = CKRecord(recordType: Self.householdRecordType, recordID: Self.householdRecordID)
            record["name"] = household.name as CKRecordValue
            record["householdID"] = household.id.uuidString as CKRecordValue
            record["createdAt"] = household.createdAt as CKRecordValue
            return record
        }
    }

    private func householdListItems(household: Household, context: ModelContext) -> [ShoppingListItem] {
        (try? context.fetch(FetchDescriptor<ShoppingListItem>()))?
            .filter { $0.household?.id == household.id } ?? []
    }

    private func householdMealPlans(household: Household, context: ModelContext) -> [MealPlanEntry] {
        (try? context.fetch(FetchDescriptor<MealPlanEntry>()))?
            .filter { $0.household?.id == household.id } ?? []
    }

    private func listRecords(for items: [ShoppingListItem], household: Household) -> [CKRecord] {
        items.map { item in
            let record = CKRecord(recordType: Self.listItemRecordType, recordID: CKRecord.ID(recordName: item.id.uuidString))
            record["name"] = item.name as CKRecordValue
            record["brand"] = item.brand as CKRecordValue?
            record["quantity"] = item.quantity as CKRecordValue
            record["isCompleted"] = (item.isCompleted ? 1 : 0) as CKRecordValue
            record["assignedTo"] = item.assignedTo as CKRecordValue?
            record["estimatedPrice"] = item.estimatedPrice as CKRecordValue?
            record["createdAt"] = item.createdAt as CKRecordValue
            record["householdID"] = household.id.uuidString as CKRecordValue
            return record
        }
    }

    private func mealPlanRecords(for entries: [MealPlanEntry], household: Household) -> [CKRecord] {
        entries.map { entry in
            let record = CKRecord(
                recordType: Self.mealPlanRecordType,
                recordID: CKRecord.ID(recordName: entry.id.uuidString)
            )
            record["recipeID"] = entry.recipeID as CKRecordValue
            record["recipeName"] = entry.recipeName as CKRecordValue
            record["scheduledDate"] = entry.scheduledDate as CKRecordValue
            record["mealTypeRaw"] = entry.mealTypeRaw as CKRecordValue
            record["isCompleted"] = (entry.isCompleted ? 1 : 0) as CKRecordValue
            record["createdAt"] = entry.createdAt as CKRecordValue
            record["householdID"] = household.id.uuidString as CKRecordValue
            return record
        }
    }

    private func pushLocalData(household: Household, context: ModelContext) async throws {
        guard isShareActive || household.isSharingEnabled else { return }

        let listItems = householdListItems(household: household, context: context)
        let mealPlans = householdMealPlans(household: household, context: context)

        try await syncRecordTypeToSharedDatabase(
            recordType: Self.listItemRecordType,
            localRecordIDs: Set(listItems.map { $0.id.uuidString }),
            records: listRecords(for: listItems, household: household)
        )

        try await syncRecordTypeToSharedDatabase(
            recordType: Self.mealPlanRecordType,
            localRecordIDs: Set(mealPlans.map { $0.id.uuidString }),
            records: mealPlanRecords(for: mealPlans, household: household)
        )
    }

    private func syncRecordTypeToSharedDatabase(
        recordType: String,
        localRecordIDs: Set<String>,
        records: [CKRecord]
    ) async throws {
        let database = ckContainer.sharedCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let results = try await database.records(matching: query)

        var toDelete: [CKRecord.ID] = []
        for (_, result) in results.matchResults {
            guard let record = try? result.get() else { continue }
            if !localRecordIDs.contains(record.recordID.recordName) {
                toDelete.append(record.recordID)
            }
        }

        if records.isEmpty && toDelete.isEmpty { return }
        _ = try await database.modifyRecords(saving: records, deleting: toDelete)
    }

    private func pullSharedData(into context: ModelContext) async throws {
        let household = HouseholdBootstrapService.bootstrap(context: context)
        let databases: [CKDatabase] = [ckContainer.sharedCloudDatabase, ckContainer.privateCloudDatabase]

        for database in databases {
            let listQuery = CKQuery(recordType: Self.listItemRecordType, predicate: NSPredicate(value: true))
            let listResults = try await database.records(matching: listQuery)
            for (_, result) in listResults.matchResults {
                guard let record = try? result.get() else { continue }
                mergeListRecord(record, household: household, context: context)
            }

            let mealQuery = CKQuery(recordType: Self.mealPlanRecordType, predicate: NSPredicate(value: true))
            let mealResults = try await database.records(matching: mealQuery)
            for (_, result) in mealResults.matchResults {
                guard let record = try? result.get() else { continue }
                mergeMealPlanRecord(record, household: household, context: context)
            }
        }

        try context.save()
        WidgetSnapshotSyncService.sync(context: context)
    }

    private func mergeListRecord(_ record: CKRecord, household: Household, context: ModelContext) {
        guard let name = record["name"] as? String else { return }
        let recordUUID = UUID(uuidString: record.recordID.recordName) ?? UUID()

        let existing = ((try? context.fetch(FetchDescriptor<ShoppingListItem>())) ?? [])
            .first { $0.id == recordUUID }

        let item = existing ?? ShoppingListItem(name: name)
        if existing == nil {
            item.id = recordUUID
            context.insert(item)
        }

        item.name = name
        item.brand = record["brand"] as? String
        item.quantity = record["quantity"] as? Double ?? item.quantity
        item.isCompleted = (record["isCompleted"] as? Int ?? 0) == 1
        item.assignedTo = record["assignedTo"] as? String
        item.estimatedPrice = record["estimatedPrice"] as? Double
        if let createdAt = record["createdAt"] as? Date {
            item.createdAt = createdAt
        }
        item.household = household
    }

    private func mergeMealPlanRecord(_ record: CKRecord, household: Household, context: ModelContext) {
        guard
            let recipeID = record["recipeID"] as? String,
            let recipeName = record["recipeName"] as? String
        else { return }

        let recordUUID = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let existing = ((try? context.fetch(FetchDescriptor<MealPlanEntry>())) ?? [])
            .first { $0.id == recordUUID }

        let entry: MealPlanEntry
        if let existing {
            entry = existing
        } else {
            let scheduledDate = record["scheduledDate"] as? Date ?? Date()
            let mealTypeRaw = record["mealTypeRaw"] as? String ?? MealType.dinner.rawValue
            entry = MealPlanEntry(
                recipeID: recipeID,
                recipeName: recipeName,
                scheduledDate: scheduledDate,
                mealType: MealType(rawValue: mealTypeRaw) ?? .dinner
            )
            entry.id = recordUUID
            context.insert(entry)
        }

        entry.recipeID = recipeID
        entry.recipeName = recipeName
        if let scheduledDate = record["scheduledDate"] as? Date {
            entry.scheduledDate = scheduledDate
        }
        if let mealTypeRaw = record["mealTypeRaw"] as? String {
            entry.mealTypeRaw = mealTypeRaw
        }
        entry.isCompleted = (record["isCompleted"] as? Int ?? 0) == 1
        if let createdAt = record["createdAt"] as? Date {
            entry.createdAt = createdAt
        }
        entry.household = household
    }
}

enum CloudKitHouseholdError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured: "CloudKit is not configured yet."
        }
    }
}
