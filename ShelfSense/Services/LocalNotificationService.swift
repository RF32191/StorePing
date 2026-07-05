//
//  LocalNotificationService.swift
//  ShelfSense
//

import Foundation
import UserNotifications

enum LocalNotificationService {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Posts a notification entirely on-device. Nothing is sent to external servers.
    static func postNearbyStoreAlert(
        title: String,
        body: String,
        storeID: UUID
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "NEARBY_STORE"
        content.userInfo = ["storeID": storeID.uuidString, "localOnly": true]

        let request = UNNotificationRequest(
            identifier: "nearby-\(storeID.uuidString)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    static func postPriceAlert(title: String, body: String, alertID: UUID) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "PRICE_ALERT"
        content.userInfo = ["alertID": alertID.uuidString, "localOnly": true]

        let request = UNNotificationRequest(
            identifier: "price-\(alertID.uuidString)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
