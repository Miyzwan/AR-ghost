//
//  AppSettings.swift
//  AR2
//

import Foundation

// Kunci UserDefaults yang dipakai bersama oleh @AppStorage di view dan oleh SoundManager.
enum AppSettings {
    static let musicEnabled = "settings.musicEnabled"
    static let soundEffectsEnabled = "settings.soundEffectsEnabled"
    static let hapticsEnabled = "settings.hapticsEnabled"
    static let hasSeenOnboarding = "hasSeenOnboarding"

    /// Nilai awal sebelum pengguna mengubah apa pun.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            musicEnabled: true,
            soundEffectsEnabled: true,
            hapticsEnabled: true,
        ])
    }
}
