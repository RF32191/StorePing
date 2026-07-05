//
//  Household.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class Household {
    var id: UUID
    var name: String
    var createdAt: Date
    var isSharingEnabled: Bool

    init(name: String = "My Household", isSharingEnabled: Bool = false) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.isSharingEnabled = isSharingEnabled
    }
}
