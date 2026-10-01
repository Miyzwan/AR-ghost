//
//  HandGestureDetectorTests.swift
//  AR2Tests
//

import CoreGraphics
import Foundation
import Testing
@testable import AR2

struct HandGestureDetectorTests {
    private let farFromGhost = CGPoint(x: 0.9, y: 0.9)

    /// Menggerakkan satu tangan dari `from` ke `to` dalam `steps` frame dengan jarak waktu `interval`.
    private func move(
        _ detector: inout HandGestureDetector,
        from: CGPoint, to: CGPoint, steps: Int, interval: TimeInterval,
        ghost: CGPoint? = nil, canPunch: Bool = true
    ) -> [HandGestureDetector.Result] {
        (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let point = CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
            return detector.process(hands: [point], ghostPoint: ghost ?? farFromGhost, canPunch: canPunch, canClap: true, at: Double(i) * interval)
        }
    }

    @Test func noHandsResetsState() {
        var detector = HandGestureDetector()
        _ = detector.process(hands: [CGPoint(x: 0.5, y: 0.5)], ghostPoint: nil, canPunch: true, canClap: true, at: 0)
        #expect(detector.hasState)

        let result = detector.process(hands: [], ghostPoint: nil, canPunch: true, canClap: true, at: 0.1)
        #expect(result == HandGestureDetector.Result())
        #expect(!detector.hasState)
    }

    @Test func slowMovementIsNotAPunch() {
        var detector = HandGestureDetector()
        // 0.2 layar dalam 1 detik
        let results = move(&detector, from: CGPoint(x: 0.4, y: 0.5), to: CGPoint(x: 0.6, y: 0.5), steps: 12, interval: 1.0 / 12)
        #expect(results.allSatisfy { $0.punchDirection == nil })
    }

    @Test func fastMovementPunchesInItsDirection() {
        var detector = HandGestureDetector()
        // 0.8 layar ke kanan dalam 0.24 detik
        let results = move(&detector, from: CGPoint(x: 0.1, y: 0.5), to: CGPoint(x: 0.9, y: 0.5), steps: 3, interval: 0.08)
        let punch = results.compactMap(\.punchDirection).first
        #expect(punch != nil)
        #expect((punch?.dx ?? 0) > 0.99)
        #expect(abs(punch?.dy ?? 1) < 0.01)
    }

    @Test func slowerSwingCountsAsPunchNearTheGhost() {
        let from = CGPoint(x: 0.35, y: 0.5)
        let to = CGPoint(x: 0.65, y: 0.5)
        // 0.3 layar dalam 0.24 detik: setelah dihaluskan di bawah threshold normal, di atas threshold dekat hantu
        var far = HandGestureDetector()
        let farResults = move(&far, from: from, to: to, steps: 3, interval: 0.08)
        #expect(farResults.allSatisfy { $0.punchDirection == nil })

        var near = HandGestureDetector()
        let nearResults = move(&near, from: from, to: to, steps: 3, interval: 0.08, ghost: CGPoint(x: 0.5, y: 0.5))
        #expect(nearResults.contains { $0.punchDirection != nil })
    }

    @Test func noPunchWhenNotAllowed() {
        var detector = HandGestureDetector()
        let results = move(&detector, from: CGPoint(x: 0.2, y: 0.5), to: CGPoint(x: 0.8, y: 0.5), steps: 3, interval: 0.08, canPunch: false)
        #expect(results.allSatisfy { $0.punchDirection == nil })
    }

    @Test func clapMustBeHeld() {
        var detector = HandGestureDetector()
        let hands = [CGPoint(x: 0.48, y: 0.5), CGPoint(x: 0.52, y: 0.5)]

        let first = detector.process(hands: hands, ghostPoint: nil, canPunch: true, canClap: true, at: 0)
        #expect(first.clapProgress == 0)
        #expect(!first.didClap)

        let half = detector.process(hands: hands, ghostPoint: nil, canPunch: true, canClap: true, at: 0.4)
        #expect(abs(half.clapProgress - 0.5) < 0.0001)

        let done = detector.process(hands: hands, ghostPoint: nil, canPunch: true, canClap: true, at: 0.8)
        #expect(done.didClap)
    }

    @Test func separatingHandsRestartsClap() {
        var detector = HandGestureDetector()
        let together = [CGPoint(x: 0.48, y: 0.5), CGPoint(x: 0.52, y: 0.5)]
        let apart = [CGPoint(x: 0.1, y: 0.5), CGPoint(x: 0.9, y: 0.5)]

        _ = detector.process(hands: together, ghostPoint: nil, canPunch: true, canClap: true, at: 0)
        let separated = detector.process(hands: apart, ghostPoint: nil, canPunch: true, canClap: true, at: 0.4)
        #expect(separated.clapProgress == 0)

        let again = detector.process(hands: together, ghostPoint: nil, canPunch: true, canClap: true, at: 0.9)
        #expect(again.clapProgress == 0)
        #expect(!again.didClap)
    }

    @Test func noClapWhenTransformNotAllowed() {
        var detector = HandGestureDetector()
        let hands = [CGPoint(x: 0.48, y: 0.5), CGPoint(x: 0.52, y: 0.5)]
        _ = detector.process(hands: hands, ghostPoint: nil, canPunch: true, canClap: false, at: 0)
        let later = detector.process(hands: hands, ghostPoint: nil, canPunch: true, canClap: false, at: 1)
        #expect(later.clapProgress == 0)
        #expect(!later.didClap)
    }
}
