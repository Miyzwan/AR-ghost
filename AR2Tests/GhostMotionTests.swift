//
//  GhostMotionTests.swift
//  AR2Tests
//

import Foundation
import simd
import Testing
@testable import AR2

struct GhostMotionTests {
    private let start: TimeInterval = 100
    private let layout = GhostMotion.Layout.face

    /// Hantu yang sudah selesai naik dan diam, beserta waktunya.
    private func idleMotion() -> (GhostMotion, TimeInterval) {
        var motion = GhostMotion(layout: layout, style: .still, startTime: start)
        let idleTime = start + GhostMotion.waitDuration + GhostMotion.riseDuration
        _ = motion.update(at: idleTime)
        return (motion, idleTime)
    }

    private func isClose(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Bool {
        simd_length(a - b) < 0.0001
    }

    @Test func risesThenRestsAtRestPosition() {
        var motion = GhostMotion(layout: layout, style: .still, startTime: start)

        let waiting = motion.update(at: start + 0.5)
        #expect(motion.phase == .waiting)
        #expect(waiting.scale == 0)

        _ = motion.update(at: start + 1.5)
        #expect(motion.phase == .rising)

        let idle = motion.update(at: start + 3.01)
        #expect(motion.phase == .idle)
        #expect(isClose(idle.position, .zero))
        #expect(idle.scale == 1)
    }

    @Test func largeTimeJumpAdvancesThroughAllPhases() {
        var motion = GhostMotion(layout: layout, style: .still, startTime: start)
        _ = motion.update(at: start + 1000)
        #expect(motion.phase == .idle)
    }

    @Test func cannotPunchBeforeIdle() {
        var motion = GhostMotion(layout: layout, style: .still, startTime: start)
        _ = motion.update(at: start + 1.5)
        let accepted = motion.punch(direction: [1, 0, 0], at: start + 1.5)
        #expect(!accepted)
        #expect(motion.phase == .rising)
    }

    @Test func zeroDirectionPunchIsIgnored() {
        var (motion, now) = idleMotion()
        let accepted = motion.punch(direction: .zero, at: now)
        #expect(!accepted)
    }

    /// Regresi: dulu animasi kembali dimulai ulang puluhan kali karena timer dijadwalkan tiap frame.
    @Test func knockReturnsExactlyOnceAtSixtyFps() {
        var (motion, now) = idleMotion()
        let accepted = motion.punch(direction: [1, 0, 0], at: now)
        #expect(accepted)

        var phases: [GhostMotion.Phase] = []
        var time = now
        let end = now + GhostMotion.knockDuration + GhostMotion.knockPauseDuration + GhostMotion.returnDuration
        while time <= end + 0.1 {
            _ = motion.update(at: time)
            if phases.last != motion.phase {
                phases.append(motion.phase)
            }
            time += 1.0 / 60
        }

        #expect(phases == [.knockedAway, .knockedPause, .returning, .idle])
    }

    @Test func knockTravelsAlongDirectionAndReturnsToRest() {
        var (motion, now) = idleMotion()
        motion.punch(direction: [0, 2, 0], at: now)

        let knocked = motion.update(at: now + GhostMotion.knockDuration + 0.1)
        #expect(motion.phase == .knockedPause)
        #expect(isClose(knocked.position, [0, layout.knockDistance, 0]))

        let back = motion.update(at: now + 3.0)
        #expect(motion.phase == .idle)
        #expect(isClose(back.position, .zero))
        #expect(abs(back.scale - 1) < 0.0001)
    }

    @Test func punchCooldownAfterReturning() {
        var (motion, now) = idleMotion()
        motion.punch(direction: [1, 0, 0], at: now)
        let returned = now + 3.0

        _ = motion.update(at: returned + 0.1)
        #expect(motion.phase == .idle)
        #expect(!motion.canPunch(at: returned + 0.1))
        #expect(motion.canPunch(at: returned + GhostMotion.punchCooldown))
    }

    @Test func cannotTransformWhileKnocked() {
        var (motion, now) = idleMotion()
        motion.punch(direction: [1, 0, 0], at: now)
        let accepted = motion.beginTransform(at: now + 0.1)
        #expect(!accepted)
    }

    @Test func transformStaysHiddenUntilRevealed() {
        var (motion, now) = idleMotion()
        let accepted = motion.beginTransform(at: now)
        #expect(accepted)

        _ = motion.update(at: now + 0.5)
        #expect(motion.phase == .shrinking)

        // Model baru belum siap: hantu tetap tersembunyi berapa lama pun
        let hidden = motion.update(at: now + 30)
        #expect(motion.phase == .hidden)
        #expect(hidden.scale == 0)
        #expect(!motion.canPunch(at: now + 30))

        motion.reveal(at: now + 30)
        _ = motion.update(at: now + 30.5)
        #expect(motion.phase == .growing)

        let done = motion.update(at: now + 31.01)
        #expect(motion.phase == .idle)
        #expect(abs(done.scale - 1) < 0.01)
    }

    @Test func transformCooldownButPunchAllowedRightAway() {
        var (motion, now) = idleMotion()
        motion.beginTransform(at: now)
        _ = motion.update(at: now + 1.0)
        motion.reveal(at: now + 1.0)
        let grown = now + 2.0

        _ = motion.update(at: grown + 0.01)
        #expect(motion.phase == .idle)
        #expect(motion.canPunch(at: grown + 0.01))
        #expect(!motion.canTransform(at: grown + 1))
        #expect(motion.canTransform(at: grown + GhostMotion.transformCooldown))
    }

    @Test func celebrationReturnsToIdle() {
        var (motion, now) = idleMotion()
        let celebrated = motion.celebrate(at: now)
        #expect(celebrated)
        let jump = motion.update(at: now + GhostMotion.celebrateDuration / 2)
        #expect(motion.phase == .celebrating)
        #expect(jump.position.y > 0)

        let done = motion.update(at: now + GhostMotion.celebrateDuration + 0.01)
        #expect(motion.phase == .idle)
        #expect(isClose(done.position, .zero))
    }

    @Test func relocationHidesWithoutClapCooldown() {
        var (motion, now) = idleMotion()
        let started = motion.beginRelocation(at: now)
        #expect(started)
        _ = motion.update(at: now + GhostMotion.shrinkDuration + 0.01)
        #expect(motion.phase == .hidden)
        let again = motion.beginRelocation(at: now + 2)
        #expect(!again)
    }

    @Test func styleMovesTheIdlePose() {
        var motion = GhostMotion(layout: layout, style: .bob, startTime: start)
        let idleTime = start + GhostMotion.waitDuration + GhostMotion.riseDuration
        let a = motion.update(at: idleTime + 0.6)
        let b = motion.update(at: idleTime + 1.2)
        #expect(motion.phase == .idle)
        #expect(!isClose(a.position, b.position))
    }

    @Test func nudgeHopsThenReturnsToIdle() {
        var (motion, now) = idleMotion()
        let nudged = motion.nudge(at: now)
        #expect(nudged)
        let hop = motion.update(at: now + GhostMotion.nudgeDuration / 4)
        #expect(motion.phase == .nudging)
        #expect(hop.position.y > 0)
        // Saat sedang mencari perhatian, gestur cerita tidak bisa dimulai ulang
        let again = motion.nudge(at: now + 0.1)
        #expect(!again)
        _ = motion.update(at: now + GhostMotion.nudgeDuration + 0.01)
        #expect(motion.phase == .idle)
    }

    @Test func anticipationLeansTowardTheViewer() {
        var (motion, now) = idleMotion()
        let calm = motion.update(at: now)
        motion.anticipation = 1
        let eager = motion.update(at: now)
        #expect(eager.position.z > calm.position.z)
        #expect(eager.scale > calm.scale)
    }

    @Test func revealIsIgnoredOutsideHiddenPhase() {
        var (motion, now) = idleMotion()
        motion.reveal(at: now)
        #expect(motion.phase == .idle)
    }
}
