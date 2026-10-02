//
//  StoryProgress.swift
//  AR2
//

import Foundation

/// Kemajuan cerita satu hantu. Murni dan tanpa timer: `GhostARModel` memanggil `advance()`
/// setelah reaksi hantu selesai, dan `arrive()` setelah hantu pindah ke titik berikutnya.
struct StoryProgress {
    enum Phase: Equatable {
        /// Menunggu gestur langkah ini.
        case playing(step: Int)
        /// Gestur benar; hantu sedang bereaksi.
        case celebrating(step: Int)
        /// Hantu sedang pindah ke titik langkah berikutnya.
        case moving(to: Int)
        case finished
    }

    let story: GhostStory
    /// Kamera depan bisa membaca wajah; jika tidak, gestur wajah diganti gestur tangan.
    let faceCamera: Bool
    private(set) var phase: Phase = .playing(step: 0)

    init(story: GhostStory, faceCamera: Bool) {
        self.story = story
        self.faceCamera = faceCamera
        if story.steps.isEmpty { phase = .finished }
    }

    /// Langkah yang kalimatnya sedang tampil.
    var stepIndex: Int {
        switch phase {
        case let .playing(step), let .celebrating(step): step
        case let .moving(to): to
        case .finished: story.steps.count
        }
    }

    /// Gestur yang sedang ditunggu; `nil` saat hantu bereaksi, pindah, atau cerita selesai.
    var expectedGesture: GhostGesture? {
        guard case let .playing(step) = phase else { return nil }
        return gesture(at: step)
    }

    /// Titik hantu untuk langkah saat ini (atau langkah terakhir setelah cerita selesai).
    var spot: BodySpot {
        guard !story.steps.isEmpty else { return .aboveHead }
        return story.steps[min(stepIndex, story.steps.count - 1)].spot
    }

    var line: LocalizedStringResource {
        stepIndex < story.steps.count ? story.steps[stepIndex].line : story.finale
    }

    var isFinished: Bool { phase == .finished }

    func gesture(at step: Int) -> GhostGesture {
        story.steps[step].gesture.resolved(faceCamera: faceCamera)
    }

    /// Gestur pengguna selesai. Mengembalikan `true` bila itu gestur yang ditunggu.
    @discardableResult
    mutating func complete(_ gesture: GhostGesture) -> Bool {
        guard case let .playing(step) = phase, gesture == self.gesture(at: step) else { return false }
        phase = .celebrating(step: step)
        return true
    }

    /// Reaksi selesai: lanjut ke langkah berikutnya atau ke penutup.
    mutating func advance() {
        guard case let .celebrating(step) = phase else { return }
        phase = step + 1 < story.steps.count ? .moving(to: step + 1) : .finished
    }

    /// Hantu sudah muncul di titik baru.
    mutating func arrive() {
        guard case let .moving(to) = phase else { return }
        phase = .playing(step: to)
    }
}
