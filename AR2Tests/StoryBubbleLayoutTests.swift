//
//  StoryBubbleLayoutTests.swift
//  AR2Tests
//

import CoreGraphics
import Testing
@testable import AR2

struct StoryBubbleLayoutTests {
    /// Layar iPhone di dalam safe area, tanpa bar atas dan tombol bawah.
    let bounds = CGRect(x: 0, y: 64, width: 393, height: 560)
    let size = CGSize(width: 270, height: 110)

    @Test func sitsAboveTheGhostWithTailPointingDown() {
        let ghost = CGRect(x: 150, y: 260, width: 90, height: 80)
        let layout = StoryBubbleLayout.place(size: size, ghost: ghost, face: nil, in: bounds)
        #expect(layout.slot == .above)
        #expect(layout.tail == .bottom)
        #expect(layout.frame.maxY <= ghost.minY)
        // Ekor menunjuk tengah hantu
        #expect(abs(layout.frame.minX + layout.tailOffset - ghost.midX) < 1)
    }

    @Test func neverCoversTheFaceOrGhost() {
        // Hantu di pundak kanan, wajah di tengah layar
        let face = CGRect(x: 100, y: 220, width: 190, height: 280)
        let ghost = CGRect(x: 290, y: 430, width: 70, height: 60)
        let layout = StoryBubbleLayout.place(size: size, ghost: ghost, face: face, in: bounds)
        #expect(layout.frame.intersection(face).isNull)
        #expect(layout.frame.intersection(ghost).isNull)
        #expect(bounds.contains(layout.frame))
    }

    @Test func movesBesideWhenThereIsNoRoomAbove() {
        // Hantu di dekat bar atas; gelembung tidak muat di atasnya
        let ghost = CGRect(x: 20, y: 90, width: 80, height: 80)
        let layout = StoryBubbleLayout.place(size: size, ghost: ghost, face: nil, in: bounds)
        #expect(layout.slot == .trailing)
        #expect(layout.tail == .leading)
        #expect(layout.frame.minX >= ghost.maxX)
    }

    @Test func staysOnTheScreen() {
        // Hantu di tepi kanan: gelembung digeser ke dalam, ekor tetap menunjuk hantu
        let ghost = CGRect(x: 330, y: 300, width: 60, height: 60)
        let layout = StoryBubbleLayout.place(size: size, ghost: ghost, face: nil, in: bounds)
        #expect(bounds.contains(layout.frame))
        #expect(layout.tailOffset > layout.frame.width / 2)
    }

    @Test func keepsThePreviousSlotWhileItStillFits() {
        let ghost = CGRect(x: 150, y: 300, width: 90, height: 80)
        let layout = StoryBubbleLayout.place(size: size, ghost: ghost, face: nil, in: bounds, preferring: .below)
        #expect(layout.slot == .below)
    }

    @Test func pinsToTheTopWhenTheGhostIsOffScreen() {
        let layout = StoryBubbleLayout.place(size: size, ghost: nil, face: nil, in: bounds)
        #expect(layout.tail == .none)
        #expect(layout.frame.minY == bounds.minY)
        #expect(abs(layout.frame.midX - bounds.midX) < 1)
    }
}
