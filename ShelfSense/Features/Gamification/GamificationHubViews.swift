//
//  GamificationHubViews.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

struct DailyQuestsView: View {
    @State private var questStore = QuestStore.shared
    @Environment(PlayerLevelStore.self) private var playerStore

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Quests")
                            .font(.shelfHeadline)
                        Text("\(questStore.completedCount)/\(questStore.allQuests.count) complete · \(questStore.streakDays)-day streak")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }
                    Spacer()
                    if questStore.allQuests.contains(where: { $0.isComplete && !$0.claimed }) {
                        Button("Claim All") { questStore.claimAllAvailable() }
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.copperLight)
                    }
                }
            }

            ForEach(questStore.allQuests) { quest in
                QuestRow(quest: quest) {
                    questStore.claim(quest.id)
                }
            }

            Section("Rank Perks") {
                ForEach(RankPerksStore.all) { perk in
                    HStack(spacing: 12) {
                        Image(systemName: perk.icon)
                            .foregroundStyle(playerStore.level >= perk.unlockLevel ? ShelfTheme.copperLight : ShelfTheme.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(perk.title).font(.shelfSubheadline)
                            Text(perk.description).font(.shelfCaption).foregroundStyle(ShelfTheme.textTertiary)
                        }
                        Spacer()
                        Text("Lv \(perk.unlockLevel)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(playerStore.level >= perk.unlockLevel ? ShelfTheme.success : ShelfTheme.textTertiary)
                    }
                }
            }
        }
        .navigationTitle("Quests & Perks")
        .onAppear { questStore.refreshIfNeeded() }
    }
}

private struct QuestRow: View {
    let quest: QuestProgress
    let onClaim: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: quest.definition.icon)
                .font(.title3)
                .foregroundStyle(quest.isComplete ? ShelfTheme.success : ShelfTheme.copper)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(quest.definition.title).font(.shelfSubheadline)
                Text(quest.definition.subtitle).font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                ProgressView(value: quest.progress).tint(ShelfTheme.copper)
                Text("+\(quest.definition.xpReward) XP")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ShelfTheme.copperGlow)
            }

            if quest.isComplete && !quest.claimed {
                Button("Claim", action: onClaim)
                    .font(.shelfCaption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ShelfTheme.copperGradient.opacity(0.4))
                    .foregroundStyle(ShelfTheme.copperLight)
                    .clipShape(Capsule())
            } else if quest.claimed {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(ShelfTheme.success)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HouseholdLeaderboardView: View {
    @Query private var members: [HouseholdMember]
    @Query private var listItems: [ShoppingListItem]
    @Environment(PlayerLevelStore.self) private var playerStore

    private var entries: [LeaderboardEntry] {
        HouseholdLeaderboardService.entries(
            members: members,
            listItems: listItems,
            playerXP: playerStore.totalXP,
            playerSavings: playerStore.lifetimeSavings
        )
    }

    var body: some View {
        List {
            Section {
                Text("Weekly household savings competition — complete list items and save to climb the board.")
                    .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
            }

            ForEach(entries) { entry in
                HStack(spacing: 12) {
                    Text("#\(entry.rank)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(entry.rank == 1 ? ShelfTheme.copperGlow : ShelfTheme.textTertiary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name).font(.shelfHeadline)
                        Text("\(entry.completedItems) items · \(Formatters.currencyString(entry.weeklySavings)) saved")
                            .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                    }

                    Spacer()

                    Text("\(entry.xp) XP")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.copperLight)
                }
            }
        }
        .navigationTitle("Leaderboard")
    }
}

