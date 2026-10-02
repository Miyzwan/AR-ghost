//
//  FaceGestureDetector.swift
//  AR2
//

import Foundation

/// Ekspresi dan arah kepala dari `ARFaceAnchor` dalam satu frame.
struct FaceSignals: Equatable {
    var smile: Float = 0
    var jawOpen: Float = 0
    var browInnerUp: Float = 0
    var cheekPuff: Float = 0
    var tongueOut: Float = 0
    var mouthPucker: Float = 0
    var blinkLeft: Float = 0
    var blinkRight: Float = 0
    /// Radian, relatif terhadap gravitasi: menunduk/mendongak, menoleh, memiringkan kepala.
    var pitch: Float = 0
    var yaw: Float = 0
    var roll: Float = 0
}

/// Mendeteksi gestur wajah dan `holdStill` untuk satu gestur yang sedang diminta cerita.
/// Murni (tanpa ARKit) dan berbasis timestamp, jadi bisa diuji dengan deret sinyal buatan.
struct FaceGestureDetector {
    struct Result: Equatable {
        var progress: Double = 0
        var didComplete = false
    }

    static let expressionHold: TimeInterval = 0.5
    static let winkHold: TimeInterval = 0.25
    static let stillDuration: TimeInterval = 3
    /// Jumlah balik arah kepala untuk angguk/geleng (turun-naik-turun).
    static let headReversals = 2
    /// Kecepatan putar kepala maksimum (radian/detik) yang masih dianggap diam.
    static let stillSpeed: Float = 0.35

    private var hold = HoldTimer(duration: Self.expressionHold)
    private var stillHold = HoldTimer(duration: Self.stillDuration, tolerance: 0.4)
    private var reversals = ReversalCounter(threshold: 0.14, window: 1.5)
    private var expected: GhostGesture?
    private var previous: (signals: FaceSignals, time: TimeInterval)?

    mutating func reset() {
        hold.reset()
        stillHold.reset()
        reversals.reset()
        previous = nil
    }

    /// - Parameters:
    ///   - signals: `nil` bila wajah tidak terlacak atau kamera tidak bisa membaca wajah (mode dunia).
    ///   - handsVisible: tangan terlihat di frame Vision terakhir (untuk `holdStill`).
    mutating func process(
        _ signals: FaceSignals?,
        handsVisible: Bool,
        expected newExpected: GhostGesture?,
        at time: TimeInterval
    ) -> Result {
        if newExpected != expected {
            reset()
            expected = newExpected
            hold.duration = newExpected == .wink ? Self.winkHold : Self.expressionHold
        }
        guard let gesture = expected, gesture.requiresFace || gesture == .holdStill else { return Result() }
        defer {
            if let signals { previous = (signals, time) } else { previous = nil }
        }

        if gesture == .holdStill {
            return holdStillResult(signals, handsVisible: handsVisible, at: time)
        }
        guard let signals else {
            hold.reset()
            return Result()
        }

        switch gesture {
        case .nod, .shakeHead:
            let angle = gesture == .nod ? signals.pitch : signals.yaw
            let count = reversals.update(Double(angle), at: time)
            if count >= Self.headReversals {
                reversals.reset()
                return Result(progress: 1, didComplete: true)
            }
            return Result(progress: Double(count) / Double(Self.headReversals))
        default:
            let progress = hold.update(matching: Self.matches(gesture, signals), at: time)
            if progress >= 1 {
                hold.reset()
                return Result(progress: 1, didComplete: true)
            }
            return Result(progress: progress)
        }
    }

    private mutating func holdStillResult(_ signals: FaceSignals?, handsVisible: Bool, at time: TimeInterval) -> Result {
        var isStill = !handsVisible
        // Tanpa wajah (mode dunia) cukup tanpa tangan; dengan wajah, kepala juga harus diam
        if let signals, let previous, time > previous.time {
            let dt = Float(time - previous.time)
            let turn = max(abs(signals.pitch - previous.signals.pitch), abs(signals.yaw - previous.signals.yaw))
            isStill = isStill && turn / dt < Self.stillSpeed
        }
        let progress = stillHold.update(matching: isStill, at: time)
        if progress >= 1 {
            stillHold.reset()
            return Result(progress: 1, didComplete: true)
        }
        return Result(progress: progress)
    }

    static func matches(_ gesture: GhostGesture, _ s: FaceSignals) -> Bool {
        switch gesture {
        case .smile: s.smile > 0.5
        case .wink: (s.blinkLeft > 0.6 && s.blinkRight < 0.3) || (s.blinkRight > 0.6 && s.blinkLeft < 0.3)
        case .mouthOpen: s.jawOpen > 0.5
        case .eyebrowRaise: s.browInnerUp > 0.6
        case .cheekPuff: s.cheekPuff > 0.5
        case .tongueOut: s.tongueOut > 0.5
        case .kiss: s.mouthPucker > 0.6
        case .tiltHead: abs(s.roll) > 0.26
        default: false
        }
    }
}
