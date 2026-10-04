//
//  StoryBubbleLayout.swift
//  AR2
//

import CoreGraphics

/// Mencari tempat gelembung cerita di dekat hantu tanpa menutupi hantu maupun wajah pengguna.
/// Murni (tanpa SwiftUI) supaya bisa diuji; semua kotak dalam koordinat yang sama.
struct StoryBubbleLayout: Equatable {
    /// Sisi gelembung tempat ekornya keluar menunjuk hantu.
    enum Tail: Equatable {
        case none, bottom, top, leading, trailing
    }

    /// Calon posisi, dicoba berurutan: di atas hantu dulu, paling akhir di bawahnya
    /// (di bawah hantu biasanya ada badan pengguna).
    enum Slot: CaseIterable {
        case above, aboveBesideFace, topEdge, trailing, leading, below
    }

    /// Kotak gelembung, termasuk ruang ekor di tiap sisi (`tailLength`).
    var frame: CGRect
    var tail: Tail
    /// Ujung ekor sepanjang sisinya, relatif ke `frame`: x untuk atas/bawah, y untuk samping.
    var tailOffset: CGFloat
    var slot: Slot?

    /// Ruang ekor; gelembung digambar menjorok sejauh ini dari tepi `frame`.
    static let tailLength: CGFloat = 10
    /// Jarak tepi `frame` ke hantu atau wajah.
    static let gap: CGFloat = 4

    /// - Parameters:
    ///   - size: ukuran gelembung termasuk ruang ekor.
    ///   - ghost: kotak hantu di layar, `nil` bila hantu tidak terlihat.
    ///   - face: kotak wajah pengguna (kamera depan) yang tidak boleh tertutup.
    ///   - previous: posisi sebelumnya, dicoba lebih dulu supaya gelembung tidak lompat bolak-balik.
    static func place(
        size: CGSize,
        ghost: CGRect?,
        face: CGRect?,
        in bounds: CGRect,
        preferring previous: Slot? = nil
    ) -> StoryBubbleLayout {
        guard let ghost else {
            // Hantu tidak terlihat: gelembung di tepi atas tanpa ekor
            let frame = CGRect(x: bounds.midX - size.width / 2, y: bounds.minY, width: size.width, height: size.height)
            return StoryBubbleLayout(frame: clamp(frame, to: bounds), tail: .none, tailOffset: 0, slot: nil)
        }

        let obstacles = [ghost] + (face.map { [$0] } ?? [])
        let order = previous.map { [$0] + Slot.allCases.filter { $0 != previous } } ?? Slot.allCases
        var best: (layout: StoryBubbleLayout, overlap: CGFloat)?

        for slot in order {
            guard let raw = frame(for: slot, size: size, ghost: ghost, face: face, in: bounds) else { continue }
            let fits = bounds.insetBy(dx: -0.5, dy: -0.5).contains(raw)
            let frame = clamp(raw, to: bounds)
            let overlap = obstacles.reduce(0) { $0 + area($1.intersection(frame)) }
            let layout = make(slot, frame: frame, ghost: ghost)
            if fits && overlap < 1 { return layout }
            if best == nil || overlap < best!.overlap { best = (layout, overlap) }
        }
        return best!.layout
    }

    /// Kotak calon untuk `slot`, sudah digeser sepanjang sumbu bebasnya agar masuk layar.
    private static func frame(for slot: Slot, size: CGSize, ghost: CGRect, face: CGRect?, in bounds: CGRect) -> CGRect? {
        let (w, h) = (size.width, size.height)
        let aboveY = ghost.minY - gap - h
        func horizontal(_ x: CGFloat, y: CGFloat) -> CGRect {
            CGRect(x: min(max(x, bounds.minX), bounds.maxX - w), y: y, width: w, height: h)
        }
        func vertical(_ x: CGFloat) -> CGRect {
            CGRect(x: x, y: min(max(ghost.midY - h / 2, bounds.minY), bounds.maxY - h), width: w, height: h)
        }

        switch slot {
        case .above:
            return horizontal(ghost.midX - w / 2, y: aboveY)
        case .aboveBesideFace:
            // Di atas hantu tetapi digeser ke samping wajah, di sisi hantu
            guard let face else { return nil }
            let x = ghost.midX < face.midX ? face.minX - gap - w : face.maxX + gap
            return horizontal(x, y: aboveY)
        case .topEdge:
            return horizontal(ghost.midX - w / 2, y: bounds.minY)
        case .trailing:
            return vertical(ghost.maxX + gap)
        case .leading:
            return vertical(ghost.minX - gap - w)
        case .below:
            return horizontal(ghost.midX - w / 2, y: ghost.maxY + gap)
        }
    }

    private static func make(_ slot: Slot, frame: CGRect, ghost: CGRect) -> StoryBubbleLayout {
        // Ekor tidak menempel di sudut yang membulat
        let inset: CGFloat = 26
        func along(_ value: CGFloat, _ length: CGFloat) -> CGFloat {
            min(max(value, inset), max(length - inset, inset))
        }
        let x = along(ghost.midX - frame.minX, frame.width)
        let y = along(ghost.midY - frame.minY, frame.height)
        return switch slot {
        case .above, .aboveBesideFace, .topEdge: StoryBubbleLayout(frame: frame, tail: .bottom, tailOffset: x, slot: slot)
        case .below: StoryBubbleLayout(frame: frame, tail: .top, tailOffset: x, slot: slot)
        case .trailing: StoryBubbleLayout(frame: frame, tail: .leading, tailOffset: y, slot: slot)
        case .leading: StoryBubbleLayout(frame: frame, tail: .trailing, tailOffset: y, slot: slot)
        }
    }

    private static func clamp(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        var frame = frame
        frame.origin.x = min(max(frame.minX, bounds.minX), max(bounds.maxX - frame.width, bounds.minX))
        frame.origin.y = min(max(frame.minY, bounds.minY), max(bounds.maxY - frame.height, bounds.minY))
        return frame
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}