struct ExpirationRouletteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var inventory: [InventoryItem]

    @State private var result: ExpirationRouletteResult?
    @State private var isSpinning = false
    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 24) {
            CopperGradientText(text: "Expiration Roulette", font: .shelfTitle)

            Text("Spin to pick expiring items and get a recipe suggestion before they go bad.")
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let result {
                GlassCard(glow: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Use these soon:").font(.shelfHeadline)
                        ForEach(result.expiringItems, id: \.id) { item in
                            Label(item.name, systemImage: "clock.badge.exclamationmark")
                                .font(.shelfSubheadline)
                        }
                        if let recipe = result.suggestedRecipe {
                            Divider()
                            Text("Try: \(recipe.name)").font(.shelfHeadline).foregroundStyle(ShelfTheme.copperLight)
                            Text("\(recipe.prepMinutes) min · \(recipe.servings) servings")
                                .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                            NavigationLink { RecipeDetailView(recipe: recipe) } label: {
                                Text("View Recipe").font(.shelfCaption).foregroundStyle(ShelfTheme.copper)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            Button {
                spin()
            } label: {
                Text(isSpinning ? "Spinning…" : "Spin!")
                    .font(.shelfHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ShelfTheme.copperGradient.opacity(0.45))
                    .foregroundStyle(ShelfTheme.copperLight)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isSpinning || inventory.filter({ $0.isExpiringSoon || $0.isExpired }).isEmpty)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
        .background(ShelfGradientBackground())
        .navigationTitle("Expiration Roulette")
        .overlay {
            ConfettiView(isActive: $showConfetti)
        }
    }

    private func spin() {
        isSpinning = true
        HapticManager.mediumImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            result = ExpirationRouletteService.spin(from: inventory)
            if let result {
                PlayerLevelStore.shared.recordActionXP(result.xpBonus, reason: "Expiration roulette")
                showConfetti = true
                SpinWheelCelebration.playWin()
            }
            isSpinning = false
        }
    }
}

struct ShareSavingsCardView: View {
    @Environment(PlayerLevelStore.self) private var playerStore
    @State private var renderedImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                savingsCard
                    .padding()
                    .background(ShelfTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(ShelfTheme.copper.opacity(0.4), lineWidth: 1)
                    }
                    .padding()

                if let renderedImage {
                    ShareLink(item: Image(uiImage: renderedImage), preview: SharePreview("My \(AppBrand.name) Savings", image: Image(uiImage: renderedImage))) {
                        Label("Share Savings Card", systemImage: "square.and.arrow.up")
                            .font(.shelfHeadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ShelfTheme.copperGradient.opacity(0.35))
                            .foregroundStyle(ShelfTheme.copperLight)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(ShelfGradientBackground())
        .navigationTitle("Share Savings")
        .onAppear { renderCard() }
    }

    private var savingsCard: some View {
        VStack(spacing: 16) {
            Image(systemName: playerStore.rank.icon)
                .font(.system(size: 48))
                .foregroundStyle(ShelfTheme.heroGradient)

            Text("Level \(playerStore.level)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(ShelfTheme.copperLight)

            Text(playerStore.rank.title)
                .font(.shelfHeadline)

            Text(Formatters.currencyString(playerStore.lifetimeSavings))
                .font(.shelfStat)
                .foregroundStyle(ShelfTheme.success)

            Text("lifetime saved with \(AppBrand.name)")
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    @MainActor
    private func renderCard() {
        let renderer = ImageRenderer(content: savingsCard.frame(width: 320).background(ShelfTheme.backgroundPrimary))
        renderer.scale = UIScreen.main.scale
        renderedImage = renderer.uiImage
    }
}

struct RecipeURLImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var urlText = ""
    @State private var status = ""
    @State private var isLoading = false

    var body: some View {
        Form {
            Section {
                TextField("https://…", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            } header: {
                Text("Recipe URL")
            } footer: {
                Text("Paste a recipe link — we'll extract ingredients and add them to your list.")
            }

            Section {
                Button(isLoading ? "Importing…" : "Import Ingredients") {
                    Task { await importRecipe() }
                }
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }

            if !status.isEmpty {
                Section { Text(status).font(.shelfCaption) }
            }
        }
        .navigationTitle("Import Recipe")
    }

    private func importRecipe() async {
        isLoading = true
        status = await AppDataBridge.addRecipeIngredients(from: urlText)
        isLoading = false
        HapticManager.success()
    }
}

struct SiriShortcutsGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Say these to Siri — or find them in the Shortcuts app under \(AppBrand.name).")
                    .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
            }

            Group {
                shortcutRow("Add milk to \(AppBrand.name)", icon: "cart.badge.plus")
                shortcutRow("What's on my \(AppBrand.name) list", icon: "list.bullet")
                shortcutRow("Plan tacos in \(AppBrand.name)", icon: "calendar")
                shortcutRow("What's expiring in \(AppBrand.name)", icon: "clock.badge.exclamationmark")
                shortcutRow("How much have I saved in \(AppBrand.name)", icon: "star.fill")
                shortcutRow("Import recipe to \(AppBrand.name)", icon: "link")
            }
        }
        .navigationTitle("Siri & Shortcuts")
    }

    private func shortcutRow(_ phrase: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(ShelfTheme.copper)
            Text("\"\(phrase)\"")
                .font(.shelfSubheadline)
        }
    }
}

struct CouponMatcherView: View {
    @Query private var coupons: [Coupon]
    @Query private var listItems: [ShoppingListItem]

    private var matches: [CouponMatch] {
        CouponMatchService.matches(coupons: coupons.filter(\.isActive), listItems: listItems)
    }

    var body: some View {
        List {
            if matches.isEmpty {
                ContentUnavailableView("No matches", systemImage: "ticket", description: Text("Add coupons and list items with matching names"))
            } else {
                ForEach(matches) { match in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.couponTitle).font(.shelfSubheadline)
                        Text("Use on: \(match.matchedItemName)")
                            .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                        if let store = match.storeName {
                            Text(store).font(.system(size: 10)).foregroundStyle(ShelfTheme.copper)
                        }
                        Text("Est. save \(Formatters.currencyString(match.estimatedSavings))")
                            .font(.shelfCaption).foregroundStyle(ShelfTheme.success)
                    }
                }
            }
        }
        .navigationTitle("Coupon Matcher")
    }
}

