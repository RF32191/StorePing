//
//  ReceiptSplitView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct ReceiptSplitView: View {
    @Query(sort: \Receipt.purchaseDate, order: .reverse) private var receipts: [Receipt]
    @Query private var lineItems: [ReceiptLineItem]
    @Query private var members: [HouseholdMember]
    @State private var selectedReceipt: Receipt?
    @State private var assignments: [UUID: String] = [:]

    var body: some View {
        List {
            Section {
                Text("Assign receipt line items to household members to split costs fairly.")
                    .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
            }

            Section("Receipt") {
                Picker("Select", selection: $selectedReceipt) {
                    Text("Choose receipt").tag(Optional<Receipt>.none)
                    ForEach(receipts, id: \.id) { receipt in
                        Text("\(receipt.storeName) — \(Formatters.currencyString(receipt.total))").tag(Optional(receipt))
                    }
                }
            }

            if let receipt = selectedReceipt {
                let items = lineItems.filter { $0.receiptID == receipt.id }
                Section("Line Items") {
                    ForEach(items, id: \.id) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.productName).font(.shelfSubheadline)
                                Text(Formatters.currencyString(item.lineTotal))
                                    .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                            }
                            Spacer()
                            Picker("", selection: binding(for: item.id)) {
                                Text("—").tag("")
                                ForEach(memberNames, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }

                Section("Split Summary") {
                    ForEach(splitSummary(receipt: receipt, items: items), id: \.name) { entry in
                        HStack {
                            Text(entry.name)
                            Spacer()
                            Text(Formatters.currencyString(entry.total))
                                .foregroundStyle(ShelfTheme.copperLight)
                        }
                    }
                }

                Section("Settlement") {
                    ForEach(settlementLines(receipt: receipt, items: items), id: \.text) { line in
                        HStack {
                            Text(line.text).font(.shelfCaption)
                            Spacer()
                            Text(line.amount)
                                .font(.shelfCaption)
                                .foregroundStyle(line.isOwed ? ShelfTheme.warning : ShelfTheme.success)
                        }
                    }
                }
            }
        }
        .navigationTitle("Split Receipt")
    }

    private var memberNames: [String] {
        let names = members.map(\.name)
        return names.isEmpty ? ["Me", "Partner", "Roommate"] : names
    }

    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { assignments[id] ?? "" },
            set: { assignments[id] = $0 }
        )
    }

    private func splitSummary(receipt: Receipt, items: [ReceiptLineItem]) -> [(name: String, total: Double)] {
        var totals: [String: Double] = [:]
        for item in items {
            let person = assignments[item.id].flatMap { $0.isEmpty ? nil : $0 } ?? "Unassigned"
            totals[person, default: 0] += item.lineTotal
        }
        return totals.map { (name: $0.key, total: $0.value) }.sorted { $0.name < $1.name }
    }

    private struct SettlementLine: Hashable {
        let text: String
        let amount: String
        let isOwed: Bool
    }

    private func settlementLines(receipt: Receipt, items: [ReceiptLineItem]) -> [SettlementLine] {
        let summary = splitSummary(receipt: receipt, items: items)
        guard summary.count > 1 else { return [] }

        let average = receipt.total / Double(summary.count)
        return summary.map { entry in
            let delta = entry.total - average
            if abs(delta) < 0.01 {
                return SettlementLine(text: "\(entry.name) is settled up", amount: "—", isOwed: false)
            }
            if delta > 0 {
                return SettlementLine(
                    text: "\(entry.name) owes the group",
                    amount: Formatters.currencyString(delta),
                    isOwed: true
                )
            }
            return SettlementLine(
                text: "Group owes \(entry.name)",
                amount: Formatters.currencyString(abs(delta)),
                isOwed: false
            )
        }
    }
}
