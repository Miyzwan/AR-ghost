//
//  HandGestureDetector.swift
//  AR2
//

import CoreGraphics
import Foundation

/// Mengubah posisi tangan per frame Vision menjadi gestur "pukul" dan "tepuk".
/// Semua titik ternormalisasi terhadap layar (0...1, origin kiri-atas).
struct HandGestureDetector {
    struct Result: Equatable {
        /// Posisi tangan yang sudah dihaluskan (untuk indikator debug).
        var handPoint: CGPoint?
        /// 0...1 selama dua tangan ditahan menyatu.
        var clapProgress: Double = 0
        /// Arah pukulan di ruang layar (vektor satuan, sumbu y ke bawah).
        var punchDirection: CGVector?
        var didClap = false
    }

    var punchVelocityThreshold: Double = 1.5     // Kecepatan minimum pukulan (layar per detik)
    var nearGhostVelocityThreshold: Double = 0.5 // Lebih mudah memukul jika tangan dekat hantu
    var nearGhostRadius: Double = 0.25
    var clapDistance: Double = 0.20              // Jarak dua tangan yang dianggap "bersatu"
    var clapHoldDuration: TimeInterval = 0.8     // Harus ditahan selama ini
    var smoothingFactor: Double = 0.4            // EMA: 40% posisi baru, 60% posisi lama
    var historySize = 5

    private var smoothedPoint: CGPoint?
    private var history: [(point: CGPoint, time: TimeInterval)] = []
    private var clapStart: TimeInterval?

    var hasState: Bool {
        smoothedPoint != nil || !history.isEmpty || clapStart != nil
    }

    mutating func reset() {
        smoothedPoint = nil
        history.removeAll()
        clapStart = nil
    }

    /// - Parameters:
    ///   - hands: titik tengah telapak tiap tangan yang terdeteksi.
    ///   - ghostPoint: posisi hantu di layar, untuk threshold pukulan yang lebih mudah di dekatnya.
    mutating func process(
        hands: [CGPoint],
        ghostPoint: CGPoint?,
        canPunch: Bool,
        canClap: Bool,
        at time: TimeInterval
    ) -> Result {
        guard let hand = hands.first else {
            reset()
            return Result()
        }

        // --- Gestur tepuk: dua tangan menyatu dan ditahan ---
        if hands.count >= 2, canClap, distance(hands[0], hands[1]) < clapDistance {
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

        // --- Gestur pukul: kecepatan tangan pertama melewati threshold ---
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

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }
}
