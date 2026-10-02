//
//  GestureTiming.swift
//  AR2
//

import Foundation

/// Menghitung berapa lama sebuah kondisi ditahan. Celah singkat (frame Vision yang meleset)
/// dimaafkan selama `tolerance`, supaya progres tidak terus mulai dari nol.
struct HoldTimer {
    var duration: TimeInterval
    var tolerance: TimeInterval = 0.3

    private var start: TimeInterval?
    private var lastMatch: TimeInterval = 0

    init(duration: TimeInterval, tolerance: TimeInterval = 0.3) {
        self.duration = duration
        self.tolerance = tolerance
    }

    var isActive: Bool { start != nil }

    mutating func reset() {
        start = nil
    }

    /// Mengembalikan progres 0...1; 1 berarti kondisi sudah ditahan cukup lama.
    mutating func update(matching: Bool, at time: TimeInterval) -> Double {
        if matching {
            if start == nil { start = time }
            lastMatch = time
        } else if let start, time - lastMatch > tolerance || time < start {
            self.start = nil
        }
        guard let start else { return 0 }
        return min(max((lastMatch - start) / duration, 0), 1)
    }
}

/// Menghitung berapa kali sebuah nilai berbalik arah (angguk, geleng, lambai).
/// Balik arah baru dihitung setelah nilai bergerak sejauh `threshold` dari titik ekstremnya.
struct ReversalCounter {
    var threshold: Double
    /// Hitungan mulai dari nol bila tidak ada balik arah selama ini.
    var window: TimeInterval

    private(set) var count = 0
    private var extreme: Double?
    private var direction = 0 // -1 turun, +1 naik, 0 belum diketahui
    private var lastReversal: TimeInterval = 0

    init(threshold: Double, window: TimeInterval) {
        self.threshold = threshold
        self.window = window
    }

    mutating func reset() {
        count = 0
        extreme = nil
        direction = 0
    }

    /// Mengembalikan jumlah balik arah dalam jendela waktu saat ini.
    mutating func update(_ value: Double, at time: TimeInterval) -> Int {
        if count > 0, time - lastReversal > window {
            count = 0
        }
        guard let current = extreme else {
            extreme = value
            lastReversal = time
            return count
        }

        switch direction {
        case 0:
            // Arah pertama ditetapkan setelah gerakan cukup jauh
            if abs(value - current) >= threshold {
                direction = value > current ? 1 : -1
                extreme = value
                lastReversal = time
            }
        default:
            if Double(direction) * (value - current) > 0 {
                // Masih searah: geser titik ekstrem
                extreme = value
            } else if abs(value - current) >= threshold {
                count += 1
                direction = -direction
                extreme = value
                lastReversal = time
            }
        }
        return count
    }
}
