//
//  GhostARModel.swift
//  AR2
//

import ARKit
import Combine
import RealityKit
import SwiftUI
import os

/// Otak layar AR: memegang sesi ARKit, entity hantu, animasi, dan deteksi gestur.
/// SwiftUI hanya membaca properti yang teramati; state per-frame diabaikan oleh Observation.
@Observable
final class GhostARModel: NSObject {
    enum Status: Equatable {
        case loading
        case running
        case unsupported
        case interrupted
        case failed
    }

    let mode: ARMode
    private(set) var status: Status = .loading
    private(set) var activeGhost: Ghost = GhostCatalog.all[0]
    /// Wajah (mode wajah) atau permukaan (mode dunia) sudah ditemukan.
    private(set) var isTargetFound = false
    /// Posisi tangan di layar, hanya diisi di build DEBUG.
    private(set) var handPoint: CGPoint?
    private(set) var clapProgress: Double = 0
    /// Bertambah setiap pukulan/transformasi berhasil; dipakai sebagai pemicu haptic.
    private(set) var punchCount = 0
    private(set) var transformCount = 0
    var showGhostInfo = false

    private static let visionInterval: TimeInterval = 0.08 // ~12fps, hemat CPU
    private static let smokeLifetime: TimeInterval = 2.0

    private enum PendingSwap {
        case loaded(index: Int, model: Entity)
        case failed
    }

    @ObservationIgnored private weak var arView: ARView?
    @ObservationIgnored private var coachingOverlay: ARCoachingOverlayView?
    @ObservationIgnored private var anchor: AnchorEntity?
    /// Wadah yang dianimasikan; model hantu menjadi anaknya dan bisa ditukar.
    @ObservationIgnored private var ghostRoot: Entity?
    @ObservationIgnored private var ghostModel: Entity?
    @ObservationIgnored private var activeIndex = 0
    @ObservationIgnored private var motion: GhostMotion?
    @ObservationIgnored private var pendingSwap: PendingSwap?
    @ObservationIgnored private var smoke: Entity?
    @ObservationIgnored private var smokeRemovalTime: TimeInterval = 0
    @ObservationIgnored private var updateSubscription: (any Cancellable)?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var visionTask: Task<Void, Never>?
    @ObservationIgnored private var detector = HandGestureDetector()
    @ObservationIgnored private let handPoseProcessor = HandPoseProcessor()
    @ObservationIgnored private var isVisionBusy = false
    @ObservationIgnored private var lastVisionTime: TimeInterval = 0

    init(mode: ARMode) {
        self.mode = mode
        super.init()
    }

    // MARK: - Lifecycle

