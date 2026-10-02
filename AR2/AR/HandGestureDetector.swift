//
//  HandGestureDetector.swift
//  AR2
//

import CoreGraphics
import Foundation

/// Satu tangan dari frame Vision: titik tengah telapak (ternormalisasi terhadap layar) dan bentuknya.
struct HandSample: Equatable {
    var palm: CGPoint
    var shape: HandShape = .unknown
}

/// Mengubah tangan per frame Vision menjadi gestur: tepuk (ganti wujud), tinju, dan gestur tangan
/// yang diminta langkah cerita. Semua titik ternormalisasi terhadap layar (0...1, origin kiri-atas).
struct HandGestureDetector {
    struct Result: Equatable {
        /// Posisi tangan yang sudah dihaluskan (untuk indikator debug).
        var handPoint: CGPoint?
        /// 0...1 selama dua tangan ditahan menyatu.
        var clapProgress: Double = 0
        /// 0...1 menuju gestur cerita yang diminta.
        var gestureProgress: Double = 0
        /// Arah pukulan di ruang layar (vektor satuan, sumbu y ke bawah).
        var punchDirection: CGVector?
        var didClap = false
        /// Gestur cerita yang diminta (selain tinju) sudah selesai.
        var didComplete = false
    }

    var punchVelocityThreshold: Double = 1.5     // Kecepatan minimum pukulan (layar per detik)
    var nearGhostVelocityThreshold: Double = 0.5 // Lebih mudah memukul jika tangan dekat hantu
    var nearGhostRadius: Double = 0.25
    var clapDistance: Double = 0.20              // Jarak dua tangan yang dianggap "bersatu"
    var clapHoldDuration: TimeInterval = 0.8     // Harus ditahan selama ini
    var smoothingFactor: Double = 0.4            // EMA: 40% posisi baru, 60% posisi lama
    var historySize = 5
    var touchRadius: Double = 0.15               // Telapak dianggap menyentuh hantu
    var faceCoverRadius: Double = 0.22           // Tangan dianggap menutupi wajah
    /// Wajah hilang sesaat setelah tangan menutupinya juga dihitung (ARKit kehilangan wajah yang tertutup).
    var faceLostGrace: TimeInterval = 1.5
    static let waveReversals = 3

    private var smoothedPoint: CGPoint?
    private var history: [(point: CGPoint, time: TimeInterval)] = []
    private var clapStart: TimeInterval?
    private var hold = HoldTimer(duration: 0.5)
    private var waveCounter = ReversalCounter(threshold: 0.04, window: 1.2)
    private var lastFaceCovered: TimeInterval?
    private var expected: GhostGesture?

    var hasState: Bool {
        smoothedPoint != nil || !history.isEmpty || clapStart != nil || hold.isActive
    }

    mutating func reset() {
        smoothedPoint = nil
        history.removeAll()
        clapStart = nil
        hold.reset()
        waveCounter.reset()
        lastFaceCovered = nil
    }

