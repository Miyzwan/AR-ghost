//
//  GhostMotion.swift
//  AR2
//

import Foundation
import simd

/// Pose hantu relatif terhadap anchor.
struct GhostPose: Equatable {
    var position: SIMD3<Float>
    var rotation: simd_quatf
    /// Pengali skala terhadap ukuran normal hantu (1 = normal, 0 = tersembunyi).
    var scale: Float
}

/// State machine animasi hantu. Murni (tanpa RealityKit) supaya bisa diuji.
/// Semua timer berbasis timestamp, jadi tidak ada callback yang tertinggal setelah layar AR ditutup.
struct GhostMotion {
    struct Layout {
        var startPosition: SIMD3<Float>
        var restPosition: SIMD3<Float>
        var pitch: Float
        var knockDistance: Float

        /// Mode wajah: hantu muncul dari belakang kepala lalu diam di atas kepala.
        static let face = Layout(
            startPosition: [0, 0, -0.1],
            restPosition: [0, 0.20, -0.05],
            pitch: 19 * .pi / 180,
            knockDistance: 0.35
        )

        /// Mode dunia: hantu naik dari permukaan datar lalu melayang di atasnya.
        static let world = Layout(
            startPosition: [0, 0, 0],
            restPosition: [0, 0.30, 0],
            pitch: 0,
            knockDistance: 0.6
        )
    }

    enum Phase: Equatable {
        case waiting
        case rising
        case idle
        case knockedAway   // Terlempar karena dipukul
        case knockedPause  // Diam sebentar di posisi terlempar
        case returning     // Kembali melayang ke posisi semula
        case shrinking     // Berubah wujud: tersedot ke dalam asap
        case hidden        // Menunggu model baru selesai dimuat
        case growing       // Muncul kembali dari asap
    }

    static let waitDuration: TimeInterval = 1.0
    static let riseDuration: TimeInterval = 2.0
    static let knockDuration: TimeInterval = 0.5
    static let knockPauseDuration: TimeInterval = 1.0
    static let returnDuration: TimeInterval = 1.5
    static let punchCooldown: TimeInterval = 0.5
    static let shrinkDuration: TimeInterval = 1.0
    static let growDuration: TimeInterval = 1.0
    static let transformCooldown: TimeInterval = 3.0

    let layout: Layout
    private(set) var phase: Phase = .waiting
    private(set) var knockDirection: SIMD3<Float> = .zero
    private var phaseStart: TimeInterval
    private var punchReadyAt: TimeInterval = 0
    private var transformReadyAt: TimeInterval = 0

    init(layout: Layout, startTime: TimeInterval) {
        self.layout = layout
        self.phaseStart = startTime
    }

    func canPunch(at now: TimeInterval) -> Bool {
        phase == .idle && now >= punchReadyAt
    }

    func canTransform(at now: TimeInterval) -> Bool {
        phase == .idle && now >= transformReadyAt
    }

    /// Memukul hantu ke arah `direction` (ruang anchor). Mengembalikan `false` jika sedang tidak bisa dipukul.
    @discardableResult
    mutating func punch(direction: SIMD3<Float>, at now: TimeInterval) -> Bool {
        guard canPunch(at: now), simd_length(direction) > 0.0001 else { return false }
        knockDirection = simd_normalize(direction)
        enter(.knockedAway, at: now)
        return true
    }

    /// Memulai transformasi. Hantu menyusut lalu tetap tersembunyi sampai `reveal(at:)` dipanggil.
    @discardableResult
    mutating func beginTransform(at now: TimeInterval) -> Bool {
        guard canTransform(at: now) else { return false }
        enter(.shrinking, at: now)
        return true
    }

    /// Dipanggil setelah model baru terpasang (atau gagal dimuat) selama fase `.hidden`.
    mutating func reveal(at now: TimeInterval) {
        guard phase == .hidden else { return }
        enter(.growing, at: now)
    }

