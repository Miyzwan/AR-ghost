//
//  SoundManager.swift
//  AR2
//

import AVFoundation
import SwiftUI
import os

// MARK: - Sound Manager
final class SoundManager {
    static let shared = SoundManager()

    enum Effect: String, CaseIterable {
        case punch
        case transform
    }

    private let musicFile = "backsound"
    private var bgmPlayer: AVAudioPlayer?
    // Satu player per efek (di-preload) supaya efek berbeda tidak saling memotong
    private var effectPlayers: [Effect: AVAudioPlayer] = [:]
    private var interruptionObserver: NSObjectProtocol?
    private var isAppActive = true

    private var isMusicEnabled: Bool { UserDefaults.standard.bool(forKey: AppSettings.musicEnabled) }
    private var isSoundEffectsEnabled: Bool { UserDefaults.standard.bool(forKey: AppSettings.soundEffectsEnabled) }

    private init() {}

    /// Dipanggil sekali saat app mulai.
    func start() {
        // .ambient: menghormati tombol silent dan tidak menghentikan musik dari app lain
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            Logger.audio.error("Gagal mengatur audio session: \(error.localizedDescription)")
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] note in
            let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                // Lanjutkan musik setelah interupsi (mis. telepon masuk) selesai
                if rawType == AVAudioSession.InterruptionType.ended.rawValue {
                    self?.updateMusicPlayback()
                }
            }
        }

        bgmPlayer = makePlayer(named: musicFile)
        bgmPlayer?.numberOfLoops = -1 // Ulang tanpa henti
        for effect in Effect.allCases {
            effectPlayers[effect] = makePlayer(named: effect.rawValue)
        }
        updateMusicPlayback()
    }

    func play(_ effect: Effect) {
        guard isSoundEffectsEnabled, let player = effectPlayers[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    /// Suara shutter kamera bawaan sistem.
    func playShutter() {
        guard isSoundEffectsEnabled else { return }
        AudioServicesPlaySystemSound(1108)
    }

    /// Musik dijeda saat app di background, lalu dilanjutkan saat aktif kembali.
    func handleScenePhase(_ phase: ScenePhase) {
        isAppActive = phase == .active
        updateMusicPlayback()
    }

    /// Menyalakan/mematikan musik sesuai pengaturan dan status app.
    func updateMusicPlayback() {
        guard let bgmPlayer else { return }
        if isMusicEnabled && isAppActive {
            if !bgmPlayer.isPlaying { bgmPlayer.play() }
        } else {
            bgmPlayer.pause()
        }
    }

    private func makePlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            Logger.audio.error("File audio '\(name).mp3' tidak ditemukan di bundle.")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            Logger.audio.error("Gagal memuat '\(name).mp3': \(error.localizedDescription)")
            return nil
        }
    }
}