    func attach(to arView: ARView) {
        self.arView = arView
        guard mode.isSupported else {
            status = .unsupported
            return
        }

        arView.session.delegate = self
        if mode == .world {
            addCoachingOverlay(to: arView)
        }

        let anchor = mode.makeAnchor()
        let ghostRoot = Entity()
        ghostRoot.isEnabled = false
        anchor.addChild(ghostRoot)
        arView.scene.addAnchor(anchor)
        self.anchor = anchor
        self.ghostRoot = ghostRoot

        updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            self?.update()
        }
        runSession(reset: false)
        loadInitialGhost()
    }

    /// Menghentikan kamera dan melepas semua resource saat layar AR ditutup.
    func detach() {
        updateSubscription?.cancel()
        updateSubscription = nil
        loadTask?.cancel()
        visionTask?.cancel()
        if let arView {
            arView.session.pause()
            arView.session.delegate = nil
            arView.scene.anchors.removeAll()
        }
        coachingOverlay?.removeFromSuperview()
        coachingOverlay = nil
        arView = nil
        anchor = nil
        ghostRoot = nil
        ghostModel = nil
        motion = nil
        pendingSwap = nil
        smoke = nil
    }

    func retry() {
        runSession(reset: true)
        if ghostModel == nil {
            loadInitialGhost()
        } else {
            status = .running
        }
    }

    // MARK: - Actions

    /// Mengubah wujud hantu (dari gestur tepuk).
    func transform() {
        let now = CACurrentMediaTime()
        guard var motion, motion.beginTransform(at: now) else { return }
        self.motion = motion
        detector.reset()
        clearGestureFeedback()
        showGhostInfo = false
        spawnSmoke(at: motion.layout.restPosition, now: now)
        SoundManager.shared.play(.transform)
        transformCount += 1

        let nextIndex = (activeIndex + 1) % GhostCatalog.all.count
        let nextGhost = GhostCatalog.all[nextIndex]
        // Model dimuat di background; ditukar saat hantu tersembunyi di dalam asap
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let model = try await makeGhostModel(for: nextGhost)
                pendingSwap = .loaded(index: nextIndex, model: model)
            } catch {
                Logger.ar.error("Gagal memuat \(nextGhost.id): \(error.localizedDescription)")
                pendingSwap = .failed
            }
        }
    }

    /// Mengambil foto layar AR (kamera + hantu).
    func snapshot() async -> UIImage? {
        guard let arView else { return nil }
        return await withCheckedContinuation { continuation in
            arView.snapshot(saveToHDR: false) { image in
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Per-frame update

    private func update() {
        guard let arView, let anchor, let ghostRoot, ghostModel != nil else { return }
        let now = CACurrentMediaTime()

        if let smoke, now >= smokeRemovalTime {
            smoke.removeFromParent()
            self.smoke = nil
        }

        let targetFound = mode == .face ? isFaceTracked(in: arView) : anchor.isAnchored
        if isTargetFound != targetFound {
            isTargetFound = targetFound
        }

        // Animasi baru dimulai setelah wajah/permukaan ditemukan
        if motion == nil {
            guard targetFound else { return }
            motion = GhostMotion(layout: mode.layout, startTime: now)
            ghostRoot.isEnabled = true
        }
        guard var motion else { return }

        if motion.phase == .hidden, let swap = pendingSwap {
            applySwap(swap)
            pendingSwap = nil
            motion.reveal(at: now)
        }

        let pose = motion.update(at: now, facingYaw: facingYaw(in: arView, anchor: anchor))
        ghostRoot.transform = Transform(
            scale: SIMD3(repeating: max(pose.scale, 0.001)),
            rotation: pose.rotation,
            translation: pose.position
        )
        self.motion = motion

        if motion.canPunch(at: now) {
            detectHandsIfNeeded(in: arView, at: now)
        } else if detector.hasState {
            detector.reset()
            clearGestureFeedback()
        }
    }

    // MARK: - Hand detection

    private func detectHandsIfNeeded(in arView: ARView, at now: TimeInterval) {
        guard !isVisionBusy, now - lastVisionTime >= Self.visionInterval,
              let frame = arView.session.currentFrame else { return }
        let viewSize = arView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return }

        let interfaceOrientation = arView.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        // Memetakan koordinat gambar kamera ke koordinat view, termasuk rotasi, crop, dan mirror kamera depan
        let imageToView = frame.displayTransform(for: interfaceOrientation, viewportSize: viewSize)
        let orientation = VisionGeometry.imageOrientation(for: interfaceOrientation, frontCamera: mode.usesFrontCamera)
        let pixelBuffer = frame.capturedImage

        lastVisionTime = now
        isVisionBusy = true
        visionTask = Task { [weak self, handPoseProcessor] in
            let rawPoints = await handPoseProcessor.detectHands(in: pixelBuffer, orientation: orientation)
            guard let self else { return }
            isVisionBusy = false
            guard !Task.isCancelled else { return }
            handleHands(rawPoints.map { $0.applying(imageToView) }, viewSize: viewSize)
        }
    }

    /// `hands` ternormalisasi terhadap view (0...1).
    private func handleHands(_ hands: [CGPoint], viewSize: CGSize) {
        guard let arView, let motion else { return }
        let now = CACurrentMediaTime()
        let ghostPoint = ghostScreenPoint(in: arView).map {
            CGPoint(x: $0.x / viewSize.width, y: $0.y / viewSize.height)
        }
        let result = detector.process(
            hands: hands,
            ghostPoint: ghostPoint,
            canPunch: motion.canPunch(at: now),
            canClap: motion.canTransform(at: now),
            at: now
        )

        #if DEBUG
        let point = result.handPoint.map { CGPoint(x: $0.x * viewSize.width, y: $0.y * viewSize.height) }
        if handPoint != point {
            handPoint = point
        }
        #endif
        if clapProgress != result.clapProgress {
            clapProgress = result.clapProgress
        }

        if result.didClap {
            transform()
        } else if let direction = result.punchDirection {
            punch(screenDirection: CGVector(dx: direction.dx * viewSize.width, dy: direction.dy * viewSize.height))
        }
    }

    private func clearGestureFeedback() {
        if handPoint != nil { handPoint = nil }
        if clapProgress != 0 { clapProgress = 0 }
    }

    // MARK: - Punch

    /// Memukul hantu ke arah `screenDirection` (satuan point layar, sumbu y ke bawah).
    private func punch(screenDirection: CGVector) {
        guard let arView, let anchor, let ghostRoot, var motion else { return }
        let center = ghostRoot.visualBounds(relativeTo: nil).center
        let worldDirection = worldDirection(for: screenDirection, at: center, in: arView)
        let direction = anchor.convert(direction: worldDirection, from: nil)

        guard motion.punch(direction: direction, at: CACurrentMediaTime()) else { return }
        self.motion = motion
        detector.reset()
        SoundManager.shared.play(.punch)
        punchCount += 1
    }

    /// Mengubah arah di layar menjadi arah dunia pada bidang yang sejajar layar dan melewati `point`.
    /// Proyeksi ini tetap benar untuk kamera depan (mirror) maupun belakang, di orientasi apa pun.
    private func worldDirection(for screenDirection: CGVector, at point: SIMD3<Float>, in arView: ARView) -> SIMD3<Float> {
        let camera = arView.cameraTransform
        if let origin = arView.project(point),
           let ray = arView.ray(through: CGPoint(x: origin.x + screenDirection.dx, y: origin.y + screenDirection.dy)) {
            let normal = simd_normalize(point - camera.translation)
            let denominator = simd_dot(ray.direction, normal)
            if abs(denominator) > 0.0001 {
                let t = simd_dot(point - ray.origin, normal) / denominator
                let hit = ray.origin + ray.direction * t
                if simd_length(hit - point) > 0.0001 {
                    return simd_normalize(hit - point)
                }
            }
        }
        // Cadangan: pakai sumbu kanan/atas kamera
        let right = camera.rotation.act([1, 0, 0])
        let up = camera.rotation.act([0, 1, 0])
        return right * Float(screenDirection.dx) - up * Float(screenDirection.dy)
    }

    // MARK: - Ghost model

    private func loadInitialGhost() {
        status = .loading
        let ghost = GhostCatalog.all[activeIndex]
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let model = try await makeGhostModel(for: ghost)
                guard !Task.isCancelled else { return }
                install(model)
                status = .running
            } catch {
                Logger.ar.error("Gagal memuat \(ghost.id): \(error.localizedDescription)")
                status = .failed
            }
        }
    }

    /// Memuat model lalu menormalkan ukurannya. Tiap file USDZ punya satuan berbeda,
    /// jadi model diskalakan ke tinggi target dengan pivot di tengah-bawah.
    private func makeGhostModel(for ghost: Ghost) async throws -> Entity {
        let model = try await Entity(named: ghost.id)
        let container = Entity()
        container.addChild(model)

        let bounds = model.visualBounds(relativeTo: container)
        let factor = mode.targetHeight(for: ghost) / max(bounds.extents.y, 0.0001)
        model.scale *= factor
        model.position = -SIMD3(bounds.center.x, bounds.min.y, bounds.center.z) * factor

        if let animation = model.availableAnimations.first {
            model.playAnimation(animation.repeat())
        }
        return container
    }

    private func install(_ model: Entity) {
        guard let ghostRoot else { return }
        ghostModel?.removeFromParent()
        ghostRoot.addChild(model)
        ghostModel = model
    }

    private func applySwap(_ swap: PendingSwap) {
        switch swap {
        case let .loaded(index, model):
            install(model)
            activeIndex = index
            activeGhost = GhostCatalog.all[index]
        case .failed:
            // Tetap memakai wujud lama
            break
        }
    }

    private func spawnSmoke(at position: SIMD3<Float>, now: TimeInterval) {
        guard let anchor else { return }
        smoke?.removeFromParent()

        let sizeFactor: Float = mode == .world ? 3 : 1
        var particles = ParticleEmitterComponent()
        particles.emitterShape = .sphere
        particles.emitterShapeSize = SIMD3(repeating: 0.03 * sizeFactor)
        particles.mainEmitter.birthRate = 300
        particles.mainEmitter.lifeSpan = 1.5
        particles.mainEmitter.size = 0.01 * sizeFactor
        particles.mainEmitter.sizeVariation = 0.04 * sizeFactor
        particles.mainEmitter.color = .evolving(
            start: .single(.init(red: 0.8, green: 0.0, blue: 0.0, alpha: 0.8)),
            end: .single(.init(red: 0.3, green: 0.0, blue: 0.0, alpha: 0.0))
        )
        particles.mainEmitter.isLightingEnabled = false

        let smoke = Entity()
        smoke.components.set(particles)
        smoke.position = position + SIMD3(0, mode.targetHeight(for: activeGhost) / 2, 0)
        anchor.addChild(smoke)
        self.smoke = smoke
        smokeRemovalTime = now + Self.smokeLifetime
    }

    // MARK: - Helpers

    private func runSession(reset: Bool) {
        guard let arView, mode.isSupported else { return }
        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        arView.session.run(mode.makeConfiguration(), options: options)
        if reset {
            // Hantu akan muncul lagi dari awal setelah target ditemukan
            motion = nil
            ghostRoot?.isEnabled = false
            detector.reset()
            clearGestureFeedback()
        }
    }

    private func addCoachingOverlay(to arView: ARView) {
        let overlay = ARCoachingOverlayView()
        overlay.session = arView.session
        overlay.goal = .horizontalPlane
        overlay.activatesAutomatically = true
        overlay.frame = arView.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(overlay)
        coachingOverlay = overlay
    }

    private func isFaceTracked(in arView: ARView) -> Bool {
        arView.session.currentFrame?.anchors.contains { ($0 as? ARFaceAnchor)?.isTracked == true } ?? false
    }

    /// Mode dunia: putar hantu agar menghadap kamera. Mode wajah: anchor sudah menghadap kamera.
    private func facingYaw(in arView: ARView, anchor: AnchorEntity) -> Float {
        guard mode == .world else { return 0 }
        let camera = anchor.convert(position: arView.cameraTransform.translation, from: nil)
        return atan2(camera.x, camera.z)
    }

    private func ghostScreenPoint(in arView: ARView) -> CGPoint? {
        guard let ghostRoot else { return nil }
        return arView.project(ghostRoot.visualBounds(relativeTo: nil).center)
    }
}

// MARK: - ARSessionDelegate

extension GhostARModel: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: any Error) {
        Logger.ar.error("Sesi AR gagal: \(error.localizedDescription)")
        status = .failed
    }

    func sessionWasInterrupted(_ session: ARSession) {
        status = .interrupted
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        retry()
    }
}

private extension Entity {
    func isDescendant(of ancestor: Entity) -> Bool {
        var current: Entity? = self
        while let entity = current {
            if entity === ancestor { return true }
            current = entity.parent
        }
        return false
    }
}
