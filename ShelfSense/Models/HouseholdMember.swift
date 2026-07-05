//
//  HouseholdMember.swift
//  ShelfSense
//

import Foundation
import SwiftData

@Model
final class HouseholdMember {
    var id: UUID
    var name: String
    var email: String?
    var roleRaw: String
    var colorHex: String
    var isCurrentUser: Bool
    var createdAt: Date

    @Transient
    var role: HouseholdRole {
        get { HouseholdRole(rawValue: roleRaw) ?? .member }
        set { roleRaw = newValue.rawValue }
    }

    var household: Household?

    init(name: String, email: String? = nil, role: HouseholdRole = .member, colorHex: String = "B87333", isCurrentUser: Bool = false) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.roleRaw = role.rawValue
        self.colorHex = colorHex
        self.isCurrentUser = isCurrentUser
        self.createdAt = Date()
    }
}

enum HouseholdRole: String, CaseIterable, Codable {
    case owner, member, child

    var title: String {
        rawValue.capitalized
    }
}
