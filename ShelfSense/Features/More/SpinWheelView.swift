//
//  SpinWheelView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData

enum SpinWheelMode: String, CaseIterable, Identifiable {
    case recipe
    case fastFood
    case pantry
    case deals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recipe: "Recipe"
        case .fastFood: "Near Me"
        case .pantry: "Pantry"
        case .deals: "Deals"
        }
    }
}

private struct WheelSegment: Identifiable {
    let id: Int
    let title: String
    let shortTitle: String
    let fastFoodOption: NearbyFastFoodOption?
}

struct SpinWheelView: View {
    @Environment(LocationManager.self) private var locationManager
    @Query private var inventory: [InventoryItem]
    @Query private var deals: [Deal]

    @State private var mode: SpinWheelMode = .recipe
    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var selectedItem: String?
    @State private var selectedRecipe: Recipe?
    @State private var selectedFastFood: NearbyFastFoodOption?
    @State private var winningIndex: Int?
    @State private var spinTask: Task<Void, Never>?
    @State private var tickTask: Task<Void, Never>?
    @State private var nearbyFastFood: [NearbyFastFoodOption] = []
    @State private var isLoadingNearby = false
    @State private var showConfetti = false
    @State private var idleWobble = false
    @State private var resultScale: CGFloat = 0.85
    @State private var wheelGlow = false
    @State private var doubleOrNothing = false
    @State private var gambledAway = false

    private let recipes = [
        "Chicken stir-fry", "Pasta primavera", "Tacos", "Salmon bowls",
        "Veggie curry", "Sheet-pan fajitas", "Greek salad wraps", "Tomato soup + grilled cheese",
        "Burrito bowls", "Shrimp fried rice", "Caprese panini", "Chili"
    ]

    private var segments: [WheelSegment] {
        switch mode {
        case .recipe:
            return recipes.prefix(8).enumerated().map { index, name in
                WheelSegment(id: index, title: name, shortTitle: abbreviate(name), fastFoodOption: nil)
            }
        case .fastFood:
            let source = nearbyFastFood.isEmpty
                ? NearbyFastFoodService.fallbackOptions()
                : nearbyFastFood
            return source.prefix(8).enumerated().map { index, option in
                WheelSegment(
                    id: index,
                    title: option.displayName,
                    shortTitle: abbreviate(option.displayName),
                    fastFoodOption: option
                )
            }
        case .pantry:
            let names = Recipe.pantryMatches(inventoryNames: inventory.map(\.name)).map(\.name)
            let source = names.isEmpty ? recipes : names
            return source.prefix(8).enumerated().map { index, name in
                WheelSegment(id: index, title: name, shortTitle: abbreviate(name), fastFoodOption: nil)
            }
        case .deals:
            let active = deals.filter(\.isActive).sorted { $0.savings > $1.savings }
            let titles = active.isEmpty
                ? ["No deals — refresh Deals tab"]
                : active.map { "\($0.productName) · \(Formatters.currencyString($0.salePrice))" }
            return titles.prefix(8).enumerated().map { index, name in
                WheelSegment(id: index, title: name, shortTitle: abbreviate(name), fastFoodOption: nil)
            }
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    Picker("Mode", selection: $mode) {
                        ForEach(SpinWheelMode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isSpinning)
                    .onChange(of: mode) { _, newMode in
                        resetSelection()
                        winningIndex = nil
                        if newMode == .fastFood {
                            Task { await loadNearbyFastFood() }
                        }
                    }

                    if mode == .fastFood {
                        nearbyStatusBanner
                    }

                    wheelSection

                    segmentLegend

                    spinButton

                    if RankPerksStore.isUnlocked("spin-double", level: PlayerLevelStore.shared.level) {
                        Toggle(isOn: $doubleOrNothing) {
                            Label("Double or Nothing (+40 XP gamble)", systemImage: "dice.fill")
                                .font(.shelfCaption)
                        }
                        .tint(ShelfTheme.copper)
                    }

                    if let selectedItem {
                        resultCard(selectedItem)
                    }
                }
                .padding()
            }

            ConfettiView(isActive: $showConfetti)
        }
        .background(ShelfGradientBackground())
        .navigationTitle("Meal Wheel")
        .onAppear {
            SpinWheelCelebration.prepare()
            idleWobble = true
            wheelGlow = true
            if mode == .fastFood {
                locationManager.startForegroundLocation()
                Task { await loadNearbyFastFood() }
            }
        }
        .onDisappear {
            spinTask?.cancel()
            tickTask?.cancel()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ShelfInterestBadge(text: "Pick for me", icon: "arrow.trianglehead.clockwise")
            CopperGradientText(text: "Spin the wheel", font: .shelfTitle)
            Text(mode == .fastFood
                 ? "Nearby fast food fills the wheel — arrow lands on your pick."
                 : "Can't decide? Let \(AppBrand.name) choose your next meal.")
                .font(.shelfCaption)
                .foregroundStyle(ShelfTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .shelfAppear()
    }

    private var nearbyStatusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: isLoadingNearby ? "location.circle" : "location.fill")
                .foregroundStyle(ShelfTheme.copperLight)
                .symbolEffect(.pulse, isActive: isLoadingNearby)

