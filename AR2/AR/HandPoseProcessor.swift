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
        // Orientasi mirrored yang berotasi adalah transpose; jangan
        // membalik kedua sumbu lagi setelah inverse rotation.
        case .leftMirrored: return CGPoint(x: v, y: u)
        case .right: return CGPoint(x: v, y: 1 - u)
        case .rightMirrored: return CGPoint(x: 1 - v, y: 1 - u)
        @unknown default: return CGPoint(x: u, y: v)
        }
    }
}

/// Hasil satu frame Vision. Semua titik dalam koordinat gambar mentah kamera (ternormalisasi, origin kiri-atas).
nonisolated struct VisionFrame: Sendable {
    struct Hand: Sendable {
        var palm: CGPoint
        var shape: HandShape
    }

    /// Titik tubuh bagian atas, bila diminta dan terdeteksi.
    struct Body: Sendable {
        var leftShoulder: CGPoint?
        var rightShoulder: CGPoint?
        var neck: CGPoint?
    }

    var hands: [Hand] = []
    var body: Body?
}

/// Menjalankan deteksi pose tangan (dan bila diminta, pose tubuh) Vision di antrean background.
nonisolated final class HandPoseProcessor: @unchecked Sendable {
    // Request hanya disentuh dari `queue`
    private let handRequest: VNDetectHumanHandPoseRequest
    private let bodyRequest = VNDetectHumanBodyPoseRequest()
    private let queue = DispatchQueue(label: "AR2.handPose", qos: .userInitiated)

    init() {
        handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2 // Deteksi 2 tangan untuk gestur tepuk
    }

    /// - Parameter includeBody: jalankan juga pose tubuh (untuk hantu di pundak/dada).
    func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, includeBody: Bool) async -> VisionFrame {
        nonisolated(unsafe) let buffer = pixelBuffer
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                continuation.resume(returning: detectSync(in: buffer, orientation: orientation, includeBody: includeBody))
            }
        }
    }

    private func detectSync(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, includeBody: Bool) -> VisionFrame {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        let requests: [VNRequest] = includeBody ? [handRequest, bodyRequest] : [handRequest]
        do {
            try handler.perform(requests)
        } catch {
            Logger.vision.error("Vision gagal: \(error.localizedDescription)")
            return VisionFrame()
        }

        let toRaw = { (point: CGPoint) in VisionGeometry.rawImagePoint(fromVision: point, orientation: orientation) }
        var frame = VisionFrame()
        frame.hands = (handRequest.results ?? []).compactMap { observation in
            guard let palm = Self.palmCenter(of: observation) else { return nil }
            return VisionFrame.Hand(palm: toRaw(palm), shape: HandShapeClassifier.classify(Self.joints(of: observation)))
        }
        if includeBody, let body = bodyRequest.results?.first {
            let point = { (joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? in
                guard let p = try? body.recognizedPoint(joint), p.confidence > 0.3 else { return nil }
                return toRaw(p.location)
            }
            frame.body = VisionFrame.Body(leftShoulder: point(.leftShoulder), rightShoulder: point(.rightShoulder), neck: point(.neck))
        }
        return frame
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

    /// Sendi untuk `HandShapeClassifier`, masih di ruang Vision (rasio jarak tidak berubah oleh orientasi).
    private static func joints(of observation: VNHumanHandPoseObservation) -> HandJoints {
        let point = { (joint: VNHumanHandPoseObservation.JointName) -> CGPoint? in
            guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.3 else { return nil }
            return p.location
        }
        return HandJoints(
            wrist: point(.wrist),
            thumbTip: point(.thumbTip),
            index: .init(tip: point(.indexTip), pip: point(.indexPIP), mcp: point(.indexMCP)),
            middle: .init(tip: point(.middleTip), pip: point(.middlePIP), mcp: point(.middleMCP)),
            ring: .init(tip: point(.ringTip), pip: point(.ringPIP), mcp: point(.ringMCP)),
            little: .init(tip: point(.littleTip), pip: point(.littlePIP), mcp: point(.littleMCP))
        )
    }
}
