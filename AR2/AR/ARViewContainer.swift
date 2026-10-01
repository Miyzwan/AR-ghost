//
//  ARViewContainer.swift
//  AR2
//

import RealityKit
import SwiftUI

struct ARViewContainer: UIViewRepresentable {
    let model: GhostARModel

    func makeCoordinator() -> GhostARModel {
        model
    }

    func makeUIView(context: Context) -> ARView {
        // Sesi dijalankan sendiri oleh GhostARModel sesuai ARMode
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        // Latar kamera harus diset eksplisit: default-nya milik proses RealityKit dan bisa jadi
        // hitam jika view RealityKit lain (kamera virtual) pernah tampil lebih dulu
        arView.environment.background = .cameraFeed()
        model.attach(to: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: GhostARModel) {
        // Matikan kamera saat kembali ke Home
        coordinator.detach()
    }
}
