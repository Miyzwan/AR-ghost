//
//  GhostStory.swift
//  AR2
//

import Foundation

/// Gerakan pengguna yang diminta satu langkah cerita.
enum GhostGesture: String, CaseIterable {
    // Wajah (blendshape dan rotasi kepala ARFaceAnchor)
    case smile, wink, mouthOpen, eyebrowRaise, cheekPuff, tongueOut, kiss, nod, shakeHead, tiltHead
    // Tangan (Vision)
    case openPalm, fist, peace, point, thumbsUp, pinch, wave, touchGhost, hideFace, punch
    // Kepala diam dan tangan tidak terlihat
    case holdStill

    /// Hanya bisa dibaca kamera depan TrueDepth.
    var requiresFace: Bool {
        switch self {
        case .smile, .wink, .mouthOpen, .eyebrowRaise, .cheekPuff, .tongueOut, .kiss, .nod, .shakeHead, .tiltHead: true
        default: false
        }
    }

    /// Dibaca dari tangan oleh `HandGestureDetector`; sisanya oleh `FaceGestureDetector`.
    var isHandGesture: Bool {
        !requiresFace && self != .holdStill
    }

    /// Bentuk tangan yang harus ditahan, untuk gestur berbasis bentuk.
    var handShape: HandShape? {
        switch self {
        case .openPalm: .open
        case .fist: .fist
        case .peace: .peace
        case .point: .point
        case .thumbsUp: .thumbsUp
        case .pinch: .pinch
        default: nil
        }
    }

    /// Pengganti di mode lantai/meja, saat kamera belakang tidak melihat wajah pengguna.
    var worldFallback: GhostGesture {
        switch self {
        case .smile, .nod: .thumbsUp
        case .wink, .tongueOut: .peace
        case .mouthOpen, .eyebrowRaise: .openPalm
        case .cheekPuff, .shakeHead: .wave
        case .kiss: .pinch
        case .tiltHead: .point
        case .hideFace: .fist
        default: self
        }
    }

    /// Gestur yang benar-benar diminta, sesuai kamera yang dipakai.
    func resolved(faceCamera: Bool) -> GhostGesture {
        faceCamera || (!requiresFace && self != .hideFace) ? self : worldFallback
    }

    /// Nama SF Symbol untuk chip petunjuk.
    var symbol: String {
        switch self {
        case .smile: "face.smiling"
        case .wink: "eye.half.closed"
        case .mouthOpen: "mouth.fill"
        case .eyebrowRaise: "eyebrow"
        case .cheekPuff: "wind"
        case .tongueOut: "face.smiling.inverse"
        case .kiss: "heart.fill"
        case .nod: "arrow.up.and.down"
        case .shakeHead: "arrow.left.and.right"
        case .tiltHead: "rotate.right"
        case .openPalm: "hand.raised.fill"
        case .fist: "figure.boxing"
        case .peace: "peacesign"
        case .point: "hand.point.up.left.fill"
        case .thumbsUp: "hand.thumbsup.fill"
        case .pinch: "hand.pinch.fill"
        case .wave: "hand.wave.fill"
        case .touchGhost: "hand.tap.fill"
        case .hideFace: "eye.slash.fill"
        case .punch: "burst.fill"
        case .holdStill: "moon.zzz.fill"
        }
    }

    /// Perintah singkat di gelembung cerita: kata kerja yang langsung bisa dilakukan.
    var instruction: LocalizedStringResource {
        switch self {
        case .smile: "Smile"
        case .wink: "Wink one eye"
        case .mouthOpen: "Open your mouth"
        case .eyebrowRaise: "Raise your eyebrows"
        case .cheekPuff: "Puff your cheeks"
        case .tongueOut: "Stick your tongue out"
        case .kiss: "Blow a kiss"
        case .nod: "Nod your head"
        case .shakeHead: "Shake your head"
        case .tiltHead: "Tilt your head"
        case .openPalm: "Open your hand"
        case .fist: "Make a fist"
        case .peace: "Peace sign"
        case .point: "Point a finger"
        case .thumbsUp: "Thumbs up"
        case .pinch: "Pinch your fingers"
        case .wave: "Wave your hand"
        case .touchGhost: "Touch the ghost"
        case .hideFace: "Cover your face"
        case .punch: "Punch the ghost!"
        case .holdStill: "Don't move"
        }
    }
}

/// Tempat hantu muncul di tubuh pengguna. Kiri/kanan mengikuti layar.
enum BodySpot: Hashable {
    enum Side: Hashable {
        case left, right