struct HomeScreenWidgetsGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Long-press your Home Screen → tap + → search \(AppBrand.name) to add widgets.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textSecondary)
            }

            Section("Available Widgets") {
                widgetRow("Shopping List", icon: "cart.fill", sizes: "Small · Medium")
                widgetRow("Level & Savings", icon: "star.fill", sizes: "Small")
                widgetRow("Expiring Soon", icon: "clock.badge.exclamationmark", sizes: "Small")
                widgetRow("Daily Quests", icon: "flag.checkered", sizes: "Medium")
                widgetRow(AppBrand.dashboardWidgetTitle, icon: "square.grid.2x2.fill", sizes: "Large")
            }

            Section {
                Text("Widgets update when you use the app. Open \(AppBrand.name) after adding list items or scanning receipts for the latest data.")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.textTertiary)
            }
        }
        .navigationTitle("Home Screen Widgets")
    }

    private func widgetRow(_ title: String, icon: String, sizes: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(ShelfTheme.copperLight)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.shelfSubheadline)
                Text(sizes).font(.shelfCaption).foregroundStyle(ShelfTheme.textTertiary)
            }
        }
    }
}

struct CheapestCartView: View {
    @Query private var listItems: [ShoppingListItem]
    @Query private var deals: [Deal]
    @Query private var stores: [Store]

    private var plans: [StoreTripPlan] {
        TripOptimizerService.optimize(listItems: listItems, deals: deals, stores: stores)
    }

    var body: some View {
        List {
            Section {
                Text("Cheapest way to buy everything on your active list.")
                    .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
            }

            if plans.isEmpty {
                ContentUnavailableView("No plan", systemImage: "cart", description: Text("Add list items and stores"))
            } else {
                ForEach(plans.prefix(3)) { plan in
                    Section(plan.storeName) {
                        LabeledContent("Items", value: "\(plan.itemCount)")
                        LabeledContent("Est. total", value: Formatters.currencyString(plan.estimatedTotal))
                        if plan.dealSavings > 0 {
                            LabeledContent("Deal savings", value: Formatters.currencyString(plan.dealSavings))
                        }
                    }
                }

                if plans.count > 1 {
                    Section("Trip + Gas") {
                        let extraStores = plans.count - 1
                        let miles = Double(extraStores) * 5
                        let gasCost = VehicleSettingsStore.tripFuelCost(miles: miles, pricePerGallon: GasPriceService.regionalAverage)
                        LabeledContent("Extra gas (~\(Int(miles)) mi)", value: Formatters.currencyString(gasCost))
                    }
                }
            }
        }
        .navigationTitle("Cheapest Cart")
    }
}
