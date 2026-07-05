//
//  Array+Reorder.swift
//  ShelfSense
//

import Foundation

extension Array {
    mutating func moveItems(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.map { self[$0] }
        for index in offsets.sorted(by: >) {
            remove(at: index)
        }
        let insertIndex = Swift.min(Swift.max(destination - offsets.filter { $0 < destination }.count, 0), count)
        insert(contentsOf: moving, at: insertIndex)
    }
}
