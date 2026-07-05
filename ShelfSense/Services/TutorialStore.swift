//
//  TutorialStore.swift
//  ShelfSense
//

import Foundation
import Observation

struct TutorialStep: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let icon: String
    let accent: String
    let tab: AppTab?
}

@Observable
@MainActor
final class TutorialStore {
    static let shared = TutorialStore()

    private static let completedKey = "tutorialCompleted"

    var isPresented = false
    var currentStep = 0

    var hasCompletedTutorial: Bool {
        get { UserDefaults.standard.bool(forKey: Self.completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.completedKey) }
    }

    static let steps: [TutorialStep] = [
        TutorialStep(
            id: 0,
            title: "Welcome to \(AppBrand.name)",
            subtitle: "Your smart shopping companion — search, save, and level up as you spend smarter.",
            icon: "sparkles",
            accent: "Start tour",
            tab: nil
        ),
        TutorialStep(
            id: 1,
            title: "Search & List",
            subtitle: "Compare prices across stores, then tap + to add items to your shopping list instantly.",
            icon: "cart.circle.fill",
            accent: "Search tab",
            tab: .search
        ),
        TutorialStep(
            id: 2,
            title: "Scan Everything",
            subtitle: "Scan barcodes for nutrition info or photograph receipts — we'll read items and track savings.",
            icon: "barcode.viewfinder",
            accent: "More → Scan",
            tab: .more
        ),
        TutorialStep(
            id: 3,
            title: "Deals & Near Me",
            subtitle: "Pull store deals automatically and get GPS alerts when you're near saved stores.",
            icon: "location.fill",
            accent: "Near Me tab",
            tab: .gps
        ),
        TutorialStep(
            id: 4,
            title: "Level Up & Save",
            subtitle: "Every dollar you save earns XP. Level up for arcade-style rank titles and confetti celebrations!",
            icon: "star.fill",
            accent: "Keep saving",
            tab: nil
        ),
        TutorialStep(
            id: 5,
            title: "Siri Voice Commands",
            subtitle: "Say \"Add milk to \(AppBrand.name)\" or \"What's on my list\" — voice ordering and meal planning hands-free.",
            icon: "mic.badge.plus",
            accent: "Try Siri",
            tab: nil
        ),
        TutorialStep(
            id: 6,
            title: "You're Ready!",
            subtitle: "Daily quests, spin the wheel, coupon matcher, and leaderboard — explore Home widgets and level up as you save.",
            icon: "checkmark.seal.fill",
            accent: "Let's go",
            tab: .dashboard
        )
    ]

    func present() {
        currentStep = 0
        isPresented = true
    }

    func complete() {
        hasCompletedTutorial = true
        isPresented = false
        currentStep = 0
    }

    func next() {
        if currentStep < Self.steps.count - 1 {
            currentStep += 1
        } else {
            complete()
        }
    }

    func previous() {
        currentStep = max(currentStep - 1, 0)
    }
}
