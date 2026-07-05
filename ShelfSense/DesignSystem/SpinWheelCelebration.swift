//
//  SpinWheelCelebration.swift
//  ShelfSense
//

import AudioToolbox
import AVFoundation

enum SpinWheelCelebration {
    private static var spinPlayer: AVAudioPlayer?

    static func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    static func playSpinStart() {
        AudioServicesPlaySystemSound(1104)
    }

    static func playTick() {
        AudioServicesPlaySystemSound(1519)
    }

    static func playWin() {
        AudioServicesPlaySystemSound(1025)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            AudioServicesPlaySystemSound(1114)
        }
    }

    static func playCoin() {
        AudioServicesPlaySystemSound(1057)
    }
}
