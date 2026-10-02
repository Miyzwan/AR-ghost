//
//  GhostMotion.swift
//  AR2
//

import Foundation
import simd

/// Pose hantu relatif terhadap titik muncul (`BodySpot`).
struct GhostPose: Equatable {
    var position: SIMD3<Float>
    var rotation: simd_quatf
    /// Pengali skala terhadap ukuran normal hantu (1 = normal, 0 = tersembunyi).
    var scale: Float
    /// Regangan tinggi (squash and stretch): >1 memanjang, <1 memipih. Lebar diatur pemanggil
    /// sebesar 1/√stretch supaya volumenya terasa tetap.
    var stretch: Float = 1
}

/// State machine animasi hantu. Murni (tanpa RealityKit) supaya bisa diuji.
/// Semua timer berbasis timestamp, jadi tidak ada callback yang tertinggal setelah layar AR ditutup.
struct GhostMotion {
    /// Ukuran gerak per mode. Pose dihitung relatif terhadap titik muncul (`BodySpot`);
    /// pemanggil yang menempatkan, memutar, dan menskalakan titik itu.
    struct Layout {
        /// Posisi awal relatif titik muncul, sebelum hantu naik.
        var riseOffset: SIMD3<Float>
        var knockDistance: Float
        /// Tinggi hantu (meter), pengali offset gerak khas.
        var height: Float

        /// Mode wajah: hantu muncul dari belakang kepala lalu naik.
        static let face = Layout(riseOffset: [0, -0.2, -0.05], knockDistance: 0.35, height: 0.2)

        /// Mode dunia: hantu naik dari permukaan datar lalu melayang di atasnya.
        static let world = Layout(riseOffset: [0, -0.3, 0], knockDistance: 0.6, height: 0.45)
    }

    enum Phase: Equatable {
        case waiting
        case rising
        case idle
        case knockedAway   // Terlempar karena dipukul
        case knockedPause  // Diam sebentar di posisi terlempar
        case returning     // Kembali melayang ke posisi semula
        case celebrating   // Senang karena gestur pengguna benar
        case nudging       // Mencari perhatian saat pengguna lama tidak bergerak
        case shrinking     // Menghilang ke dalam asap (ganti wujud atau pindah titik)
        case hidden        // Menunggu model baru dimuat atau titik baru dipasang
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
    static let celebrateDuration: TimeInterval = 0.9
    static let nudgeDuration: TimeInterval = 0.8
    static let transformCooldown: TimeInterval = 3.0

    let layout: Layout
    /// Gerak khas wujud yang sedang tampil; diganti saat model ditukar.
    var style: MotionStyle
    /// 0...1: seberapa dekat pengguna dengan gestur yang diminta. Hantu condong, membesar,
    /// dan bergetar penuh harap.
    var anticipation: Float = 0
    private(set) var phase: Phase = .waiting
    private(set) var knockDirection: SIMD3<Float> = .zero
    private var phaseStart: TimeInterval
    private var punchReadyAt: TimeInterval = 0
    private var transformReadyAt: TimeInterval = 0

