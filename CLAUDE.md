# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

AR Ghost: a single-target iOS app (`AR2.xcodeproj`, scheme `AR2`). A 3D ghost rises from behind the user's head, attached to their face through the front camera. The user punches it away or claps to make it change form. It has no tests, no linter and no package dependencies.

## Build & run

```sh
# Compile check (the simulator can build it but cannot run AR)
xcodebuild -project AR2.xcodeproj -scheme AR2 -destination 'generic/platform=iOS Simulator' build
```

- The app uses `ARFaceTrackingConfiguration`, so the AR screen only works on a **physical device with a TrueDepth front camera**. On the simulator it shows an empty `ARView`, and the only sign is a console log. Any AR or hand-tracking behavior has to be checked on a device.
- Deployment target is iOS 26.2. The Swift language mode is 5, with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency turned on, so every type is implicitly `@MainActor` unless marked otherwise.
- The project uses file-system-synchronized groups (objectVersion 77). A file placed in `AR2/` joins the target automatically, and `project.pbxproj` never needs editing.
- There is no Info.plist file. Its keys come from `INFOPLIST_KEY_*` build settings. `NSCameraUsageDescription` is still the literal placeholder `CAMERA_USAGE_DESCRIPTION`.

## Architecture

**Entry point.** A UIKit `AppDelegate` (`@main`) sets up `AVAudioSession(.playback)` so audio plays in silent mode. It starts the looping background music and hosts SwiftUI `ContentView` in a `UIHostingController`. There is no SwiftUI `App` and no SceneDelegate. `SoundManager` (a singleton in `AppDelegate.swift`) plays bundled mp3s by bare filename.

**Screen switching (`ContentView`).** `ContentView` owns `isARActive` and passes `HomeView` and `GhostARView` a *custom* `Binding` rather than `$isARActive`. The binding's setter runs the animated gothic-gate transition (`closeGateAndEnterAR` / `closeGateAndReturn`), which flips the real state halfway through. Child views just set `isARActive = true/false`, and the transition happens on its own.

**AR screen (`GhostARView.swift`).** The SwiftUI layer is decorative blood/vignette overlays, the ghost info card, the clap-progress ring, a green hand-tracking debug circle and buttons. All game logic is in `ARViewContainer.Coordinator`, which talks back to SwiftUI only through four bindings (`showGhostInfo`, `handPosition`, `showClapIndicator`, `clapProgress`).

The Coordinator is a phase state machine that a `CADisplayLink` ticks every frame (`updateAnimation`):

```
waiting → rising → stationary ⇄ knockedAway → returning → stationary
                   stationary → transforming → stationary
```

- The ghost is a child of `AnchorEntity(.face)`. All positions are in face-local metres, and `stationaryPosition` is the resting spot above the head.
- **Hand detection** (`processHandDetection`) runs only while the phase is `.stationary`, at most every 80 ms. It runs Vision `VNDetectHumanHandPoseRequest` on `ARFrame.capturedImage` with orientation `.leftMirrored` on a background `visionQueue`, then sends UI updates back via `DispatchQueue.main.async`. Vision coordinates start at the bottom left. X is mirrored by hand, and each hand is reduced to the centroid of 11 joints (`getBestHandPoint`), smoothed with an EMA.
- **Punch**: the smoothed centroid's velocity passes a threshold, which is lower when the hand is in the ghost's screen zone. That calls `triggerKnockAway(direction:)`.
- **Clap**: two hand centroids stay within `handsClapThreshold` for `handsClapDuration`. That calls `triggerTransformation()`, which cycles `ghostModelNames`, spawns a particle smoke entity and swaps the model with `Entity.loadAsync`. The `.transforming` phase holds the ghost at near-zero scale until `isModelLoaded` is true.
- `canPunch` / `canTransform` are cooldown flags, reset by delayed `asyncAfter` calls.

**Adding or changing a ghost model.** USDZ files have very different native units, so each model needs its own scale entry in `ghostScales` (for example 0.0005 against 0.002). To add a form, drop the `.usdz` into `AR2/` and add its name to both `ghostModelNames` and `ghostScales`. The first model load in `makeUIView` separately hard-codes `"Cute_ghost"` and its scale.

## Conventions

- Code comments and user-facing strings are in **Indonesian**. Write new comments and UI text in Indonesian to match.
- Assets (`.usdz`, `.mp3`) are loaded by bare string name from the bundle. Renaming a file breaks it silently at runtime and only logs to the console.
