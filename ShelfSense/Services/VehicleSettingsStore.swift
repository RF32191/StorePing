//
//  VehicleSettingsStore.swift
//  ShelfSense
//

import Foundation

enum VehicleSettingsStore {
    private static let mpgKey = "vehicleMPG"
    private static let nameKey = "vehicleName"
    private static let tankKey = "vehicleTankGallons"

    static var mpg: Double {
        get {
            let value = UserDefaults.standard.double(forKey: mpgKey)
            return value > 0 ? value : 28
        }
        set { UserDefaults.standard.set(max(newValue, 1), forKey: mpgKey) }
    }

    static var vehicleName: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? "My Car" }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    static var tankGallons: Double {
        get {
            let value = UserDefaults.standard.double(forKey: tankKey)
            return value > 0 ? value : 14
        }
        set { UserDefaults.standard.set(max(newValue, 1), forKey: tankKey) }
    }

    static func tripFuelCost(miles: Double, pricePerGallon: Double) -> Double {
        guard mpg > 0 else { return 0 }
        return (miles / mpg) * pricePerGallon
    }

    static func gallonsNeeded(miles: Double) -> Double {
        guard mpg > 0 else { return 0 }
        return miles / mpg
    }
}