    /// - Parameters:
    ///   - hands: tangan yang terdeteksi di frame ini.
    ///   - ghostPoint: posisi hantu di layar, untuk tinju dan sentuhan.
    ///   - facePoint: posisi wajah di layar; `nil` bila wajah tidak terlacak.
    ///   - expected: gestur yang diminta langkah cerita (hanya gestur tangan yang diproses di sini).
    mutating func process(
        hands: [HandSample],
        ghostPoint: CGPoint?,
        facePoint: CGPoint? = nil,
        expected newExpected: GhostGesture? = nil,
        canPunch: Bool,
        canClap: Bool,
        at time: TimeInterval
    ) -> Result {
        if newExpected != expected {
            expected = newExpected
            hold.reset()
            waveCounter.reset()
            lastFaceCovered = nil
            hold.duration = newExpected == .touchGhost ? 0.8 : 0.5
        }

        guard let hand = hands.first?.palm else {
            smoothedPoint = nil
            history.removeAll()
            clapStart = nil
            // Cilukba: tangan bisa ikut hilang saat menutupi kamera dan wajah
            let progress = expected == .hideFace ? storyProgress(hands: [], ghostPoint: ghostPoint, facePoint: facePoint, time: time) : 0
            return finish(Result(gestureProgress: progress))
        }

        // --- Gestur tepuk: dua tangan menyatu dan ditahan ---
        if hands.count >= 2, canClap, distance(hands[0].palm, hands[1].palm) < clapDistance {
            let start = clapStart ?? time
            clapStart = start
            let progress = min((time - start) / clapHoldDuration, 1)
            if progress >= 1 {
                clapStart = nil
                return Result(handPoint: smoothedPoint, didClap: true)
            }
            return Result(handPoint: smoothedPoint, clapProgress: progress)
        }
        clapStart = nil

        let smoothed: CGPoint
        if let previous = smoothedPoint {
            smoothed = CGPoint(
                x: previous.x + smoothingFactor * (hand.x - previous.x),
                y: previous.y + smoothingFactor * (hand.y - previous.y)
            )
        } else {
            smoothed = hand
        }
        smoothedPoint = smoothed
        history.append((smoothed, time))
        if history.count > historySize {
            history.removeFirst()
        }

        var result = Result(handPoint: smoothed)
        if expected?.isHandGesture == true, expected != .punch {
            result.gestureProgress = storyProgress(hands: hands, ghostPoint: ghostPoint, facePoint: facePoint, time: time)
            return finish(result)
        }

        // --- Gestur pukul: kecepatan tangan pertama melewati threshold ---
        guard canPunch, history.count >= 2, let oldest = history.first else { return result }

        let dt = time - oldest.time
        guard dt > 0.01 else { return result }

        let dx = smoothed.x - oldest.point.x
        let dy = smoothed.y - oldest.point.y
        let length = hypot(dx, dy)
        let velocity = length / dt
        let isNearGhost = ghostPoint.map { distance(smoothed, $0) < nearGhostRadius } ?? false
        let threshold = isNearGhost ? nearGhostVelocityThreshold : punchVelocityThreshold

        guard velocity > threshold, length > 0.001 else { return result }
        result.punchDirection = CGVector(dx: dx / length, dy: dy / length)
        history.removeAll()
        return result
    }

    /// Progres 0...1 gestur tangan yang diminta cerita.
    private mutating func storyProgress(hands: [HandSample], ghostPoint: CGPoint?, facePoint: CGPoint?, time: TimeInterval) -> Double {
        guard let gesture = expected else { return 0 }
        switch gesture {
        case .wave:
            guard let point = smoothedPoint, hands.first?.shape != .fist else { return 0 }
            let count = waveCounter.update(Double(point.x), at: time)
            return Double(count) / Double(Self.waveReversals)

        case .touchGhost:
            let touching = ghostPoint.map { ghost in hands.contains { distance($0.palm, ghost) < touchRadius } } ?? false
            return hold.update(matching: touching, at: time)

        case .hideFace:
            var covered = false
            if let face = facePoint {
                covered = hands.count >= 2 && hands.prefix(2).allSatisfy { distance($0.palm, face) < faceCoverRadius }
            } else if let last = lastFaceCovered {
                // Wajah tertutup sampai tidak terlacak lagi
                covered = time - last < faceLostGrace
            }
            if covered, facePoint != nil {
                lastFaceCovered = time
            }
            return hold.update(matching: covered, at: time)

        default:
            guard let shape = gesture.handShape else { return 0 }
            return hold.update(matching: hands.contains { $0.shape == shape }, at: time)
        }
    }

    private mutating func finish(_ result: Result) -> Result {
        guard result.gestureProgress >= 1 else { return result }
        var done = result
        done.didComplete = true
        hold.reset()
        waveCounter.reset()
        lastFaceCovered = nil
        return done
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }
}
