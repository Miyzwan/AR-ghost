//
//  StoryProgressTests.swift
//  AR2Tests
//

import Testing
@testable import AR2

struct StoryProgressTests {
    private let story = GhostStory.misterQ

    @Test func advancesOnlyWithTheRightGesture() {
        var progress = StoryProgress(story: story, faceCamera: true)
        #expect(progress.expectedGesture == .smile)
        #expect(progress.spot == .aboveHead)

        let wrong = progress.complete(.wink)
        #expect(!wrong)
        #expect(progress.phase == .playing(step: 0))

        let right = progress.complete(.smile)
        #expect(right)
        #expect(progress.expectedGesture == nil)
        progress.advance()
        #expect(progress.phase == .moving(to: 1))
        // Kalimat dan titik berikutnya baru dipakai setelah hantu tiba
        progress.arrive()
        #expect(progress.phase == .playing(step: 1))
        #expect(progress.expectedGesture == .nod)
        #expect(progress.spot == story.steps[1].spot)
    }

    @Test func lastStepEndsWithFinale() {
        var progress = StoryProgress(story: story, faceCamera: true)
        for step in story.steps.indices {
            let accepted = progress.complete(progress.gesture(at: step))
            #expect(accepted)
            progress.advance()
            progress.arrive()
        }
        #expect(progress.isFinished)
        #expect(progress.expectedGesture == nil)
        #expect(progress.stepIndex == story.steps.count)
        // Hantu tetap di titik terakhir
        #expect(progress.spot == story.steps.last?.spot)
    }

    @Test func worldModeAsksForHandGestures() {
        let progress = StoryProgress(story: story, faceCamera: false)
        #expect(progress.expectedGesture == .thumbsUp)
    }

    @Test func advanceAndArriveIgnoredOutOfOrder() {
        var progress = StoryProgress(story: story, faceCamera: true)
        progress.advance()
        progress.arrive()
        #expect(progress.phase == .playing(step: 0))
    }
}
