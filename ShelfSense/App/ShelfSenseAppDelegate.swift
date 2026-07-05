//
//  ShelfSenseAppDelegate.swift
//  ShelfSense
//

import CloudKit
import UIKit

final class ShelfSenseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            do {
                try await CloudKitHouseholdService.shared.acceptShare(metadata: cloudKitShareMetadata)
                HapticManager.success()
            } catch {
                await MainActor.run {
                    CloudKitHouseholdService.shared.noteSyncMessage(error.localizedDescription)
                }
            }
        }
    }
}
