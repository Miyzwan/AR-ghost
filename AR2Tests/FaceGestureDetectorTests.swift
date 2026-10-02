//
//  FaceGestureDetectorTests.swift
//  AR2Tests
//

import Foundation
import Testing
@testable import AR2

struct FaceGestureDetectorTests {
    private let fps: TimeInterval = 1.0 / 30

    /// Memutar deret sinyal per frame dan mengembalikan waktu pertama gestur selesai.
    private func run(
        _ expected: GhostGesture, frames: Int, handsVisible: Bool = false,
        signals: (TimeInterval) -> FaceSignals?
    ) -> TimeInterval? {
        var detector = FaceGestureDetector()
        for i in 0..<frames {
            let t = Double(i) * fps
            if detector.process(signals(t), handsVisible: handsVisible, expected: expected, at: t).didComplete {
                return t
            }
        }
        return nil
    }

    @Test func heldSmileCompletes() {
        let done = run(.smile, frames: 60) { _ in FaceSignals(smile: 0.8) }
        #expect(done != nil)
        #expect((done ?? 0) >= FaceGestureDetector.expressionHold - 0.001)
    }

    @Test func flashOfSmileDoesNotComplete() {
        let done = run(.smile, frames: 60) { t in FaceSignals(smile: t < 0.2 ? 0.8 : 0.1) }
        #expect(done == nil)
    }

    @Test func blinkingBothEyesIsNotAWink() {
        let both = run(.wink, frames: 30) { _ in FaceSignals(blinkLeft: 0.9, blinkRight: 0.9) }
        #expect(both == nil)
        let one = run(.wink, frames: 30) { _ in FaceSignals(blinkLeft: 0.9, blinkRight: 0.1) }
        #expect(one != nil)
    }

    @Test func nodNeedsDownUpDown() {
        // Menunduk-mendongak 20° dua kali per detik
        let nod = run(.nod, frames: 60) { t in FaceSignals(pitch: Float(0.35 * sin(t * 2 * .pi * 2))) }
        #expect(nod != nil)

        // Menoleh tidak dihitung sebagai angguk
        let turn = run(.nod, frames: 60) { t in FaceSignals(yaw: Float(0.35 * sin(t * 2 * .pi * 2))) }
        #expect(turn == nil)
    }

    @Test func shakeReadsYaw() {
        let shake = run(.shakeHead, frames: 60) { t in FaceSignals(yaw: Float(0.35 * sin(t * 2 * .pi * 2))) }
        #expect(shake != nil)
    }

    @Test func holdStillNeedsQuietHeadAndNoHands() {
        let still = run(.holdStill, frames: 120) { _ in FaceSignals() }
        #expect(still != nil)
        #expect((still ?? 0) >= FaceGestureDetector.stillDuration - 0.001)

        let withHands = run(.holdStill, frames: 120, handsVisible: true) { _ in FaceSignals() }
        #expect(withHands == nil)

        let moving = run(.holdStill, frames: 120) { t in FaceSignals(yaw: Float(0.3 * sin(t * 2 * .pi))) }
        #expect(moving == nil)
    }

    @Test func holdStillWorksWithoutFaceInWorldMode() {
        let done = run(.holdStill, frames: 120) { _ in nil }
        #expect(done != nil)
    }

    @Test func handGesturesAreIgnored() {
        let done = run(.openPalm, frames: 60) { _ in FaceSignals(smile: 1, jawOpen: 1) }
        #expect(done == nil)
    }
}