    init(layout: Layout, style: MotionStyle, startTime: TimeInterval) {
        self.layout = layout
        self.style = style
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

    /// Ganti wujud: hantu menyusut lalu tetap tersembunyi sampai `reveal(at:)` dipanggil.
    @discardableResult
    mutating func beginTransform(at now: TimeInterval) -> Bool {
        guard canTransform(at: now) else { return false }
        enter(.shrinking, at: now)
        return true
    }

    /// Pindah titik: sama seperti ganti wujud, tetapi tanpa jeda tepuk.
    @discardableResult
    mutating func beginRelocation(at now: TimeInterval) -> Bool {
        guard phase == .idle else { return false }
        enter(.shrinking, at: now)
        return true
    }

    /// Reaksi senang singkat saat langkah cerita berhasil.
    @discardableResult
    mutating func celebrate(at now: TimeInterval) -> Bool {
        guard phase == .idle else { return false }
        enter(.celebrating, at: now)
        return true
    }

    /// Dua loncatan kecil sambil bergoyang, untuk mengingatkan pengguna.
    @discardableResult
    mutating func nudge(at now: TimeInterval) -> Bool {
        guard phase == .idle else { return false }
        enter(.nudging, at: now)
        return true
    }

    /// Dipanggil setelah model baru atau titik baru terpasang selama fase `.hidden`.
    mutating func reveal(at now: TimeInterval) {
        guard phase == .hidden else { return }
        enter(.growing, at: now)
    }

    /// Memajukan fase sesuai waktu lalu menghitung pose untuk frame ini, relatif terhadap titik muncul.
    mutating func update(at now: TimeInterval) -> GhostPose {
        advancePhase(at: now)

        let elapsed = now - phaseStart
        // Gerak khas wujud ini, berjalan terus di semua fase
        let stylePose = style.pose(at: now)
        let drift = stylePose.offset * layout.height
        let sway = stylePose.rotation
        let styleScale = stylePose.scale

        switch phase {
        case .waiting:
            return GhostPose(position: layout.riseOffset, rotation: sway, scale: 0)

        case .rising:
            let p = progress(elapsed, Self.riseDuration)
            let eased = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
            let position = layout.riseOffset * (1 - eased) + drift * eased
            // Muncul perlahan di awal perjalanan naik, memanjang selagi melesat
            return GhostPose(position: position, rotation: sway, scale: min(p / 0.3, 1) * styleScale, stretch: 1 + 0.2 * sin(p * .pi))

        case .idle:
            // Penuh harap saat gestur hampir selesai: condong ke penonton, membesar, dan bergetar
            let a = min(max(anticipation, 0), 1)
            let lean = SIMD3<Float>(0, 0.05, 0.15) * layout.height * a
            let tremble = simd_quatf(angle: sin(Float(now) * 45) * 0.06 * a, axis: [0, 0, 1])
            return GhostPose(position: drift + lean, rotation: tremble * sway, scale: styleScale * (1 + 0.15 * a), stretch: 1 + 0.1 * a)

        case .celebrating:
            let reaction = style.celebration(progress(elapsed, Self.celebrateDuration))
            return GhostPose(
                position: drift + reaction.pose.offset * layout.height,
                rotation: reaction.pose.rotation * sway,
                scale: styleScale * reaction.pose.scale,
                stretch: reaction.stretch
            )

        case .nudging:
            let p = progress(elapsed, Self.nudgeDuration)
            // Dua loncatan kecil sambil bergoyang: "hei, aku di sini!"
            let hop = abs(sin(p * 2 * .pi)) * 0.18 * layout.height
            let wiggle = simd_quatf(angle: 0.35 * sin(p * 4 * .pi) * (1 - p), axis: [0, 0, 1])
            return GhostPose(position: drift + [0, hop, 0], rotation: wiggle * sway, scale: styleScale, stretch: 1 + 0.15 * cos(p * 4 * .pi) * (1 - p))

        case .knockedAway, .knockedPause:
            let p = phase == .knockedPause ? 1 : progress(elapsed, Self.knockDuration)
            // Easing: cepat di awal lalu melambat (efek terlempar)
            let eased = 1 - pow(1 - p, 3)
            let position = drift + knockDirection * layout.knockDistance * eased
            // Berputar lucu 2x di sumbu pukulan
            let tumbleAxis = simd_normalize(SIMD3<Float>(-knockDirection.y, knockDirection.x, 0.3))
            let tumble = simd_quatf(angle: eased * .pi * 4, axis: tumbleAxis)
            // Membesar saat kaget, lalu kembali normal
            let scale = 1 + 0.3 * sin(eased * .pi)
            return GhostPose(position: position, rotation: tumble * sway, scale: scale)

        case .returning:
            let p = progress(elapsed, Self.returnDuration)
            // Cubic ease-out: monoton naik dari 0 ke 1, tidak pernah overshoot
            let baseEased = 1 - pow(1 - p, 3)
            // Wobble kecil yang meluruh menjelang akhir
            let wobbleDecay = (1 - p) * (1 - p)
            let wobbleOffset = wobbleDecay * 0.08 * sin(p * .pi * 5)
            let knockedPosition = drift + knockDirection * layout.knockDistance
            let mainPosition = knockedPosition + (drift - knockedPosition) * baseEased
            let wobbleAngle = wobbleDecay * 0.4 * sin(Float(elapsed) * 10)
            let scale = 1 + wobbleDecay * 0.12 * sin(p * .pi * 4)
            return GhostPose(
                position: mainPosition + knockDirection * wobbleOffset,
                rotation: simd_quatf(angle: wobbleAngle, axis: [0, 1, 0]) * sway,
                scale: scale
            )

        case .shrinking:
            let p = progress(elapsed, Self.shrinkDuration)
            // Berputar makin cepat selagi tersedot asap
            let spin = simd_quatf(angle: Float(elapsed) * 15, axis: [0, 1, 0])
            // Memanjang tipis seperti tersedot ke atas
            return GhostPose(position: drift, rotation: spin * sway, scale: 1 - p * p, stretch: 1 + 0.6 * p)

        case .hidden:
            return GhostPose(position: drift, rotation: sway, scale: 0)

        case .growing:
            let p = progress(elapsed, Self.growDuration)
            let bounce = sin(p * .pi * 2.5) * exp(-p * 3)
            // Memantul seperti jeli saat muncul
            return GhostPose(position: drift, rotation: sway, scale: (p + bounce * 0.3) * styleScale, stretch: 1 + 0.4 * bounce)
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
        case .celebrating: (.idle, Self.celebrateDuration)
        case .nudging: (.idle, Self.nudgeDuration)
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
}
