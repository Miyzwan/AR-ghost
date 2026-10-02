//
//  HandShapeClassifier.swift
//  AR2
//

import CoreGraphics
import Foundation

/// Bentuk tangan yang dikenali dari sendi Vision.
nonisolated enum HandShape: Equatable, Sendable {
    case open, fist, peace, point, thumbsUp, pinch, unknown
}

/// Sendi tangan yang dipakai klasifikasi, dalam koordinat ternormalisasi gambar yang sama.
nonisolated struct HandJoints: Sendable {
    struct Finger: Sendable {
        var tip: CGPoint?
        var pip: CGPoint?
        var mcp: CGPoint?
    }

    var wrist: CGPoint?
    var thumbTip: CGPoint?
    var index = Finger()
    var middle = Finger()
    var ring = Finger()
    var little = Finger()
}

/// Mengubah sendi tangan menjadi `HandShape`. Murni dan nonisolated: dijalankan di antrean Vision.
nonisolated enum HandShapeClassifier {
    /// Jari lurus bila ujungnya jauh lebih jauh dari pergelangan daripada sendi tengahnya.
    static let extendedRatio: CGFloat = 1.15
    /// Ibu jari terbuka bila ujungnya jauh dari pangkal telunjuk (pecahan ukuran telapak).
    static let thumbOutRatio: CGFloat = 0.65
    /// Cubit bila ujung ibu jari dan telunjuk berdekatan (pecahan ukuran telapak).
    static let pinchRatio: CGFloat = 0.3

    static func classify(_ joints: HandJoints) -> HandShape {
        guard let wrist = joints.wrist, let middleMCP = joints.middle.mcp else { return .unknown }
        let palmSize = distance(wrist, middleMCP)
        guard palmSize > 0.001 else { return .unknown }

        let fingers = [joints.index, joints.middle, joints.ring, joints.little].map { isExtended($0, wrist: wrist) }
        guard fingers.allSatisfy({ $0 != nil }) else { return .unknown }
        let extended = fingers.map { $0! }
        let thumbOut = isThumbOut(joints, palmSize: palmSize)

        // Cubit: ujung ibu jari menyentuh ujung telunjuk, jari lain tidak ikut mengepal.
        // Pada kepalan, ibu jari juga sering menempel di telunjuk yang tertekuk.
        if let thumbTip = joints.thumbTip, let indexTip = joints.index.tip,
           distance(thumbTip, indexTip) < palmSize * pinchRatio,
           extended[1] || extended[2] || extended[3] {
            return .pinch
        }

        switch (extended[0], extended[1], extended[2], extended[3]) {
        case (true, true, true, true): return .open
        case (true, true, false, false): return .peace
        case (true, false, false, false): return .point
        case (false, false, false, false):
            switch thumbOut {
            case true?: return .thumbsUp
            case false?: return .fist
            case nil: return .unknown
            }
        default: return .unknown
        }
    }

    private static func isExtended(_ finger: HandJoints.Finger, wrist: CGPoint) -> Bool? {
        guard let tip = finger.tip, let pip = finger.pip else { return nil }
        return distance(wrist, tip) > distance(wrist, pip) * extendedRatio
    }

    private static func isThumbOut(_ joints: HandJoints, palmSize: CGFloat) -> Bool? {
        guard let thumbTip = joints.thumbTip, let indexMCP = joints.index.mcp else { return nil }
        return distance(thumbTip, indexMCP) > palmSize * thumbOutRatio
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
