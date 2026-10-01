//
//  VisionGeometryTests.swift
//  AR2Tests
//

import CoreGraphics
import CoreImage
import ImageIO
import Testing
import UIKit
@testable import AR2

struct VisionGeometryTests {
    nonisolated static let orientations: [CGImagePropertyOrientation] = [
        .up, .upMirrored, .down, .downMirrored, .left, .leftMirrored, .right, .rightMirrored,
    ]

    /// Dibandingkan dengan Core Image sebagai acuan independen:
    /// titik di gambar mentah → gambar terorientasi (koordinat Vision) → kembali ke gambar mentah.
    @Test(arguments: orientations)
    func mapsVisionPointsBackToRawImage(orientation: CGImagePropertyOrientation) {
        // Gambar mentah tidak persegi agar rotasi yang salah ketahuan
        let raw = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 400, height: 300))
        let toOriented = raw.orientationTransform(for: orientation)
        let orientedExtent = raw.extent.applying(toOriented)

        let samples = [CGPoint(x: 10, y: 20), CGPoint(x: 390, y: 40), CGPoint(x: 200, y: 150), CGPoint(x: 50, y: 290)]
        for rawPoint in samples {
            // Core Image: origin kiri-bawah
            let oriented = rawPoint.applying(toOriented)
            let visionPoint = CGPoint(
                x: (oriented.x - orientedExtent.minX) / orientedExtent.width,
                y: (oriented.y - orientedExtent.minY) / orientedExtent.height
            )

            let mapped = VisionGeometry.rawImagePoint(fromVision: visionPoint, orientation: orientation)

            // Harapan: ternormalisasi dengan origin kiri-atas
            let expected = CGPoint(x: rawPoint.x / 400, y: 1 - rawPoint.y / 300)
            #expect(abs(mapped.x - expected.x) < 0.0001, "\(orientation.rawValue) x")
            #expect(abs(mapped.y - expected.y) < 0.0001, "\(orientation.rawValue) y")
        }
    }

    @Test func backCameraPortraitUsesRightOrientation() {
        #expect(VisionGeometry.imageOrientation(for: .portrait, frontCamera: false) == .right)
    }

    @Test func frontCameraPortraitIsMirrored() {
        #expect(VisionGeometry.imageOrientation(for: .portrait, frontCamera: true) == .leftMirrored)
    }

    @Test func frontCameraPortraitMapsVisionCoordinatesToRawImage() {
        let raw = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 400, height: 300))
        let orientation: CGImagePropertyOrientation = .leftMirrored
        let toOriented = raw.orientationTransform(for: orientation)
        let orientedExtent = raw.extent.applying(toOriented)

        let samples = [CGPoint(x: 10, y: 20), CGPoint(x: 390, y: 40), CGPoint(x: 200, y: 150), CGPoint(x: 50, y: 290)]
        for rawPoint in samples {
            let oriented = rawPoint.applying(toOriented)
            let visionPoint = CGPoint(
                x: (oriented.x - orientedExtent.minX) / orientedExtent.width,
                y: (oriented.y - orientedExtent.minY) / orientedExtent.height
            )

            let mapped = VisionGeometry.rawImagePoint(fromVision: visionPoint, orientation: orientation)
            let expected = CGPoint(x: rawPoint.x / 400, y: 1 - rawPoint.y / 300)

            #expect(abs(mapped.x - expected.x) < 0.0001, "front camera x: mapped=\(mapped.x), expected=\(expected.x)")
            #expect(abs(mapped.y - expected.y) < 0.0001, "front camera y: mapped=\(mapped.y), expected=\(expected.y)")
        }
    }
}
