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
    /// Efek `.wav` per nama (cheer, jingle, teleport), dimuat saat pertama dipakai atau lewat `preload`.
    private var soundPlayers: [String: AVAudioPlayer] = [:]
    // "Suara bicara" hantu: satu blip pendek yang diputar dengan nada berbeda tiap hantu
    private let voiceEngine = AVAudioEngine()
    private let voiceNode = AVAudioPlayerNode()
    private let voicePitch = AVAudioUnitVarispeed()
    private var voiceBuffers: [String: AVAudioPCMBuffer] = [:]
    private var isVoiceEngineReady = false
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

    /// Memuat efek lebih awal supaya tidak tersendat saat pertama dimainkan.
    func preload(_ names: [String]) {
        for name in names where soundPlayers[name] == nil {
            soundPlayers[name] = makePlayer(named: name, extension: "wav")
        }
    }

    /// Memainkan efek `.wav` dari `AR2/Sounds`.
    func play(sound name: String, volume: Float = 1) {
        guard isSoundEffectsEnabled else { return }
        if soundPlayers[name] == nil {
            soundPlayers[name] = makePlayer(named: name, extension: "wav")
        }
        guard let player = soundPlayers[name] else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    /// Satu suku kata "bicara" hantu. Nadanya sedikit diacak supaya terdengar seperti celoteh.
    func playVoice(_ voice: GhostVoice) {
        guard isSoundEffectsEnabled, let buffer = voiceBuffer(named: voice.blip), prepareVoiceEngine(format: buffer.format) else { return }
        voicePitch.rate = voice.pitch * Float.random(in: 0.92...1.08)
        voiceNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !voiceNode.isPlaying { voiceNode.play() }
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

    private func makePlayer(named name: String, extension ext: String = "mp3") -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            Logger.audio.error("File audio '\(name).\(ext)' tidak ditemukan di bundle.")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            Logger.audio.error("Gagal memuat '\(name).\(ext)': \(error.localizedDescription)")
            return nil
        }
    }

    private func voiceBuffer(named name: String) -> AVAudioPCMBuffer? {
        if let buffer = voiceBuffers[name] { return buffer }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            Logger.audio.error("File audio '\(name).wav' tidak ditemukan di bundle.")
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
            try file.read(into: buffer)
            voiceBuffers[name] = buffer
            return buffer
        } catch {
            Logger.audio.error("Gagal memuat '\(name).wav': \(error.localizedDescription)")
            return nil
        }
    }

    /// Menyambungkan node sekali, lalu menyalakan ulang mesin bila berhenti (mis. setelah interupsi).
    private func prepareVoiceEngine(format: AVAudioFormat) -> Bool {
        if !isVoiceEngineReady {
            voiceEngine.attach(voiceNode)
            voiceEngine.attach(voicePitch)
            voiceEngine.connect(voiceNode, to: voicePitch, format: format)
            voiceEngine.connect(voicePitch, to: voiceEngine.mainMixerNode, format: format)
            voiceNode.volume = 0.6
            isVoiceEngineReady = true
        }
        guard !voiceEngine.isRunning else { return true }
        do {
            try voiceEngine.start()
            return true
        } catch {
            Logger.audio.error("Gagal menyalakan mesin suara: \(error.localizedDescription)")
            return false
        }
    }
}
