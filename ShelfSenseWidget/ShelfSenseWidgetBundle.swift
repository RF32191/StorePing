//
//  ShelfSenseWidgetBundle.swift
//  ShelfSenseWidget
//

import WidgetKit
import SwiftUI

@main
struct ShelfSenseWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShoppingListWidget()
        LevelBadgeWidget()
        ExpiringSoonWidget()
        DailyQuestsWidget()
        ShelfSenseDashboardWidget()
    }
}