    /// Memajukan fase sesuai waktu lalu menghitung pose untuk frame ini.
    /// `facingYaw` memutar hantu agar menghadap kamera (0 pada mode wajah).
    mutating func update(at now: TimeInterval, facingYaw: Float = 0) -> GhostPose {
        advancePhase(at: now)

        let elapsed = now - phaseStart
        // Goyangan kiri-kanan yang terus-menerus
        let shake = Float(sin(now * 2 * .pi)) * (15 * .pi / 180)
        let yaw = facingYaw + shake
        let rest = layout.restPosition

        switch phase {
        case .waiting:
            return GhostPose(position: layout.startPosition, rotation: upright(yaw: yaw), scale: 0)

        case .rising:
            let p = progress(elapsed, Self.riseDuration)
            let eased = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
            let position = layout.startPosition + (rest - layout.startPosition) * eased
            // Muncul perlahan di awal perjalanan naik
            return GhostPose(position: position, rotation: upright(yaw: yaw), scale: min(p / 0.3, 1))

        case .idle:
            return GhostPose(position: rest, rotation: upright(yaw: yaw), scale: 1)

        case .knockedAway, .knockedPause:
            let p = phase == .knockedPause ? 1 : progress(elapsed, Self.knockDuration)
            // Easing: cepat di awal lalu melambat (efek terlempar)
            let eased = 1 - pow(1 - p, 3)
            let position = rest + knockDirection * layout.knockDistance * eased
            // Berputar lucu 2x di sumbu pukulan
            let tumbleAxis = simd_normalize(SIMD3<Float>(-knockDirection.y, knockDirection.x, 0.3))
            let tumble = simd_quatf(angle: eased * .pi * 4, axis: tumbleAxis)
            // Membesar saat kaget, lalu kembali normal
            let scale = 1 + 0.3 * sin(eased * .pi)
            return GhostPose(position: position, rotation: tumble * upright(yaw: yaw), scale: scale)

        case .returning:
            let p = progress(elapsed, Self.returnDuration)
            // Cubic ease-out: monoton naik dari 0 ke 1, tidak pernah overshoot
            let baseEased = 1 - pow(1 - p, 3)
            // Wobble kecil yang meluruh menjelang akhir
            let wobbleDecay = (1 - p) * (1 - p)
            let wobbleOffset = wobbleDecay * 0.08 * sin(p * .pi * 5)
            let knockedPosition = rest + knockDirection * layout.knockDistance
            let mainPosition = knockedPosition + (rest - knockedPosition) * baseEased
            let wobbleAngle = wobbleDecay * 0.4 * sin(Float(elapsed) * 10)
            let scale = 1 + wobbleDecay * 0.12 * sin(p * .pi * 4)
            return GhostPose(
                position: mainPosition + knockDirection * wobbleOffset,
                rotation: upright(yaw: yaw + wobbleAngle),
                scale: scale
            )

        case .shrinking:
            let p = progress(elapsed, Self.shrinkDuration)
            // Berputar makin cepat selagi tersedot asap
            let spin = Float(elapsed) * 15
            return GhostPose(position: rest, rotation: upright(yaw: yaw + spin), scale: 1 - p * p)

        case .hidden:
            return GhostPose(position: rest, rotation: upright(yaw: yaw), scale: 0)

        case .growing:
            let p = progress(elapsed, Self.growDuration)
            let bounce = sin(p * .pi * 2.5) * exp(-p * 3)
            return GhostPose(position: rest, rotation: upright(yaw: yaw), scale: p + bounce * 0.3)
        }
    }

    // MARK: - Private

    private mutating func enter(_ newPhase: Phase, at time: TimeInterval) {
        phase = newPhase
        phaseStart = time
    }

    /// Fase berikutnya beserta durasi fase saat ini; `nil` jika fase menunggu aksi dari luar.
    private func nextStep() -> (phase: Phase, after: TimeInterval)? {
        switch phase {
        case .waiting: (.rising, Self.waitDuration)
        case .rising: (.idle, Self.riseDuration)
        case .knockedAway: (.knockedPause, Self.knockDuration)
        case .knockedPause: (.returning, Self.knockPauseDuration)
        case .returning: (.idle, Self.returnDuration)
        case .shrinking: (.hidden, Self.shrinkDuration)
        case .growing: (.idle, Self.growDuration)
        case .idle, .hidden: nil
        }
    }

    private mutating func advancePhase(at now: TimeInterval) {
        while let step = nextStep(), now - phaseStart >= step.after {
            let end = phaseStart + step.after
            if phase == .returning { punchReadyAt = end + Self.punchCooldown }
            if phase == .growing { transformReadyAt = end + Self.transformCooldown }
            enter(step.phase, at: end)
        }
    }

    private func progress(_ elapsed: TimeInterval, _ duration: TimeInterval) -> Float {
        Float(min(max(elapsed / duration, 0), 1))
    }

    private func upright(yaw: Float) -> simd_quatf {
        simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: layout.pitch, axis: [1, 0, 0])
    }
}
