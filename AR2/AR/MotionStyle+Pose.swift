//
//  MotionStyle+Pose.swift
//  AR2
//

import Foundation
import simd

/// Pose gerak khas pada satu waktu. `offset` dalam satuan tinggi hantu, supaya geraknya
/// sebanding di atas kepala (kecil) maupun di lantai (besar).
nonisolated struct StylePose {
    var offset: SIMD3<Float> = .zero
    var rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
    var scale: Float = 1
}

nonisolated extension MotionStyle {
    /// Fungsi murni dari waktu ke pose. Sumbu: +X kanan, +Y atas, +Z ke arah penonton.
    func pose(at time: TimeInterval) -> StylePose {
        let t = Float(time.truncatingRemainder(dividingBy: 3600))
        switch self {
        case .still:
            return StylePose()

        case .bob:
            // Melayang naik-turun sambil memiringkan kepala, seperti melamun
            return StylePose(
                offset: [0, 0.06 * wave(t, period: 2.4), 0],
                rotation: euler(yaw: 0.15 * wave(t, period: 6), roll: 0.08 * wave(t, period: 4.8))
            )

        case .jitter:
            // Gemetar marah, lalu tiap 3 detik menerjang ke arah penonton
            let lunge = pulse(t, every: 3, length: 0.5)
            return StylePose(
                offset: [0.02 * wave(t, period: 1 / 7), 0.015 * wave(t, period: 1 / 9.3), 0.25 * lunge],
                rotation: euler(pitch: 0.2 * lunge, yaw: 0.05 * wave(t, period: 1 / 6)),
                scale: 1 + 0.1 * lunge
            )

        case .hugSway:
            // Condong maju-mundur seperti mau memeluk
            let lean = wave(t, period: 2.2)
            return StylePose(
                offset: [0, 0.02 * wave(t, period: 1.1), 0.12 * lean],
                rotation: euler(pitch: 0.18 * lean),
                scale: 1 + 0.04 * lean
            )

        case .wave:
            // Gerak ombak: berguling, naik-turun, dan bergeser dengan fase berbeda
            return StylePose(
                offset: [0.06 * wave(t, period: 3.6), 0.05 * wave(t, period: 1.8, phase: .pi / 2), 0],
                rotation: euler(roll: 0.25 * wave(t, period: 1.8))
            )

        case .nap:
            // Bernapas pelan, tiap 4 detik loncat kecil seperti kucing yang kaget
            return StylePose(
                offset: [0, 0.15 * pulse(t, every: 4, length: 0.35), 0],
                scale: 1 + 0.03 * wave(t, period: 3)
            )

        case .sneak:
            // Mengendap kanan-kiri rendah, berhenti untuk mengintip sambil miring
            let u = t.truncatingRemainder(dividingBy: 4)
            let x: Float
            var roll: Float = 0
            var yaw: Float = 0
            switch u {
            case ..<1.2:
                x = -0.18 + 0.36 * smoothstep(u / 1.2)
                yaw = 0.4
            case ..<2:
                x = 0.18
                roll = 0.3 * sin((u - 1.2) / 0.8 * .pi)
            case ..<3.2:
                x = 0.18 - 0.36 * smoothstep((u - 2) / 1.2)
                yaw = -0.4
            default:
                x = -0.18
                roll = -0.3 * sin((u - 3.2) / 0.8 * .pi)
            }
            return StylePose(offset: [x, -0.05, 0], rotation: euler(yaw: yaw, roll: roll))

        case .orbit:
            // Terbang memutar, condong ke arah terbang. Hadapnya dibatasi ±57° supaya wajahnya
            // tetap terlihat, tidak membelakangi penonton di sisi belakang lingkaran.
            let angle = t / 3.2 * 2 * .pi
            return StylePose(
                offset: [0.5 * sin(angle), 0.05 * sin(2 * angle), 0.5 * cos(angle)],
                rotation: euler(yaw: cos(angle), roll: -0.3)
            )

        case .glideBow:
            // Meluncur pelan dan tiap 5 detik membungkuk sopan
            let bow = pulse(t, every: 5, length: 1.2)
            return StylePose(
                offset: [0.1 * wave(t, period: 6), 0.04 * wave(t, period: 3), 0],
                rotation: euler(pitch: 0.5 * bow)
            )

        case .rocking:
            // Terayun seperti kapal di laut
            return StylePose(
                offset: [0, 0.04 * wave(t, period: 1.3), 0],
                rotation: euler(pitch: 0.1 * wave(t, period: 5.2, phase: 1), roll: 0.22 * wave(t, period: 2.6))
            )

        case .pixelStep:
            // 8-bit: loncat di antara 4 posisi, 2 kali per detik, tanpa transisi halus
            let step = Int(floor(t * 2)) % 4
            let positions: [SIMD3<Float>] = [[-0.1, 0, 0], [0, 0.08, 0], [0.1, 0, 0], [0, 0.08, 0]]
            let yaws: [Float] = [0, .pi / 4, 0, -.pi / 4]
            return StylePose(offset: positions[step], rotation: euler(yaw: yaws[step]))
        }
    }

    /// Reaksi senang saat gestur berhasil, `progress` 0...1. `stretch` adalah regangan tinggi
    /// (squash and stretch): >1 memanjang, <1 memipih, volume dijaga oleh pemanggil.
    /// Di `progress` 1 pose kembali netral supaya tidak meloncat ke gerak khas.
    func celebration(_ progress: Float) -> (pose: StylePose, stretch: Float) {
        let p = min(max(progress, 0), 1)
        let arc = sin(p * .pi)
        // Memipih sebelum melompat, memanjang di udara, memipih lagi saat mendarat
        let hopStretch: Float = switch p {
        case ..<0.15: 1 - 0.3 * sin(p / 0.15 * .pi)
        case 0.85...: 1 - 0.25 * sin((p - 0.85) / 0.15 * .pi)
        default: 1.15
        }

        switch self {
        case .jitter:
            // Marah tapi puas: gemetar keras sambil membesar
            return (StylePose(
                offset: [0.06 * sin(p * 70) * arc, 0.1 * arc, 0],
                rotation: euler(yaw: 0.3 * sin(p * 55) * arc),
                scale: 1 + 0.3 * arc
            ), 1)
        case .hugSway:
            // Mencondongkan badan jauh ke penonton, seperti memeluk
            return (StylePose(offset: [0, 0.1 * arc, 0.4 * arc], rotation: euler(pitch: 0.5 * arc), scale: 1 + 0.15 * arc), 1 - 0.15 * arc)
        case .wave:
            // Berguling dua kali di udara
            return (StylePose(offset: [0, 0.3 * arc, 0], rotation: euler(roll: p * 4 * .pi)), hopStretch)
        case .nap:
            // Menggeliat seperti kucing, lalu meloncat
            let stretch = p < 0.5 ? 1 + 0.45 * sin(p / 0.5 * .pi) : hopStretch
            let hop: Float = p < 0.5 ? 0 : 0.35 * sin((p - 0.5) / 0.5 * .pi)
            return (StylePose(offset: [0, hop, 0]), stretch)
        case .sneak:
            // Berputar cepat sambil berkedip hilang-muncul
            return (StylePose(rotation: euler(yaw: p * 6 * .pi), scale: 1 - 0.5 * abs(sin(p * 3 * .pi))), 1)
        case .orbit:
            // Salto penuh di udara
            return (StylePose(offset: [0, 0.4 * arc, 0.2 * sin(p * 2 * .pi)], rotation: euler(pitch: p * 2 * .pi)), 1)
        case .glideBow:
            // Membungkuk dalam-dalam dengan sopan
            return (StylePose(offset: [0, -0.05 * arc, 0.1 * arc], rotation: euler(pitch: 0.9 * arc)), 1)
        case .rocking:
            // Terombang-ambing ombak besar
            return (StylePose(offset: [0, 0.25 * arc, 0], rotation: euler(roll: 0.6 * sin(p * 4 * .pi))), hopStretch)
        case .pixelStep:
            // Loncat 8-bit: tinggi dan putaran patah-patah per 90°
            let q = floor(p * 5) / 5
            return (StylePose(offset: [0, 0.4 * sin(q * .pi), 0], rotation: euler(yaw: floor(q * 4) * .pi / 2)), 1)
        case .bob, .still:
            // Loncat sambil berputar satu kali
            return (StylePose(offset: [0, 0.3 * arc, 0], rotation: euler(yaw: p * 2 * .pi)), hopStretch)
        }
    }

    // MARK: - Bantuan

    private func wave(_ t: Float, period: Float, phase: Float = 0) -> Float {
        sin(t / period * 2 * .pi + phase)
    }

    /// 0 di luar denyut; naik ke 1 lalu turun lagi selama `length` detik di awal tiap `every` detik.
    private func pulse(_ t: Float, every: Float, length: Float) -> Float {
        let u = t.truncatingRemainder(dividingBy: every)
        return u < length ? sin(u / length * .pi) : 0
    }

    private func smoothstep(_ x: Float) -> Float {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    private func euler(pitch: Float = 0, yaw: Float = 0, roll: Float = 0) -> simd_quatf {
        simd_quatf(angle: yaw, axis: [0, 1, 0])
            * simd_quatf(angle: pitch, axis: [1, 0, 0])
            * simd_quatf(angle: roll, axis: [0, 0, 1])
    }
}
