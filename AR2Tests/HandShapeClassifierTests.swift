//
//  HandShapeClassifierTests.swift
//  AR2Tests
//

import CoreGraphics
import Testing
@testable import AR2

struct HandShapeClassifierTests {
    /// Tangan tegak buatan: pergelangan di bawah, jari ke atas. Ukuran telapak 0.2.
    private func hand(
        index: Bool, middle: Bool, ring: Bool, little: Bool,
        thumbOut: Bool, pinch: Bool = false
    ) -> HandJoints {
        func finger(x: CGFloat, extended: Bool) -> HandJoints.Finger {
            HandJoints.Finger(
                tip: CGPoint(x: x, y: extended ? 0.62 : 0.38),
                pip: CGPoint(x: x, y: 0.5),
                mcp: CGPoint(x: x, y: 0.4)
            )
        }
        let indexFinger = finger(x: 0.45, extended: index)
        var thumbTip = thumbOut ? CGPoint(x: 0.25, y: 0.35) : CGPoint(x: 0.47, y: 0.42)
        if pinch, let tip = indexFinger.tip {
            thumbTip = CGPoint(x: tip.x + 0.02, y: tip.y)
        }
        return HandJoints(
            wrist: CGPoint(x: 0.5, y: 0.2),
            thumbTip: thumbTip,
            index: indexFinger,
            middle: finger(x: 0.5, extended: middle),
            ring: finger(x: 0.55, extended: ring),
            little: finger(x: 0.6, extended: little)
        )
    }

    @Test func recognizesEachShape() {
        #expect(HandShapeClassifier.classify(hand(index: true, middle: true, ring: true, little: true, thumbOut: true)) == .open)
        #expect(HandShapeClassifier.classify(hand(index: true, middle: true, ring: false, little: false, thumbOut: false)) == .peace)
        #expect(HandShapeClassifier.classify(hand(index: true, middle: false, ring: false, little: false, thumbOut: false)) == .point)
        #expect(HandShapeClassifier.classify(hand(index: false, middle: false, ring: false, little: false, thumbOut: true)) == .thumbsUp)
        #expect(HandShapeClassifier.classify(hand(index: false, middle: false, ring: false, little: false, thumbOut: false)) == .fist)
        #expect(HandShapeClassifier.classify(hand(index: true, middle: true, ring: true, little: true, thumbOut: false, pinch: true)) == .pinch)
    }

    @Test func unusualCombinationIsUnknown() {
        // Salam "shaka": ibu jari dan kelingking lurus
        #expect(HandShapeClassifier.classify(hand(index: false, middle: false, ring: false, little: true, thumbOut: true)) == .unknown)
    }

    @Test func missingJointsAreUnknown() {
        var joints = hand(index: true, middle: true, ring: true, little: true, thumbOut: true)
        joints.ring.tip = nil
        #expect(HandShapeClassifier.classify(joints) == .unknown)
        joints = hand(index: true, middle: true, ring: true, little: true, thumbOut: true)
        joints.wrist = nil
        #expect(HandShapeClassifier.classify(joints) == .unknown)
    }
}