            if isLoadingNearby {
                Text("Finding fast food near you…")
            } else if !nearbyFastFood.isEmpty {
                Text("\(min(nearbyFastFood.count, 8)) nearby spots on wheel")
            } else {
                Text("Using popular picks — enable location for nearby spots")
            }
        }
        .font(.shelfCaption)
        .foregroundStyle(ShelfTheme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ShelfTheme.backgroundSecondary.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var wheelSection: some View {
        ZStack {
            Circle()
                .fill(ShelfTheme.copper.opacity(wheelGlow ? 0.18 : 0.08))
                .frame(width: 310, height: 310)
                .blur(radius: 20)
                .scaleEffect(wheelGlow ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: wheelGlow)

            ZStack {
                outerRing

                ZStack {
                    wheelSlices
                    wheelLabels
                    winningHighlight
                }
                .rotationEffect(.degrees(rotation))
                .animation(isSpinning ? .timingCurve(0.12, 0.88, 0.15, 1.0, duration: 3.8) : .default, value: rotation)
                .shadow(color: ShelfTheme.copper.opacity(0.35), radius: isSpinning ? 20 : 10, y: 6)

                centerHub

                landingPointer
            }
            .scaleEffect(idleWobble && !isSpinning ? 1.012 : 1.0)
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: idleWobble)
        }
        .frame(height: 320)
        .padding(.vertical, 8)
    }

    private var segmentLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    Text(segment.title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(winningIndex == index ? ShelfTheme.backgroundPrimary : ShelfTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(winningIndex == index ? ShelfTheme.copperLight : ShelfTheme.backgroundSecondary)
                        }
                        .overlay {
                            if winningIndex == index {
                                Capsule().strokeBorder(ShelfTheme.copperGlow, lineWidth: 1.5)
                            }
                        }
                }
            }
        }
    }

    private var outerRing: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        ShelfTheme.copperLight.opacity(0.9),
                        ShelfTheme.copper.opacity(0.2),
                        ShelfTheme.copperGlow.opacity(0.75),
                        ShelfTheme.copper.opacity(0.2),
                        ShelfTheme.copperLight.opacity(0.9)
                    ],
                    center: .center
                ),
                lineWidth: 5
            )
            .frame(width: 288, height: 288)
    }

    private var centerHub: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [ShelfTheme.backgroundPrimary, ShelfTheme.backgroundSecondary],
                    center: .center,
                    startRadius: 4,
                    endRadius: 38
                )
            )
            .frame(width: 72, height: 72)
            .overlay {
                Circle().strokeBorder(ShelfTheme.copper.opacity(0.5), lineWidth: 2)
            }
            .overlay {
                Image(systemName: mode == .recipe ? "frying.pan.fill" : "takeoutbag.and.cup.and.straw.fill")
                    .font(.title3)
                    .foregroundStyle(ShelfTheme.heroGradient)
                    .symbolEffect(.bounce, value: isSpinning)
            }
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }

    private var landingPointer: some View {
        VStack(spacing: 0) {
            TrianglePointer()
                .fill(
                    LinearGradient(
                        colors: [ShelfTheme.copperGlow, ShelfTheme.copperLight, ShelfTheme.copper],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 26, height: 20)
                .shadow(color: ShelfTheme.copperGlow.opacity(0.6), radius: 6, y: 2)

            Rectangle()
                .fill(ShelfTheme.copperLight.opacity(0.85))
                .frame(width: 3, height: 14)
        }
        .offset(y: -148)
        .zIndex(10)
    }

    private var wheelSlices: some View {
        let count = max(segments.count, 1)
        let slice = 360.0 / Double(count)

        return ZStack {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, _ in
                WheelSlice(
                    startAngle: .degrees(Double(index) * slice),
                    endAngle: .degrees(Double(index + 1) * slice),
                    color: sliceColor(for: index)
                )

                WheelSliceDivider(angle: Double(index) * slice)
            }
        }
        .frame(width: 268, height: 268)
        .clipShape(Circle())
    }

    private var wheelLabels: some View {
        let count = max(segments.count, 1)
        let slice = 360.0 / Double(count)

        return ZStack {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                WheelLabel(
                    text: segment.shortTitle,
                    midAngle: Double(index) * slice + slice / 2,
                    radius: 88
                )
            }
        }
        .frame(width: 268, height: 268)
    }

    @ViewBuilder
    private var winningHighlight: some View {
        if let winningIndex, !isSpinning {
            let count = max(segments.count, 1)
            let slice = 360.0 / Double(count)
            WheelSlice(
                startAngle: .degrees(Double(winningIndex) * slice),
                endAngle: .degrees(Double(winningIndex + 1) * slice),
                color: ShelfTheme.copperGlow.opacity(0.35)
            )
            .frame(width: 268, height: 268)
            .overlay {
                WheelSliceBorder(
                    startAngle: .degrees(Double(winningIndex) * slice),
                    endAngle: .degrees(Double(winningIndex + 1) * slice)
                )
                .stroke(ShelfTheme.copperLight, lineWidth: 3)
                .frame(width: 268, height: 268)
            }
            .transition(.opacity)
        }
    }

    private var spinButton: some View {
        Button { spin() } label: {
            Label(isSpinning ? "Spinning…" : "Spin!", systemImage: "arrow.trianglehead.clockwise")
                .font(.shelfHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ShelfTheme.copperGradient.opacity(isSpinning ? 0.2 : 0.38))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(ShelfTheme.copperLight.opacity(0.35), lineWidth: 1)
                        }
                }
                .foregroundStyle(ShelfTheme.copperLight)
        }
        .disabled(isSpinning || segments.isEmpty)
        .buttonStyle(ShelfPressButtonStyle())
    }

    private func resultCard(_ item: String) -> some View {
        GlassCard(glow: true) {
            VStack(spacing: 10) {
                Label("Arrow landed on", systemImage: "arrow.down.circle.fill")
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.copperLight)

                Text(item)
                    .font(.shelfTitle)
                    .foregroundStyle(ShelfTheme.textPrimary)
                    .multilineTextAlignment(.center)

                if let selectedFastFood, let distance = selectedFastFood.distanceLabel {
                    Label(distance, systemImage: "location.fill")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.copperLight)
                }

                if let address = selectedFastFood?.address, !address.isEmpty {
                    Text(address)
                        .font(.system(size: 10))
                        .foregroundStyle(ShelfTheme.textTertiary)
                        .multilineTextAlignment(.center)
                }

                if let selectedRecipe {
                    NavigationLink {
                        RecipeDetailView(recipe: selectedRecipe)
                    } label: {
                        Label(
                            selectedRecipe.isFastFood ? "View pick" : "View recipe & add ingredients",
                            systemImage: "arrow.right.circle.fill"
                        )
                        .font(.shelfSubheadline)
                        .foregroundStyle(ShelfTheme.copperLight)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scaleEffect(resultScale)
    }

    private func sliceColor(for index: Int) -> Color {
        let palette: [Color] = [
            ShelfTheme.copper.opacity(0.45),
            Color(red: 0.16, green: 0.12, blue: 0.09),
            ShelfTheme.copper.opacity(0.30),
            ShelfTheme.backgroundTertiary,
            ShelfTheme.copperLight.opacity(0.25),
            Color(red: 0.20, green: 0.15, blue: 0.11)
        ]
        return palette[index % palette.count]
    }

    private func abbreviate(_ name: String) -> String {
        let map: [String: String] = [
            "McDonald's": "McD", "Chick-fil-A": "CFA", "In-N-Out": "In-N-Out",
            "Panda Express": "Panda", "Five Guys": "5 Guys", "Shake Shack": "Shack",
            "Taco Bell": "Taco Bell", "Starbucks": "Sbucks", "Chipotle": "Chipotle",
            "Panera": "Panera", "Subway": "Subway", "Wendy's": "Wendy's"
        ]
        if let short = map[name] { return short }
        if name.count <= 10 { return name }
        return String(name.prefix(9)) + "…"
    }

    private func resetSelection() {
        selectedItem = nil
        selectedRecipe = nil
        selectedFastFood = nil
        showConfetti = false
        resultScale = 0.85
    }

    private func loadNearbyFastFood() async {
        isLoadingNearby = true
        locationManager.startForegroundLocation()
        if locationManager.currentLocation == nil {
            try? await Task.sleep(for: .milliseconds(900))
        }
        nearbyFastFood = await NearbyFastFoodService.nearbyOptions(near: locationManager.currentLocation?.coordinate)
        isLoadingNearby = false
    }

    private func spin() {
        guard !isSpinning, !segments.isEmpty else { return }

        isSpinning = true
        resetSelection()
        winningIndex = nil
        SpinWheelCelebration.playSpinStart()
        HapticManager.lightImpact()

        let count = segments.count
        let slice = 360.0 / Double(count)
        let targetIndex = Int.random(in: 0..<count)
        let sliceCenter = Double(targetIndex) * slice + slice / 2
        let currentMod = rotation.truncatingRemainder(dividingBy: 360)
        var delta = (360 - sliceCenter - currentMod).truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        let extraSpins = Double.random(in: 5...7) * 360
        let finalRotation = rotation + extraSpins + delta

        tickTask?.cancel()
        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(340))
                guard !Task.isCancelled else { break }
                await MainActor.run { SpinWheelCelebration.playTick() }
            }
        }

        withAnimation(.timingCurve(0.12, 0.88, 0.15, 1.0, duration: 3.8)) {
            rotation = finalRotation
        }

        spinTask?.cancel()
        spinTask = Task {
            try? await Task.sleep(for: .seconds(3.85))
            await MainActor.run {
                tickTask?.cancel()
                let index = targetIndex
                let segment = segments[index]

                winningIndex = index
                selectedItem = segment.title
                selectedRecipe = Recipe.find(byName: segment.title)
                selectedFastFood = segment.fastFoodOption
                isSpinning = false
                showConfetti = true
                SpinWheelCelebration.playWin()
                HapticManager.success()

                if doubleOrNothing, Bool.random() {
                    PlayerLevelStore.shared.recordActionXP(40, reason: "Double or nothing!")
                }

                withAnimation(ShelfMotion.spring) {
                    resultScale = 1.0
                }
            }
        }
    }
}

