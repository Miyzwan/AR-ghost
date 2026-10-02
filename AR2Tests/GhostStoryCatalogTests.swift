//
//  GhostStoryCatalogTests.swift
//  AR2Tests
//

import Foundation
import simd
import Testing
@testable import AR2

struct GhostStoryCatalogTests {
    @Test func everyGhostHasAThreeStepStory() {
        for ghost in GhostCatalog.all {
            #expect(ghost.story.steps.count == 3, "\(ghost.id)")
        }
    }

    @Test func gestureCodesAreUnique() {
        let codes = GhostCatalog.all.map { $0.story.steps.map(\.gesture.rawValue).joined(separator: ">") }
        #expect(Set(codes).count == codes.count)
    }

    @Test func spotChangesBetweenSteps() {
        for ghost in GhostCatalog.all {
            let spots = ghost.story.steps.map(\.spot)
            for (a, b) in zip(spots, spots.dropFirst()) {
                #expect(a != b, "\(ghost.id): titik sama berturut-turut")
            }
        }
    }

    @Test func everyGhostHasItsOwnMotionStyle() {
        let styles = GhostCatalog.all.map(\.style)
        #expect(Set(styles).count == styles.count)
        #expect(!styles.contains(.still))
    }

    @Test func worldFallbacksNeverNeedTheFace() {
        for gesture in GhostGesture.allCases {
            let resolved = gesture.resolved(faceCamera: false)
            #expect(!resolved.requiresFace, "\(gesture)")
            #expect(resolved != .hideFace)
            #expect(gesture.resolved(faceCamera: true) == gesture)
        }
    }

    @Test func punchOnlyWhereTheStoryAsksForIt() {
        let punchers = GhostCatalog.all.filter { $0.story.steps.contains { $0.gesture == .punch } }.map(\.id)
        #expect(Set(punchers) == ["Scary_ghost", "Pixel_ghost"])
    }

    @Test func everySoundIsInTheBundle() {
        let bundle = Bundle(for: GhostARModel.self)
        let shared = ["sfx_appear", "sfx_vanish", "sfx_tick", "sfx_nudge"]
        let voices = GhostCatalog.all.flatMap { [$0.voice.blip, $0.voice.cheer, $0.voice.jingle] }
        for name in Set(shared + voices) {
            #expect(bundle.url(forResource: name, withExtension: "wav") != nil, "\(name).wav hilang")
        }
    }

    @Test func everyGhostSoundsDifferent() {
        let cheers = GhostCatalog.all.map(\.voice.cheer)
        let jingles = GhostCatalog.all.map(\.voice.jingle)
        #expect(Set(cheers).count == cheers.count)
        #expect(Set(jingles).count == jingles.count)
    }

    @Test func completionListRoundTrips() {
        var stored = ""
        stored = StoryCompletion.adding("Boo_ghost", to: stored)
        stored = StoryCompletion.adding("Cute_ghost", to: stored)
        stored = StoryCompletion.adding("Boo_ghost", to: stored)
        #expect(StoryCompletion.ids(in: stored) == ["Boo_ghost", "Cute_ghost"])
        #expect(StoryCompletion.ids(in: "") .isEmpty)
    }
}

struct MotionStyleTests {
    private let samples = stride(from: 0.0, to: 12.0, by: 0.05).map { $0 }

    @Test func posesStayCloseToTheSpot() {
        for style in MotionStyle.allCases {
            for t in samples {
                let pose = style.pose(at: t)
                #expect(simd_length(pose.offset) <= 0.6, "\(style) t=\(t)")
                #expect(pose.scale > 0.8 && pose.scale < 1.2, "\(style) t=\(t)")
            }
        }
    }

    @Test func stylesMoveDifferently() {
        let styles = MotionStyle.allCases.filter { $0 != .still }
        let traces = styles.map { style in samples.map { style.pose(at: $0).offset } }
        for i in traces.indices {
            for j in traces.indices where j > i {
                let difference = zip(traces[i], traces[j]).map { simd_length($0 - $1) }.max() ?? 0
                #expect(difference > 0.02, "\(styles[i]) mirip \(styles[j])")
            }
        }
    }

    @Test func pixelStepJumpsInDiscreteSteps() {
        let a = MotionStyle.pixelStep.pose(at: 0.05).offset
        let b = MotionStyle.pixelStep.pose(at: 0.45).offset
        let c = MotionStyle.pixelStep.pose(at: 0.55).offset
        #expect(a == b)
        #expect(a != c)
    }

    @Test func celebrationEndsInNeutralPose() {
        for style in MotionStyle.allCases {
            let end = style.celebration(1)
            #expect(simd_length(end.pose.offset) < 0.001, "\(style)")
            #expect(abs(end.pose.scale - 1) < 0.001, "\(style)")
            #expect(abs(end.stretch - 1) < 0.001, "\(style)")
            // Di tengah reaksi hantu harus terlihat bergerak
            let middle = style.celebration(0.5)
            let moved = simd_length(middle.pose.offset) > 0.01 || abs(middle.pose.scale - 1) > 0.01
                || abs(middle.pose.rotation.angle) > 0.1 || abs(middle.stretch - 1) > 0.05
            #expect(moved, "\(style)")
        }
    }

    @Test func stillDoesNotMove() {
        #expect(MotionStyle.still.pose(at: 3.7).offset == .zero)
    }
}
