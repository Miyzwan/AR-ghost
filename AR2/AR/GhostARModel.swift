//
//  GhostARModel.swift
//  AR2
//

import ARKit
import Combine
import RealityKit
import SwiftUI
import os

/// Otak layar AR: memegang sesi ARKit, entity hantu, animasi, cerita, dan deteksi gestur.
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
    /// 0...1 menuju gestur cerita yang sedang diminta.
    private(set) var gestureProgress: Double = 0
    /// Bertambah setiap pukulan/transformasi/langkah cerita berhasil; dipakai sebagai pemicu haptic.
    private(set) var punchCount = 0
    private(set) var transformCount = 0
    private(set) var storySuccessCount = 0
    /// Seruan langkah yang baru berhasil (ditampilkan meletup di layar).
    private(set) var cheer: LocalizedStringResource?
    /// Bertambah tiap hantu mencari perhatian; chip petunjuk berdenyut.
    private(set) var nudgeCount = 0
    /// Cerita tampil setelah hantu selesai muncul.
    private(set) var isStoryVisible = false
    private(set) var storyStepIndex = 0
    /// Gestur langkah ini sedang ditunggu (bukan saat hantu bereaksi atau pindah).
    private(set) var isAwaitingGesture = false
    private(set) var isStoryComplete = false
    /// Hantu menunggu di telapak, tetapi tangan pengguna belum terlihat.
    private(set) var needsHand = false
    #if DEBUG
    /// Nilai sensor mentah untuk mengkalibrasi ambang gestur di perangkat.
    private(set) var debugText = ""
    #endif
    var showGhostInfo = false

    private static let visionInterval: TimeInterval = 0.08 // ~12fps, hemat CPU
    private static let smokeLifetime: TimeInterval = 2.0
    /// Data Vision yang lebih tua dari ini tidak dipakai untuk menempatkan hantu.
    private static let visionStaleness: TimeInterval = 0.5
    /// Seberapa cepat hantu di titik yang dilacak mengejar targetnya per frame.
    private static let trackingLerp: Float = 0.2
    /// Hantu mencari perhatian bila gestur belum dicoba selama ini.
    private static let nudgeAfter: TimeInterval = 7
    private static let sharedSounds = ["sfx_appear", "sfx_vanish", "sfx_tick", "sfx_nudge"]

    private enum PendingSwap {
        case loaded(index: Int, model: Entity)
        case failed
    }

    /// Posisi, putaran, dan skala titik muncul pada anchor induknya.
    private struct Placement {
        var parent: Entity
        var position: SIMD3<Float>
        var rotation: simd_quatf
        var scale: Float
    }

    /// Hasil Vision terakhir, sudah dalam koordinat view (point).
    private struct VisionSnapshot {
        var palms: [CGPoint] = []
        var leftShoulder: CGPoint?
        var rightShoulder: CGPoint?
        var time: TimeInterval = 0
    }

    @ObservationIgnored private weak var arView: ARView?
    @ObservationIgnored private var coachingOverlay: ARCoachingOverlayView?
    /// Anchor wajah (mode wajah) atau permukaan (mode dunia).
    @ObservationIgnored private var anchor: AnchorEntity?
    /// Anchor dunia untuk titik yang dilacak tiap frame (pundak, dada, telapak) dan asap.
    @ObservationIgnored private var worldAnchor: AnchorEntity?
    /// Wadah yang dianimasikan; model hantu menjadi anaknya dan bisa ditukar.
    @ObservationIgnored private var ghostRoot: Entity?
    @ObservationIgnored private var ghostModel: Entity?
    @ObservationIgnored private var activeIndex = 0
    @ObservationIgnored private var motion: GhostMotion?
    @ObservationIgnored private var story: StoryProgress
    @ObservationIgnored private var spot: BodySpot
    @ObservationIgnored private var placement: Placement?
    /// Posisi dunia yang dihaluskan untuk titik yang dilacak; `nil` berarti langsung lompat ke target.
    @ObservationIgnored private var trackedPosition: SIMD3<Float>?
    @ObservationIgnored private var isTransforming = false
    @ObservationIgnored private var pendingSwap: PendingSwap?
    @ObservationIgnored private var smoke: Entity?
    @ObservationIgnored private var smokeRemovalTime: TimeInterval = 0
    @ObservationIgnored private var updateSubscription: (any Cancellable)?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var visionTask: Task<Void, Never>?
    @ObservationIgnored private var detector = HandGestureDetector()
    @ObservationIgnored private var faceDetector = FaceGestureDetector()
    @ObservationIgnored private let handPoseProcessor = HandPoseProcessor()
    @ObservationIgnored private var vision = VisionSnapshot()
    @ObservationIgnored private var isVisionBusy = false
    @ObservationIgnored private var lastVisionTime: TimeInterval = 0
    @ObservationIgnored private var handGestureProgress: Double = 0
    @ObservationIgnored private var lastDebugTime: TimeInterval = 0
    @ObservationIgnored private var lastPhase: GhostMotion.Phase?
    /// Terakhir kali pengguna mencoba gestur atau hantu mencari perhatian.
    @ObservationIgnored private var lastAttention: TimeInterval = 0
    /// Sepertiga progres terakhir yang sudah berbunyi "tik".
    @ObservationIgnored private var lastTickStep = 0
    @ObservationIgnored private var burst: Entity?
    @ObservationIgnored private var burstRemovalTime: TimeInterval = 0

    /// - Parameter startIndex: wujud pertama yang dipanggil (dipilih di Home).
    init(mode: ARMode, startIndex: Int = 0) {
        self.mode = mode
        let index = GhostCatalog.all.indices.contains(startIndex) ? startIndex : 0
        activeIndex = index
        activeGhost = GhostCatalog.all[index]
        story = StoryProgress(story: GhostCatalog.all[index].story, faceCamera: mode.usesFrontCamera)
        spot = story.spot
        super.init()
    }

    // MARK: - Cerita (dibaca SwiftUI)

    /// Kalimat hantu saat ini, atau penutup setelah cerita selesai.
    var storyLine: LocalizedStringResource {
        let steps = activeGhost.story.steps
        return storyStepIndex < steps.count ? steps[storyStepIndex].line : activeGhost.story.finale
    }

    /// Gestur yang diminta langkah ini, sesuai kamera yang dipakai.
    var storyGesture: GhostGesture? {
        let steps = activeGhost.story.steps
        guard isAwaitingGesture, storyStepIndex < steps.count else { return nil }
        return steps[storyStepIndex].gesture.resolved(faceCamera: mode.usesFrontCamera)
    }

    var storyStepCount: Int { activeGhost.story.steps.count }

    /// Wujud yang muncul bila pengguna bertepuk tangan.
    var nextGhost: Ghost { GhostCatalog.all[GhostCatalog.index(after: activeIndex)] }

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
        let worldAnchor = AnchorEntity(world: matrix_identity_float4x4)
        let ghostRoot = Entity()
        ghostRoot.isEnabled = false
        anchor.addChild(ghostRoot)
        arView.scene.addAnchor(anchor)
        arView.scene.addAnchor(worldAnchor)
        self.anchor = anchor
        self.worldAnchor = worldAnchor
        self.ghostRoot = ghostRoot

        updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            self?.update()
        }
        runSession(reset: false)
        loadInitialGhost()
        preloadSounds()
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
        worldAnchor = nil
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

    /// Mengubah wujud hantu (dari gestur tepuk). Cerita wujud baru dimulai dari awal.
    func transform() {
        let now = CACurrentMediaTime()
        guard var motion, motion.beginTransform(at: now) else { return }
        self.motion = motion
        isTransforming = true
        resetGestures()
        showGhostInfo = false
        spawnSmoke(now: now)
        SoundManager.shared.play(.transform)
        transformCount += 1

        let nextIndex = GhostCatalog.index(after: activeIndex)
        let nextGhost = GhostCatalog.all[nextIndex]
        // Model dimuat di background; ditukar saat hantu tersembunyi di dalam asap
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let model = try await makeGhostModel(for: nextGhost)
                guard !Task.isCancelled else { return }
                pendingSwap = .loaded(index: nextIndex, model: model)
            } catch {
                guard !Task.isCancelled else { return }
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
        if let burst, now >= burstRemovalTime {
            burst.removeFromParent()
            self.burst = nil
        }

        let targetFound = mode == .face ? isFaceTracked(in: arView) : anchor.isAnchored
        if isTargetFound != targetFound {
            isTargetFound = targetFound
        }

        // Animasi baru dimulai setelah wajah/permukaan ditemukan
        if motion == nil {
            guard targetFound else { return }
            motion = GhostMotion(layout: mode.layout, style: activeGhost.style, startTime: now)
            trackedPosition = nil
            ghostRoot.isEnabled = true
        }
        guard var motion else { return }

        if motion.phase == .hidden {
            if isTransforming {
                if let swap = pendingSwap {
                    applySwap(swap, motion: &motion)
                    pendingSwap = nil
                    isTransforming = false
                    motion.reveal(at: now)
                }
            } else if case .moving = story.phase {
                // Pindah titik selagi tak terlihat, lalu muncul lagi di sana
                story.arrive()
                spot = story.spot
                trackedPosition = nil
                lastAttention = now
                motion.reveal(at: now)
            }
        }

        advanceStory(motion: &motion, now: now)
        nudgeIfIgnored(motion: &motion, now: now)
        motion.anticipation = story.expectedGesture == nil ? 0 : Float(gestureProgress)

        let pose = motion.update(at: now)
        playPhaseSounds(motion.phase)
        if let placement = placement(for: spot, in: arView) {
            if ghostRoot.parent !== placement.parent {
                ghostRoot.setParent(placement.parent)
            }
            // Squash and stretch: tinggi dikali `stretch`, lebar dibagi √stretch
            let stretch = max(pose.stretch, 0.1)
            let size = max(pose.scale * placement.scale, 0.001)
            ghostRoot.transform = Transform(
                scale: SIMD3(size / sqrt(stretch), size * stretch, size / sqrt(stretch)),
                rotation: placement.rotation * pose.rotation,
                translation: placement.position + placement.rotation.act(pose.position * placement.scale)
            )
            self.placement = placement
        }
        self.motion = motion

        syncStory(motion: motion)

        if motion.phase != .waiting && motion.phase != .hidden {
            detectHandsIfNeeded(in: arView, at: now)
        }
        detectFaceGestures(in: arView, motion: motion, at: now)
    }

    /// Reaksi selesai → langkah berikutnya (pindah titik) atau penutup cerita.
    private func advanceStory(motion: inout GhostMotion, now: TimeInterval) {
        guard case .celebrating = story.phase, motion.phase == .idle else { return }
        story.advance()
        switch story.phase {
        case .moving:
            if motion.beginRelocation(at: now) {
                spawnSmoke(now: now, tint: activeGhost.glow)
                SoundManager.shared.play(sound: "sfx_vanish")
            }
        case .finished:
            UserDefaults.standard.set(
                StoryCompletion.adding(activeGhost.id, to: UserDefaults.standard.string(forKey: AppSettings.completedStories) ?? ""),
                forKey: AppSettings.completedStories
            )
            // Pesta penutup: loncatan kemenangan, kembang api, dan jingle khas hantu
            motion.celebrate(at: now)
            spawnBurst(finale: true, now: now)
            SoundManager.shared.play(sound: activeGhost.voice.jingle)
        default:
            break
        }
    }

    /// Menyalin state cerita ke properti teramati, hanya bila berubah.
    private func syncStory(motion: GhostMotion) {
        let visible = motion.phase != .waiting && motion.phase != .rising && !isTransforming
        if isStoryVisible != visible { isStoryVisible = visible }
        if storyStepIndex != story.stepIndex { storyStepIndex = story.stepIndex }
        let awaiting = story.expectedGesture != nil
        if isAwaitingGesture != awaiting { isAwaitingGesture = awaiting }
        if isStoryComplete != story.isFinished { isStoryComplete = story.isFinished }
        let waitingForHand = spot == .palm && awaiting && vision.palms.isEmpty
        if needsHand != waitingForHand { needsHand = waitingForHand }
    }

    /// Gestur cerita yang diminta sudah dilakukan.
    private func completeStoryStep(_ gesture: GhostGesture) {
        let step = story.stepIndex
        guard var motion, story.complete(gesture) else { return }
        let now = CACurrentMediaTime()
        // Tinju sudah membuat hantu terlempar; gestur lain dibalas reaksi khas hantu
        if gesture != .punch {
            motion.celebrate(at: now)
            self.motion = motion
        }
        SoundManager.shared.play(sound: activeGhost.voice.cheer)
        spawnBurst(finale: false, now: now)
        cheer = activeGhost.story.steps[step].cheer
        resetGestures()
        storySuccessCount += 1
    }

    /// Hantu meloncat-loncat dan bersuara bila pengguna lama tidak mencoba gestur.
    private func nudgeIfIgnored(motion: inout GhostMotion, now: TimeInterval) {
        guard story.expectedGesture != nil, motion.phase == .idle else {
            lastAttention = now
            return
        }
        if gestureProgress > 0 || clapProgress > 0 {
            lastAttention = now
        } else if now - lastAttention > Self.nudgeAfter, motion.nudge(at: now) {
            lastAttention = now
            nudgeCount += 1
            SoundManager.shared.play(sound: "sfx_nudge", volume: 0.7)
        }
    }

    /// Bunyi "pop" saat hantu muncul dan bunyi tik saat gestur makin dekat selesai.
    private func playPhaseSounds(_ phase: GhostMotion.Phase) {
        if phase != lastPhase {
            if phase == .rising || phase == .growing {
                SoundManager.shared.play(sound: "sfx_appear")
            }
            lastPhase = phase
        }
        let tickStep = Int(gestureProgress * 3)
        if tickStep > lastTickStep, tickStep < 3 {
            SoundManager.shared.play(sound: "sfx_tick", volume: 0.8)
        }
        lastTickStep = tickStep
    }

    private func preloadSounds() {
        let voices = GhostCatalog.all.flatMap { [$0.voice.cheer, $0.voice.jingle] }
        SoundManager.shared.preload(Self.sharedSounds + voices)
    }

    // MARK: - Titik muncul

    /// Tempat hantu untuk `spot` pada frame ini.
    private func placement(for spot: BodySpot, in arView: ARView) -> Placement? {
        guard let anchor, let worldAnchor else { return nil }
        let faceCamera = mode.usesFrontCamera
        let scale = spot.scale(faceCamera: faceCamera)

        if faceCamera && spot.isOnHead {
            return Placement(
                parent: anchor,
                position: spot.headOffset,
                rotation: simd_quatf(angle: spot.headPitch, axis: [1, 0, 0]),
                scale: scale
            )
        }

        if !faceCamera && spot != .palm {
            // Mode dunia: titik tetap di permukaan, diukur dari arah kamera
            let camera = anchor.convert(position: arView.cameraTransform.translation, from: nil)
            var toward = SIMD3<Float>(camera.x, 0, camera.z)
            toward = simd_length(toward) > 0.001 ? simd_normalize(toward) : [0, 0, 1]
            let right = SIMD3<Float>(toward.z, 0, -toward.x)
            let offset = spot.planeOffset
            let position = right * offset.x + SIMD3(0, offset.y, 0) + toward * offset.z
            return Placement(parent: anchor, position: position, rotation: facing(camera, from: position), scale: scale)
        }

        // Titik yang dilacak di ruang dunia: pundak, dada, telapak
        guard let target = trackedTarget(for: spot, in: arView) else { return placement }
        let position: SIMD3<Float>
        if let previous = trackedPosition {
            position = previous + (target - previous) * Self.trackingLerp
        } else {
            position = target
        }
        trackedPosition = position
        let camera = arView.cameraTransform.translation
        return Placement(parent: worldAnchor, position: position, rotation: facing(camera, from: position), scale: scale)
    }

    /// Posisi dunia (alas hantu) untuk titik yang dilacak.
    private func trackedTarget(for spot: BodySpot, in arView: ARView) -> SIMD3<Float>? {
        guard let anchor else { return nil }
        let camera = arView.cameraTransform.translation
        let now = CACurrentMediaTime()
        let fresh = now - vision.time < Self.visionStaleness
        let palm = fresh ? vision.palms.first : nil

        guard mode == .face else {
            // Mode dunia: telapak di depan kamera, atau titik di permukaan bila tangan tidak terlihat
            let surface = anchor.convert(position: BodySpot.palm.planeOffset, to: nil)
            guard let palm else { return surface }
            let reference = camera + simd_normalize(surface - camera) * 0.4
            return worldPoint(at: palm, depthOf: reference, in: arView) ?? surface
        }

        let face = anchor.position(relativeTo: nil)
        guard let faceScreen = arView.project(face), let above = arView.project(face + [0, 0.1, 0]) else { return nil }
        // Piksel per meter di kedalaman wajah, untuk perkiraan posisi tubuh di layar
        let pixelsPerMeter = max(hypot(above.x - faceScreen.x, above.y - faceScreen.y) / 0.1, 1)
        func estimated(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: faceScreen.x + dx * pixelsPerMeter, y: faceScreen.y + dy * pixelsPerMeter)
        }
        let leftShoulder = (fresh ? vision.leftShoulder : nil) ?? estimated(-0.17, 0.22)
        let rightShoulder = (fresh ? vision.rightShoulder : nil) ?? estimated(0.17, 0.22)

        let screenPoint: CGPoint
        var reference = face
        switch spot {
        case let .shoulder(side):
            screenPoint = side == .left ? leftShoulder : rightShoulder
        case .chest:
            screenPoint = CGPoint(
                x: (leftShoulder.x + rightShoulder.x) / 2,
                y: (leftShoulder.y + rightShoulder.y) / 2 + 0.1 * pixelsPerMeter
            )
        default:
            // Telapak sedikit lebih dekat ke kamera daripada wajah
            screenPoint = palm ?? CGPoint(x: rightShoulder.x, y: rightShoulder.y - 0.05 * pixelsPerMeter)
            reference = face + simd_normalize(camera - face) * 0.1
        }
        return worldPoint(at: screenPoint, depthOf: reference, in: arView)
    }

    /// Titik dunia di bawah `screenPoint` pada bidang sejajar layar yang melewati `reference`.
    private func worldPoint(at screenPoint: CGPoint, depthOf reference: SIMD3<Float>, in arView: ARView) -> SIMD3<Float>? {
        guard let ray = arView.ray(through: screenPoint) else { return nil }
        let normal = simd_normalize(reference - arView.cameraTransform.translation)
        let denominator = simd_dot(ray.direction, normal)
        guard abs(denominator) > 0.0001 else { return nil }
        let t = simd_dot(reference - ray.origin, normal) / denominator
        return ray.origin + ray.direction * t
    }

    /// Putaran sumbu Y agar hantu di `position` menghadap `camera` (keduanya di ruang induk yang sama).
    private func facing(_ camera: SIMD3<Float>, from position: SIMD3<Float>) -> simd_quatf {
        simd_quatf(angle: atan2(camera.x - position.x, camera.z - position.z), axis: [0, 1, 0])
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
        let includeBody: Bool = switch spot {
        case .shoulder, .chest: mode == .face
        default: false
        }

        lastVisionTime = now
        isVisionBusy = true
        visionTask = Task { [weak self, handPoseProcessor] in
            let result = await handPoseProcessor.detect(in: pixelBuffer, orientation: orientation, includeBody: includeBody)
            guard let self else { return }
            isVisionBusy = false
            guard !Task.isCancelled else { return }
            let toView = { (point: CGPoint) in point.applying(imageToView) }
            handleVision(result, toView: toView, viewSize: viewSize)
        }
    }

    /// `toView` memetakan titik gambar mentah ke view ternormalisasi (0...1).
    private func handleVision(_ result: VisionFrame, toView: (CGPoint) -> CGPoint, viewSize: CGSize) {
        guard let arView, let motion else { return }
        let now = CACurrentMediaTime()
        let toPoints = { (p: CGPoint) in CGPoint(x: p.x * viewSize.width, y: p.y * viewSize.height) }
        let hands = result.hands.map { HandSample(palm: toView($0.palm), shape: $0.shape) }

        // Bahu diurutkan menurut posisi layar, bukan label Vision (kamera depan dicerminkan)
        let shoulders = [result.body?.leftShoulder, result.body?.rightShoulder]
            .compactMap { $0.map { toPoints(toView($0)) } }
            .sorted { $0.x < $1.x }
        vision = VisionSnapshot(
            palms: hands.map { toPoints($0.palm) },
            leftShoulder: shoulders.count == 2 ? shoulders[0] : nil,
            rightShoulder: shoulders.count == 2 ? shoulders[1] : nil,
            time: now
        )

        // Gestur hanya dibaca saat hantu diam menunggu
        guard motion.phase == .idle else {
            if detector.hasState { resetGestures() }
            return
        }

        let normalized = { (point: CGPoint) in CGPoint(x: point.x / viewSize.width, y: point.y / viewSize.height) }
        let ghostPoint = ghostScreenPoint(in: arView).map(normalized)
        let facePoint = mode == .face && isTargetFound ? anchor.flatMap { arView.project($0.position(relativeTo: nil)) }.map(normalized) : nil
        let expected = story.expectedGesture
        let result = detector.process(
            hands: hands,
            ghostPoint: ghostPoint,
            facePoint: facePoint,
            expected: expected?.isHandGesture == true ? expected : nil,
            canPunch: expected == .punch && motion.canPunch(at: now),
            canClap: motion.canTransform(at: now) && expected != .hideFace,
            at: now
        )

        #if DEBUG
        let point = result.handPoint.map(toPoints)
        if handPoint != point {
            handPoint = point
        }
        if now - lastDebugTime > 0.2 {
            lastDebugTime = now
            let shapes = hands.map { "\($0.shape)" }.joined(separator: ",")
            debugText = "hands: \(shapes.isEmpty ? "-" : shapes)" + (debugText.split(separator: "\n").dropFirst().first.map { "\n" + $0 } ?? "")
        }
        #endif
        if clapProgress != result.clapProgress {
            clapProgress = result.clapProgress
        }
        handGestureProgress = result.gestureProgress
        updateGestureProgress()

        if result.didClap {
            transform()
        } else if let direction = result.punchDirection {
            punch(screenDirection: CGVector(dx: direction.dx * viewSize.width, dy: direction.dy * viewSize.height))
        } else if result.didComplete, let expected {
            completeStoryStep(expected)
        }
    }

    // MARK: - Face gestures

    private func detectFaceGestures(in arView: ARView, motion: GhostMotion, at now: TimeInterval) {
        let expected = story.expectedGesture
        guard motion.phase == .idle, let expected, expected.requiresFace || expected == .holdStill else {
            faceDetector.reset()
            return
        }
        let signals = mode == .face ? arView.session.currentFrame.flatMap(faceSignals(in:)) : nil
        let handsVisible = now - vision.time < Self.visionStaleness && !vision.palms.isEmpty
        let result = faceDetector.process(signals, handsVisible: handsVisible, expected: expected, at: now)

        #if DEBUG
        if let signals, now - lastDebugTime > 0.2 {
            lastDebugTime = now
            let firstLine = debugText.split(separator: "\n").first.map(String.init) ?? "hands: -"
            debugText = firstLine + "\n" + String(
                format: "smile %.2f jaw %.2f brow %.2f puff %.2f tongue %.2f kiss %.2f blink %.2f/%.2f\npitch %.0f° yaw %.0f° roll %.0f°",
                signals.smile, signals.jawOpen, signals.browInnerUp, signals.cheekPuff, signals.tongueOut,
                signals.mouthPucker, signals.blinkLeft, signals.blinkRight,
                signals.pitch * 180 / .pi, signals.yaw * 180 / .pi, signals.roll * 180 / .pi
            )
        }
        #endif

        if result.didComplete {
            completeStoryStep(expected)
        } else if result.progress != gestureProgress {
            gestureProgress = result.progress
        }
    }

    /// Ekspresi dan arah kepala dari anchor wajah. Sudut diukur terhadap gravitasi, jadi tidak
    /// bergantung pada orientasi ponsel.
    private func faceSignals(in frame: ARFrame) -> FaceSignals? {
        guard let face = frame.anchors.lazy.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else { return nil }
        let shapes = face.blendShapes
        func value(_ key: ARFaceAnchor.BlendShapeLocation) -> Float { shapes[key]?.floatValue ?? 0 }
        let forward = simd_normalize(SIMD3(face.transform.columns.2.x, face.transform.columns.2.y, face.transform.columns.2.z))
        let side = simd_normalize(SIMD3(face.transform.columns.0.x, face.transform.columns.0.y, face.transform.columns.0.z))
        return FaceSignals(
            smile: (value(.mouthSmileLeft) + value(.mouthSmileRight)) / 2,
            jawOpen: value(.jawOpen),
            browInnerUp: value(.browInnerUp),
            cheekPuff: value(.cheekPuff),
            tongueOut: value(.tongueOut),
            mouthPucker: value(.mouthPucker),
            blinkLeft: value(.eyeBlinkLeft),
            blinkRight: value(.eyeBlinkRight),
            pitch: asin(min(max(forward.y, -1), 1)),
            yaw: atan2(forward.x, forward.z),
            roll: asin(min(max(side.y, -1), 1))
        )
    }

    private func updateGestureProgress() {
        let progress = story.expectedGesture?.isHandGesture == true ? handGestureProgress : gestureProgress
        if gestureProgress != progress { gestureProgress = progress }
    }

    private func resetGestures() {
        detector.reset()
        faceDetector.reset()
        handGestureProgress = 0
        if handPoint != nil { handPoint = nil }
        if clapProgress != 0 { clapProgress = 0 }
        if gestureProgress != 0 { gestureProgress = 0 }
    }

    // MARK: - Punch

    /// Memukul hantu ke arah `screenDirection` (satuan point layar, sumbu y ke bawah).
    private func punch(screenDirection: CGVector) {
        guard let arView, let ghostRoot, let parent = ghostRoot.parent, let placement, var motion else { return }
        let center = ghostRoot.visualBounds(relativeTo: nil).center
        let worldDirection = worldDirection(for: screenDirection, at: center, in: arView)
        // Arah pukulan di ruang pose: ruang induk tanpa putaran titik muncul
        let direction = placement.rotation.inverse.act(parent.convert(direction: worldDirection, from: nil))

        guard motion.punch(direction: direction, at: CACurrentMediaTime()) else { return }
        self.motion = motion
        detector.reset()
        SoundManager.shared.play(.punch)
        punchCount += 1
        completeStoryStep(.punch)
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
    /// jadi semua model dimuatkan ke kotak yang sama (`GhostSizing`) dengan pivot di tengah-bawah.
    private func makeGhostModel(for ghost: Ghost) async throws -> Entity {
        let model = try await Entity(named: ghost.id)
        let container = Entity()
        container.addChild(model)

        let bounds = model.visualBounds(relativeTo: container)
        let factor = GhostSizing.scale(forExtents: bounds.extents, height: mode.ghostHeight)
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

    /// Memasang wujud baru selagi hantu tersembunyi; ceritanya dimulai dari langkah pertama.
    private func applySwap(_ swap: PendingSwap, motion: inout GhostMotion) {
        switch swap {
        case let .loaded(index, model):
            install(model)
            activeIndex = index
            activeGhost = GhostCatalog.all[index]
            motion.style = activeGhost.style
        case .failed:
            // Tetap memakai wujud lama, tetapi ceritanya diulang
            break
        }
        story = StoryProgress(story: activeGhost.story, faceCamera: mode.usesFrontCamera)
        spot = story.spot
        trackedPosition = nil
    }

    /// Asap di posisi hantu saat ini (sebelum menghilang). Merah darah untuk ganti wujud,
    /// warna kilau hantu untuk pindah titik.
    private func spawnSmoke(now: TimeInterval, tint: SIMD3<Float> = [0.8, 0, 0]) {
        guard let worldAnchor, let ghostRoot else { return }
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
            start: .single(.init(red: CGFloat(tint.x), green: CGFloat(tint.y), blue: CGFloat(tint.z), alpha: 0.8)),
            end: .single(.init(red: CGFloat(tint.x * 0.4), green: CGFloat(tint.y * 0.4), blue: CGFloat(tint.z * 0.4), alpha: 0.0))
        )
        particles.mainEmitter.isLightingEnabled = false

        let smoke = Entity()
        smoke.components.set(particles)
        worldAnchor.addChild(smoke)
        smoke.setPosition(ghostRoot.visualBounds(relativeTo: nil).center, relativeTo: nil)
        self.smoke = smoke
        smokeRemovalTime = now + Self.smokeLifetime
    }

    /// Ledakan kilau berwarna khas hantu saat gestur berhasil; kembang api besar di akhir cerita.
    private func spawnBurst(finale: Bool, now: TimeInterval) {
        guard let worldAnchor, let ghostRoot else { return }
        burst?.removeFromParent()

        let sizeFactor: Float = mode == .world ? 2.5 : 1
        let glow = activeGhost.glow
        var particles = ParticleEmitterComponent()
        particles.emitterShape = .sphere
        particles.birthLocation = .surface
        particles.birthDirection = .normal
        particles.emitterShapeSize = SIMD3(repeating: 0.02 * sizeFactor)
        particles.speed = (finale ? 0.6 : 0.35) * sizeFactor
        particles.speedVariation = 0.15 * sizeFactor
        particles.isEmitting = false
        particles.burstCount = finale ? 400 : 140
        particles.mainEmitter.birthRate = 0
        particles.mainEmitter.lifeSpan = finale ? 1.6 : 1.0
        particles.mainEmitter.size = 0.006 * sizeFactor
        particles.mainEmitter.sizeVariation = 0.004 * sizeFactor
        particles.mainEmitter.acceleration = [0, -0.4 * sizeFactor, 0]
        particles.mainEmitter.dampingFactor = 2
        particles.mainEmitter.isLightingEnabled = false
        particles.mainEmitter.color = .evolving(
            start: .single(.init(red: CGFloat(glow.x), green: CGFloat(glow.y), blue: CGFloat(glow.z), alpha: 1)),
            end: .single(.init(red: 1, green: 1, blue: 1, alpha: 0))
        )
        particles.burst()

        let burst = Entity()
        burst.components.set(particles)
        worldAnchor.addChild(burst)
        burst.setPosition(ghostRoot.visualBounds(relativeTo: nil).center, relativeTo: nil)
        self.burst = burst
        burstRemovalTime = now + 2.5
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
            // Ganti wujud yang terputus dibatalkan; cerita wujud ini dimulai lagi
            loadTask?.cancel()
            pendingSwap = nil
            isTransforming = false
            story = StoryProgress(story: activeGhost.story, faceCamera: mode.usesFrontCamera)
            spot = story.spot
            resetGestures()
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
