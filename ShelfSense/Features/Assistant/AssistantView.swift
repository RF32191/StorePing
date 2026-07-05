//
//  AssistantView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct AssistantView: View {
    @Query private var inventoryItems: [InventoryItem]
    @Query private var deals: [Deal]
    @Query private var stores: [Store]
    @Query private var receipts: [Receipt]
    @Query private var listItems: [ShoppingListItem]
    @Query private var wasteEntries: [WasteEntry]
    @Query private var mealPlans: [MealPlanEntry]
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var showItemSearch = false
    @State private var itemSearchQuery = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if messages.isEmpty {
                    welcomeView
                } else {
                    messageList
                }

                inputBar
            }
            .background(ShelfGradientBackground())
            .navigationTitle("AI Assistant")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showItemSearch = true
                    } label: {
                        Label("Compare Prices", systemImage: "magnifyingglass.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showItemSearch) {
                NavigationStack {
                    ItemSearchView(initialQuery: itemSearchQuery)
                }
            }
            .onAppear {
                if messages.isEmpty {
                    messages.append(ChatMessage(
                        role: .assistant,
                        text: "Hi! I'm your \(AppBrand.name) assistant. Ask me about your inventory, deals, shopping lists, or what expires this week."
                    ))
                }
            }
        }
    }

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 32)

                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ShelfTheme.accent, ShelfTheme.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("How can I help?")
                    .font(.shelfTitle)
                    .foregroundStyle(ShelfTheme.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(suggestedPrompts, id: \.self) { prompt in
                        Button {
                            sendMessage(prompt)
                        } label: {
                            Text(prompt)
                                .font(.shelfCaption)
                                .foregroundStyle(ShelfTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(ShelfTheme.backgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }

                    if isTyping {
                        TypingIndicator()
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask \(AppBrand.name)...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ShelfTheme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.isEmpty ? ShelfTheme.textTertiary : ShelfTheme.accent)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var suggestedPrompts: [String] {
        [
            "Compare prices for milk",
            "What's running low?",
            "What expires this week?",
            "Plan dinner this week",
            "Cook with my pantry",
            "Optimize my shopping trip",
            "Show macro summary",
            "Any substitutes for butter?"
        ]
    }

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        inputText = ""
        isInputFocused = false
        HapticManager.lightImpact()

        isTyping = true
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            let response = generateResponse(for: trimmed)
            await MainActor.run {
                isTyping = false
                messages.append(ChatMessage(role: .assistant, text: response))
                HapticManager.success()
            }
        }
    }

    private func generateResponse(for query: String) -> String {
        let lowercased = query.lowercased()

        let enhanced = AssistantEngine.respond(
            to: query,
            inventory: inventoryItems,
            deals: deals,
            stores: stores,
            receipts: receipts,
            listItems: listItems,
            wasteEntries: wasteEntries,
            mealPlans: mealPlans
        )
        if !enhanced.isEmpty { return enhanced }

        if lowercased.contains("low") || lowercased.contains("running") {
            let lowItems = inventoryItems.filter { $0.isLowStock }
            if lowItems.isEmpty {
                return "Everything looks well stocked! No items are below their minimum quantity."
            }
            let names = lowItems.prefix(5).map { item -> String in
                if let days = item.daysUntilRunOut {
                    return "• \(item.name) — est. \(days) days left"
                }
                return "• \(item.name) — below minimum"
            }.joined(separator: "\n")
            return "Here are items running low:\n\n\(names)"
        }

        if lowercased.contains("expir") {
            let expiring = inventoryItems.filter { $0.isExpiringSoon || $0.isExpired }
            if expiring.isEmpty {
                return "Nothing is expiring in the next week. You're doing great reducing waste!"
            }
            let names = expiring.map { "• \($0.name) — \($0.expirationDate?.formatted(date: .abbreviated, time: .omitted) ?? "unknown")" }.joined(separator: "\n")
            return "Items expiring soon:\n\n\(names)\n\nWould you like recipe suggestions using these ingredients?"
        }

        if lowercased.contains("shopping list") || lowercased.contains("generate") {
            let count = inventoryItems.filter { $0.isLowStock }.count
            if count == 0 {
                return "Your inventory looks good — nothing needs to be added to the list right now."
            }
            return "You have \(count) item\(count == 1 ? "" : "s") that may need restocking. Check the Lists tab to review."
        }

        if lowercased.contains("compare") || (lowercased.contains("price") && lowercased.contains("for")) {
            let item = extractCompareItem(from: query)
            itemSearchQuery = item
            showItemSearch = true
            if item.isEmpty {
                return "Opening price comparison search…"
            }
            return "Opening price comparison for “\(item)” across Amazon, Walmart, and nearby stores."
        }

        if lowercased.contains("sale") || lowercased.contains("deal") {
            let activeDeals = deals.filter(\.isActive)
            if activeDeals.isEmpty {
                return "No active deals yet. Add your favorite stores in the Deals tab — each business gets its own weekly ad and inventory-matched picks."
            }
            let lines = activeDeals.prefix(5).map { deal in
                if deal.source == .weeklyAd {
                    return "• \(deal.storeName) weekly ad — open in Deals tab"
                }
                return "• \(deal.productName) at \(deal.storeName) — save \(Formatters.currencyString(deal.savings))"
            }.joined(separator: "\n")
            return "Active deals:\n\n\(lines)"
        }

        if lowercased.contains("detergent") || lowercased.contains("how much") || lowercased.contains("how many") {
            if let item = inventoryItems.first(where: { lowercased.contains($0.name.lowercased()) }) {
                return "You have \(item.quantity.formatted()) \(item.quantityUnit) of \(item.name). \(item.isLowStock ? "You're running low — I'd suggest adding it to your list." : "Stock level looks healthy.")"
            }
            return "I couldn't find a specific match. You currently track \(inventoryItems.count) items across \(Set(inventoryItems.map(\.category)).count) categories."
        }

        if lowercased.contains("saving") || lowercased.contains("spent") || lowercased.contains("budget") {
            let savings = deals.filter(\.isActive).reduce(0) { $0 + $1.savings }
            let monthlySpent = receipts.reduce(0) { $0 + $1.total }
            if savings == 0 && monthlySpent == 0 {
                return "Add stores and scan receipts to start tracking savings and spending."
            }
            return "Active deal savings: \(Formatters.currencyString(savings)). Receipt total tracked: \(Formatters.currencyString(monthlySpent))."
        }

        return "I can help with inventory, shopping lists, deals, expiration tracking, and spending insights. Try asking \"What's running low?\" or \"Compare prices for milk\""
    }

    private func extractCompareItem(from query: String) -> String {
        let lower = query.lowercased()
        for prefix in ["compare prices for ", "compare price for ", "price of ", "prices for ", "find "] {
            if lower.hasPrefix(prefix) {
                return String(query.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if let range = lower.range(of: " for ") {
            return String(query[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
}

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    let text: String
    let timestamp = Date()
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            Text(message.text)
                .font(.shelfBody)
                .foregroundStyle(message.role == .user ? .white : ShelfTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if message.role == .user {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(ShelfTheme.accent)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }
}

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(ShelfTheme.textTertiary)
                        .frame(width: 6, height: 6)
                        .opacity(animating ? 0.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer()
        }
        .onAppear { animating = true }
    }
}

#Preview {
    AssistantView()
        .modelContainer(PreviewModelContainer.shared)
}
