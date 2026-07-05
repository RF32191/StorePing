//
//  TutorialWalkthroughView.swift
//  ShelfSense
//

import SwiftUI

struct TutorialWalkthroughView: View {
    @Bindable var tutorialStore: TutorialStore
    var onJumpToTab: (AppTab) -> Void

    private var step: TutorialStep {
        TutorialStore.steps[tutorialStore.currentStep]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        tutorialStore.complete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(ShelfTheme.textTertiary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(ShelfTheme.copperGradient.opacity(0.25))
                            .frame(width: 110, height: 110)
                            .blur(radius: 8)

                        Image(systemName: step.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(ShelfTheme.heroGradient)
                            .symbolEffect(.bounce, value: tutorialStore.currentStep)
                    }

                    CopperGradientText(text: step.title, font: .shelfTitle)
                        .multilineTextAlignment(.center)

                    Text(step.subtitle)
                        .font(.shelfBody)
                        .foregroundStyle(ShelfTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    HStack(spacing: 6) {
                        ForEach(TutorialStore.steps.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == tutorialStore.currentStep ? ShelfTheme.copperLight : ShelfTheme.textTertiary.opacity(0.4))
                                .frame(width: index == tutorialStore.currentStep ? 22 : 7, height: 7)
                                .animation(ShelfMotion.spring, value: tutorialStore.currentStep)
                        }
                    }
                    .padding(.top, 4)

                    HStack(spacing: 12) {
                        if tutorialStore.currentStep > 0 {
                            Button("Back") {
                                tutorialStore.previous()
                            }
                            .font(.shelfSubheadline)
                            .foregroundStyle(ShelfTheme.textSecondary)
                        }

                        Button {
                            if let tab = step.tab {
                                onJumpToTab(tab)
                            }
                            tutorialStore.next()
                        } label: {
                            Text(tutorialStore.currentStep == TutorialStore.steps.count - 1 ? "Finish" : step.accent)
                                .font(.shelfHeadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(ShelfTheme.copperGradient.opacity(0.45))
                                .foregroundStyle(ShelfTheme.copperLight)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(ShelfPressButtonStyle())
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(ShelfTheme.backgroundSecondary)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(ShelfTheme.copper.opacity(0.35), lineWidth: 1)
                        }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

struct AppTopChrome: View {
    @Bindable var playerStore: PlayerLevelStore
    @Bindable var tutorialStore: TutorialStore
    var onShowProfile: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                tutorialStore.present()
                HapticManager.lightImpact()
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ShelfTheme.copperLight)
                    .shadow(color: ShelfTheme.copper.opacity(0.4), radius: 4)
            }
            .accessibilityLabel("Tutorial")

            Button(action: onShowProfile) {
                HStack(spacing: 6) {
                    Image(systemName: playerStore.rank.icon)
                        .font(.caption)
                    Text("Lv \(playerStore.level)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(ShelfTheme.backgroundPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(ShelfTheme.copperGradient)
                        .shadow(color: ShelfTheme.copper.opacity(0.45), radius: 6, y: 2)
                }
            }
            .accessibilityLabel("Level \(playerStore.level)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(ShelfTheme.backgroundPrimary.opacity(0.88))
                .overlay {
                    Capsule()
                        .strokeBorder(ShelfTheme.copper.opacity(0.25), lineWidth: 0.75)
                }
        }
    }
}

struct LevelUpOverlayView: View {
    let event: LevelUpEvent
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var pulse = false
    @State private var confetti = true

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            ConfettiView(isActive: $confetti)

            VStack(spacing: 18) {
                Text("LEVEL UP!")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(ShelfTheme.copperGlow)
                    .tracking(3)

                ZStack {
                    Circle()
                        .stroke(ShelfTheme.copperLight.opacity(pulse ? 0.8 : 0.2), lineWidth: 4)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulse ? 1.08 : 0.95)

                    Circle()
                        .fill(ShelfTheme.copperGradient.opacity(0.35))
                        .frame(width: 120, height: 120)

                    VStack(spacing: 4) {
                        Text("\(event.newLevel)")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(ShelfTheme.copperLight)
                        Text("LEVEL")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }
                }
                .scaleEffect(showContent ? 1 : 0.4)
                .opacity(showContent ? 1 : 0)

                VStack(spacing: 6) {
                    Text(event.rankTitle)
                        .font(.shelfTitle)
                        .foregroundStyle(ShelfTheme.textPrimary)
                    Text("+\(event.xpGained) XP · saved \(Formatters.currencyString(event.savingsGained))")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.success)
                }
                .opacity(showContent ? 1 : 0)

                Button("Continue") { dismiss() }
                    .font(.shelfHeadline)
                    .foregroundStyle(ShelfTheme.backgroundPrimary)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .background(ShelfTheme.copperGradient)
                    .clipShape(Capsule())
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(ShelfMotion.spring) { showContent = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func dismiss() {
        confetti = false
        onDismiss()
    }
}

struct XPGainToast: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(ShelfTheme.copperGlow)
            Text("+\(amount) XP")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(ShelfTheme.copperLight)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(ShelfTheme.backgroundSecondary)
                .overlay {
                    Capsule().strokeBorder(ShelfTheme.copperLight.opacity(0.5), lineWidth: 1)
                }
        }
        .shadow(color: ShelfTheme.copper.opacity(0.35), radius: 10, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct PlayerLevelCard: View {
    let playerStore: PlayerLevelStore

    var body: some View {
        GlassCard(glow: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(playerStore.rank.title, systemImage: playerStore.rank.icon)
                            .font(.shelfHeadline)
                            .foregroundStyle(ShelfTheme.copperLight)
                        Text("Level \(playerStore.level) · \(Formatters.currencyString(playerStore.lifetimeSavings)) saved")
                            .font(.shelfCaption)
                            .foregroundStyle(ShelfTheme.textSecondary)
                    }
                    Spacer()
                    Text("\(playerStore.currentXP)/\(playerStore.xpToNext)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(ShelfTheme.textTertiary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ShelfTheme.backgroundTertiary)
                        Capsule()
                            .fill(ShelfTheme.copperGradient)
                            .frame(width: geo.size.width * playerStore.progress)
                            .shadow(color: ShelfTheme.copper.opacity(0.5), radius: 4)
                    }
                }
                .frame(height: 10)

                Text("Save money on deals and receipts to earn \(PlayerLevelService.xpPerDollarSaved) XP per dollar!")
                    .font(.system(size: 10))
                    .foregroundStyle(ShelfTheme.textTertiary)
            }
        }
    }
}
