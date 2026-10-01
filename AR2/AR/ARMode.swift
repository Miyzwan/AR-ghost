//
//  ARMode.swift
//  AR2
//

import ARKit
import RealityKit

/// Cara hantu ditampilkan, tergantung kemampuan perangkat.
enum ARMode {
    /// Kamera depan (TrueDepth): hantu muncul di atas kepala pengguna.
    case face
    /// Kamera belakang: hantu muncul di lantai/meja. Untuk perangkat tanpa TrueDepth.
    case world

    #if DEBUG
    /// Launch argument `-debug.forceWorldMode YES` memaksa mode dunia di perangkat Face ID.
    static let forceWorldModeKey = "debug.forceWorldMode"
    #endif

    static var preferred: ARMode {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: forceWorldModeKey) { return .world }
        #endif
        return ARFaceTrackingConfiguration.isSupported ? .face : .world
    }

    var isSupported: Bool {
        switch self {
        case .face: ARFaceTrackingConfiguration.isSupported
        case .world: ARWorldTrackingConfiguration.isSupported
        }
    }

    var usesFrontCamera: Bool { self == .face }

    var layout: GhostMotion.Layout {
        switch self {
        case .face: .face
        case .world: .world
        }
    }

    /// Tinggi kotak hantu (meter). Semua wujud dimuatkan ke kotak yang sama lewat `GhostSizing`.
    var ghostHeight: Float {
        switch self {
        case .face: 0.2 // di atas kepala
        case .world: 0.45 // di atas lantai/meja
        }
    }

    func makeConfiguration() -> ARConfiguration {
        switch self {
        case .face:
            let configuration = ARFaceTrackingConfiguration()
            configuration.maximumNumberOfTrackedFaces = 1
            return configuration
        case .world:
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            configuration.environmentTexturing = .automatic
            return configuration
        }
    }

    func makeAnchor() -> AnchorEntity {
        switch self {
        case .face:
            AnchorEntity(.face)
        case .world:
            AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.2, 0.2]))
        }
    }
}
