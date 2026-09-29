//
//  HandPoseProcessor.swift
//  AR2
//

import CoreVideo
import ImageIO
import UIKit
import Vision
import os

/// Konversi koordinat antara Vision dan gambar mentah kamera ARKit.
nonisolated enum VisionGeometry {
    /// Orientasi gambar kamera agar tangan tampak tegak bagi model Vision.
    /// Hanya memengaruhi akurasi deteksi; ketepatan koordinat dijamin oleh `rawImagePoint`.
    static func imageOrientation(for interface: UIInterfaceOrientation, frontCamera: Bool) -> CGImagePropertyOrientation {
        switch (interface, frontCamera) {
        case (.landscapeRight, false): .up
        case (.landscapeLeft, false): .down
        case (.portraitUpsideDown, false): .left
        case (_, false): .right
        case (.landscapeRight, true): .downMirrored
        case (.landscapeLeft, true): .upMirrored
        case (.portraitUpsideDown, true): .rightMirrored
        case (_, true): .leftMirrored
        }
    }

    /// Titik Vision (ternormalisasi, origin kiri-bawah, pada gambar yang sudah diorientasikan)
    /// → titik ternormalisasi pada gambar mentah kamera (origin kiri-atas),
    /// yaitu ruang koordinat yang dipakai `ARFrame.displayTransform`.
    static func rawImagePoint(fromVision point: CGPoint, orientation: CGImagePropertyOrientation) -> CGPoint {
        let u = point.x
        let v = 1 - point.y
        switch orientation {
        case .up: return CGPoint(x: u, y: v)
        case .upMirrored: return CGPoint(x: 1 - u, y: v)
        case .down: return CGPoint(x: 1 - u, y: 1 - v)
        case .downMirrored: return CGPoint(x: u, y: 1 - v)
        case .left: return CGPoint(x: 1 - v, y: u)
        case .leftMirrored: return CGPoint(x: 1 - v, y: 1 - u)
        case .right: return CGPoint(x: v, y: 1 - u)
        case .rightMirrored: return CGPoint(x: v, y: u)
        @unknown default: return CGPoint(x: u, y: v)
        }
    }
}

/// Menjalankan deteksi pose tangan Vision di antrean background.
nonisolated final class HandPoseProcessor: @unchecked Sendable {
    // `request` hanya disentuh dari `queue`
    private let request: VNDetectHumanHandPoseRequest
    private let queue = DispatchQueue(label: "AR2.handPose", qos: .userInitiated)

    init() {
        request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2 // Deteksi 2 tangan untuk gestur tepuk
    }

    /// Titik tengah telapak tiap tangan, dalam koordinat gambar mentah kamera (ternormalisasi, origin kiri-atas).
    func detectHands(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) async -> [CGPoint] {
        nonisolated(unsafe) let buffer = pixelBuffer
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                continuation.resume(returning: detect(in: buffer, orientation: orientation))
            }
        }
    }

    private func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> [CGPoint] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            Logger.vision.error("Vision gagal: \(error.localizedDescription)")
            return []
        }
        return (request.results ?? [])
            .compactMap(Self.palmCenter(of:))
            .map { VisionGeometry.rawImagePoint(fromVision: $0, orientation: orientation) }
    }

    /// Rata-rata 11 titik (pergelangan + 2 sendi pangkal tiap jari) supaya tracking stabil di tengah telapak.
    private static func palmCenter(of observation: VNHumanHandPoseObservation) -> CGPoint? {
        let joints: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbMP, .thumbIP,
            .indexMCP, .indexPIP,
            .middleMCP, .middlePIP,
            .ringMCP, .ringPIP,
            .littleMCP, .littlePIP,
        ]

        // Titik dengan confidence rendah dibuang; rata-rata banyak titik membuatnya kebal terhadap 1-2 titik yang salah
        let points = joints.compactMap { joint -> CGPoint? in
            guard let point = try? observation.recognizedPoint(joint), point.confidence > 0.5 else { return nil }
            return point.location
        }

        // Minimal 4 titik valid agar dihitung sebagai tangan
        guard points.count >= 4 else { return nil }
        let count = CGFloat(points.count)
        return CGPoint(
            x: points.map(\.x).reduce(0, +) / count,
            y: points.map(\.y).reduce(0, +) / count
        )
    }
}
