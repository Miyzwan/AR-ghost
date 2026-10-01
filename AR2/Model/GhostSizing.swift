//
//  GhostSizing.swift
//  AR2
//

import simd

/// Menyamakan ukuran semua hantu. Tiap USDZ punya satuan dan proporsi berbeda, jadi setiap
/// model diskalakan ke tinggi yang sama (`height`). Lebarnya dibatasi `height * maxWidthRatio`
/// sebagai pengaman untuk model yang sangat lebar (misalnya alas datar besar) agar tidak tampak raksasa;
/// tangan terentang atau alas diorama Mister Q masih di bawah batas ini.
enum GhostSizing {
    static let maxWidthRatio: Float = 2

    /// Faktor skala untuk model dengan ukuran `extents` (x, y, z; Y ke atas).
    static func scale(forExtents extents: SIMD3<Float>, height: Float) -> Float {
        let width = max(extents.x, extents.z)
        let byHeight = height / max(extents.y, 0.0001)
        let byWidth = height * maxWidthRatio / max(width, 0.0001)
        return min(byHeight, byWidth)
    }
}