        /// -1 untuk kiri, +1 untuk kanan.
        var sign: Float { self == .left ? -1 : 1 }
    }

    case aboveHead
    case besideHead(Side)
    case inFrontOfFace
    case peekBehindHead
    case shoulder(Side)
    case chest
    case palm

    /// Menempel pada anchor wajah (ikut gerakan kepala) di mode wajah.
    var isOnHead: Bool {
        switch self {
        case .aboveHead, .besideHead, .inFrontOfFace, .peekBehindHead: true
        case .shoulder, .chest, .palm: false
        }
    }

    /// Pengali tinggi hantu: kecil di pundak dan telapak, normal di atas kepala.
    func scale(faceCamera: Bool) -> Float {
        switch self {
        case .aboveHead: 1
        case .besideHead, .shoulder: 0.6
        case .palm: faceCamera ? 0.6 : 0.3
        case .inFrontOfFace: 0.5
        case .peekBehindHead: 0.7
        case .chest: 0.7
        }
    }

    /// Mode wajah: posisi di ruang anchor wajah (meter; +Y atas, +Z ke arah kamera).
    var headOffset: SIMD3<Float> {
        switch self {
        case .aboveHead: [0, 0.20, -0.05]
        case let .besideHead(side): [side.sign * 0.17, -0.04, -0.02]
        case .inFrontOfFace: [0.09, -0.12, 0.10]
        case .peekBehindHead: [-0.16, 0.04, -0.10]
        case .shoulder, .chest, .palm: .zero
        }
    }

    /// Kemiringan ke depan di atas kepala, supaya hantu terlihat dari kamera depan.
    var headPitch: Float {
        self == .aboveHead ? 19 * .pi / 180 : 0
    }

    /// Mode dunia: posisi relatif titik anchor permukaan dalam (kanan, atas, arah kamera), meter.
    var planeOffset: SIMD3<Float> {
        switch self {
        case .aboveHead: [0, 0.30, 0]
        case let .besideHead(side): [side.sign * 0.35, 0.30, -0.10]
        case .inFrontOfFace: [0.05, 0.12, 0.30]
        case .peekBehindHead: [-0.20, 0.15, -0.35]
        case let .shoulder(side): [side.sign * 0.30, 0.12, 0]
        case .chest: [0, 0.05, 0.12]
        case .palm: [0.15, 0.25, 0.20]
        }
    }
}

/// Gerak khas tiap hantu saat melayang. Lihat `MotionStyle.pose(at:)`.
/// Nonisolated karena Home hero memanggilnya dari thread render SceneKit.
nonisolated enum MotionStyle: CaseIterable, Sendable {
    case bob, jitter, hugSway, wave, nap, sneak, orbit, glideBow, rocking, pixelStep
    /// Tanpa gerak (Reduce Motion dan unit test).
    case still
}

struct StoryStep {
    let spot: BodySpot
    let gesture: GhostGesture
    /// Kalimat hantu untuk langkah ini.
    let line: LocalizedStringResource
    /// Seruan singkat yang meletup di layar saat gestur berhasil.
    let cheer: LocalizedStringResource
}

/// Identitas suara hantu. Nama file `.wav` di `AR2/Sounds` (Kenney, CC0).
struct GhostVoice {
    /// Bunyi "bicara" per huruf saat kalimat muncul, dimainkan dengan nada `pitch`.
    let blip: String
    /// Kecepatan putar blip: >1 lebih tinggi dan cepat, <1 lebih berat.
    let pitch: Float
    /// Bunyi saat gestur langkah berhasil.
    let cheer: String
    /// Musik pendek saat cerita selesai.
    let jingle: String

    init(blip: String = "sfx_voice", pitch: Float, cheer: String, jingle: String) {
        self.blip = blip
        self.pitch = pitch
        self.cheer = cheer
        self.jingle = jingle
    }
}

/// Cerita satu hantu: beberapa langkah lalu penutup yang mengarahkan ke hantu berikutnya.
struct GhostStory {
    let steps: [StoryStep]
    let finale: LocalizedStringResource
}

/// Daftar `Ghost.id` yang ceritanya sudah selesai, disimpan sebagai teks dipisah koma di `@AppStorage`.
enum StoryCompletion {
    static func ids(in stored: String) -> Set<String> {
        Set(stored.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    static func adding(_ id: String, to stored: String) -> String {
        var ids = ids(in: stored)
        ids.insert(id)
        return ids.sorted().joined(separator: ",")
    }
}
