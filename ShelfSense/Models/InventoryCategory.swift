//
//  InventoryCategory.swift
//  ShelfSense
//

import Foundation

enum InventoryCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case groceries
    case pantry
    case refrigerator
    case freezer
    case cleaningSupplies
    case toiletries
    case medicine
    case petSupplies
    case babyProducts
    case electronics
    case officeSupplies
    case clothing
    case shoes
    case kitchenItems
    case automotiveSupplies
    case hardware
    case seasonalDecorations
    case everythingElse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groceries: "Groceries"
        case .pantry: "Pantry"
        case .refrigerator: "Refrigerator"
        case .freezer: "Freezer"
        case .cleaningSupplies: "Cleaning Supplies"
        case .toiletries: "Toiletries"
        case .medicine: "Medicine"
        case .petSupplies: "Pet Supplies"
        case .babyProducts: "Baby Products"
        case .electronics: "Electronics"
        case .officeSupplies: "Office Supplies"
        case .clothing: "Clothing"
        case .shoes: "Shoes"
        case .kitchenItems: "Kitchen Items"
        case .automotiveSupplies: "Automotive Supplies"
        case .hardware: "Hardware"
        case .seasonalDecorations: "Seasonal Decorations"
        case .everythingElse: "Everything Else"
        }
    }

    var icon: String {
        switch self {
        case .groceries: "cart.fill"
        case .pantry: "cabinet.fill"
        case .refrigerator: "refrigerator.fill"
        case .freezer: "snowflake"
        case .cleaningSupplies: "bubbles.and.sparkles.fill"
        case .toiletries: "drop.fill"
        case .medicine: "cross.case.fill"
        case .petSupplies: "pawprint.fill"
        case .babyProducts: "figure.and.child.holdinghands"
        case .electronics: "desktopcomputer"
        case .officeSupplies: "pencil.and.ruler.fill"
        case .clothing: "tshirt.fill"
        case .shoes: "shoe.fill"
        case .kitchenItems: "frying.pan.fill"
        case .automotiveSupplies: "car.fill"
        case .hardware: "wrench.and.screwdriver.fill"
        case .seasonalDecorations: "sparkles"
        case .everythingElse: "square.grid.2x2.fill"
        }
    }
}
