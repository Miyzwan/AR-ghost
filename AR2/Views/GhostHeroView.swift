//
//  GhostHeroView.swift
//  AR2
//

import SceneKit
import SwiftUI
import os

/// Model 3D hantu yang melayang dan bergoyang di Home (tanpa kamera/AR).
///
/// Sengaja memakai SceneKit, bukan RealityView: RealityView berkamera virtual yang tampil
/// sebelum layar AR membuat latar kamera ARView menjadi hitam di perangkat.
struct GhostHeroView: View {
    var ghost: Ghost = GhostCatalog.all[0]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: SCNScene?
    @State private var loadFailed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Pendaran labu di bawah hantu
            Ellipse()
                .fill(Spooky.pumpkin.opacity(0.4))
                .frame(width: 180, height: 36)
                .blur(radius: 24)
                .padding(.bottom, 8)

            if let scene {
                GhostSceneView(scene: scene)
            } else if loadFailed {
                Text(verbatim: "👻")
                    .font(.system(size: 130))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            // Dimuat sekali saja, bukan di tiap evaluasi body
            guard scene == nil, !loadFailed else { return }
            scene = GhostHeroScene.make(for: ghost, animated: !reduceMotion)
            loadFailed = scene == nil
        }
    }
}

private enum GhostHeroScene {
    private static let height: Float = 0.2

    /// Memuat USDZ, menormalkan tingginya, lalu menambahkan kamera, cahaya, dan goyangan.
    static func make(for ghost: Ghost, animated: Bool) -> SCNScene? {
        guard let url = Bundle.main.url(forResource: ghost.id, withExtension: "usdz") else {
            Logger.ar.error("File \(ghost.id).usdz tidak ditemukan di bundle.")
            return nil
        }
        let source: SCNScene
        do {
            source = try SCNScene(url: url)
        } catch {
            Logger.ar.error("Gagal memuat hantu Home \(ghost.id): \(error.localizedDescription)")
            return nil
        }

        let model = SCNNode()
        for child in source.rootNode.childNodes {
            model.addChildNode(child)
        }

        // Tiap USDZ punya satuan dan pivot berbeda: skalakan ke tinggi target, pivot di tengah-bawah
        let (minBound, maxBound) = model.boundingBox
        let factor = height / max(maxBound.y - minBound.y, 0.0001)
        model.scale = SCNVector3(factor, factor, factor)
        model.position = SCNVector3(
            -(minBound.x + maxBound.x) / 2 * factor,
            -minBound.y * factor,
            -(minBound.z + maxBound.z) / 2 * factor
        )

        // Pivot terpisah supaya goyangan tidak bentrok dengan animasi bawaan model
        let pivot = SCNNode()
        pivot.addChildNode(model)

        let scene = SCNScene()
        scene.rootNode.addChildNode(pivot)

        // Model punya alas diorama yang lebar, jadi kamera agak jauh dan sedikit dari atas
        let camera = SCNCamera()
        camera.fieldOfView = 40
        camera.zNear = 0.01
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, height * 1.05, 0.54)
        cameraNode.look(at: SCNVector3(0, height * 0.42, 0))
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1000
        key.position = SCNVector3(0.4, 0.8, 0.8)
        key.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(key)

        if animated {
            let swayRight = SCNAction.group([
                .rotateTo(x: 0, y: 0.4, z: 0, duration: 2.6),
                .moveBy(x: 0, y: 0.02, z: 0, duration: 2.6),
            ])
            let swayLeft = SCNAction.group([
                .rotateTo(x: 0, y: -0.4, z: 0, duration: 2.6),
                .moveBy(x: 0, y: -0.02, z: 0, duration: 2.6),
            ])
            swayRight.timingMode = .easeInEaseOut
            swayLeft.timingMode = .easeInEaseOut
            pivot.eulerAngles.y = -0.4
            pivot.runAction(.repeatForever(.sequence([swayRight, swayLeft])))
        }
        return scene
    }
}

/// SCNView transparan supaya langit malam di belakangnya tetap terlihat.
private struct GhostSceneView: UIViewRepresentable {
    let scene: SCNScene

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

#Preview {
    ZStack {
        SpookyBackground()
        GhostHeroView()
            .frame(height: 320)
    }
}