private struct WheelLabel: View {
    let text: String
    let midAngle: Double
    let radius: Double

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(.black.opacity(0.55)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
            .rotationEffect(.degrees(midAngle))
            .offset(y: -radius)
            .rotationEffect(.degrees(-midAngle))
    }
}

private struct WheelSliceBorder: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle - .degrees(90),
            endAngle: endAngle - .degrees(90),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: radius * 0.28,
            startAngle: endAngle - .degrees(90),
            endAngle: startAngle - .degrees(90),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

private struct WheelSliceDivider: View {
    let angle: Double

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            let radians = (angle - 90) * .pi / 180
            Path { path in
                path.move(to: center)
                path.addLine(to: CGPoint(
                    x: center.x + radius * cos(radians),
                    y: center.y + radius * sin(radians)
                ))
            }
            .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
    }
}

private struct WheelSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: min(geo.size.width, geo.size.height) / 2,
                    startAngle: startAngle - .degrees(90),
                    endAngle: endAngle - .degrees(90),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.95), color.opacity(0.55)],
                    center: .center,
                    startRadius: 10,
                    endRadius: min(geo.size.width, geo.size.height) / 2
                )
            )
        }
    }
}

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    NavigationStack {
        SpinWheelView()
            .environment(LocationManager.shared)
    }
}
