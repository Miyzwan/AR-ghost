# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

AR Ghost: a universal iOS app (`AR2.xcodeproj`, scheme `AR2`, test target `AR2Tests`). A 3D ghost rises from behind the user's head, or from a floor or table on devices without a TrueDepth camera. Each of the ten ghosts plays a short interactive story: it hops between spots on the user's body and asks for a specific face or hand gesture at each step. Clapping changes it into the next ghost. It has no package dependencies and no linter.

## Build & test

```sh
# Compile check
xcodebuild -project AR2.xcodeproj -scheme AR2 -destination 'generic/platform=iOS Simulator' build

# Unit tests (Swift Testing)
xcodebuild test -project AR2.xcodeproj -scheme AR2 -destination 'platform=iOS Simulator,name=iPhone 17'
# One suite or test: add -only-testing:AR2Tests/GhostMotionTests (or .../GhostMotionTests/knockReturnsExactlyOnceAtSixtyFps)
```

- The simulator supports neither AR configuration, so the AR screen only shows the "unsupported" state there. Any AR, camera or hand-tracking behavior has to be checked on a device.
- To test world mode on a Face ID device, use the DEBUG toggle in Settings, or the launch argument `-debug.forceWorldMode YES`. The green hand circle (DEBUG only) shows whether Vision coordinates line up with the screen.
- Deployment target is iOS 26.2. The Swift language mode is 5, with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency turned on. Everything is implicitly `@MainActor`; code that runs on the Vision queue has to be marked `nonisolated` (see `HandPoseProcessor.swift`, `Log.swift`).
- The project uses file-system-synchronized groups (objectVersion 77). A file placed in `AR2/` or `AR2Tests/` joins its target automatically.
- Info.plist values come from `INFOPLIST_KEY_*` build settings plus `AR2-Info.plist` at the repo root. That file holds what build settings can't express: the scene manifest with a single window, and `CFBundleLocalizations`. Keep `INFOPLIST_KEY_UIApplicationSceneManifest_Generation` off; when it is on, it overrides the manifest in that file.

## Architecture

**App shell.** `AR2App` (SwiftUI `App`) registers defaults (`AppSettings`) and starts `SoundManager`, which uses an `.ambient` session and one preloaded player per effect. Sound, vibration and onboarding settings are `@AppStorage` keys defined in `AppSettings`, shared by the views and `SoundManager`.

**Screen switching (`ContentView`).** `ContentView` owns `isARActive` and passes `HomeView` and `GhostARView` a *custom* `Binding`. Its setter asks for camera permission, runs the portal transition (`PortalTransitionView`), and ignores taps while a transition is running. Child views just set `isARActive`. Onboarding is a `fullScreenCover`, shown while `hasSeenOnboarding` is false.

**AR screen.** `GhostARView` (SwiftUI HUD) → `ARViewContainer` (`UIViewRepresentable`; `dismantleUIView` calls `detach()`, which stops the camera) → `GhostARModel` (`@Observable`, the only class that touches ARKit and RealityKit). Pure logic lives in separate types so it can be tested:

- `ARMode` is `.face` (front camera, `AnchorEntity(.face)`) when TrueDepth is available, otherwise `.world` (rear camera, horizontal-plane anchor, `ARCoachingOverlayView`). Anchor, configuration, layout and ghost height all branch on it.
- `GhostMotion` is a pure state machine: `waiting → rising → idle ⇄ knockedAway → knockedPause → returning`, `idle → celebrating → idle`, and `idle → shrinking → hidden → growing` (used both to change form and to move to another spot). `update(at:)` returns a `GhostPose` relative to the current spot, including the ghost's signature motion (`MotionStyle.pose(at:)`, in units of ghost height). Cooldowns are timestamps. Never schedule timers (`asyncAfter`) for animation: a timer can fire after the view is gone, and the old code restarted the return animation on every frame that way.
- The frame loop is a RealityKit `SceneEvents.Update` subscription. It resolves the current `BodySpot` to a placement and applies placement × pose to `ghostRoot`, a container entity. The ghost model is a child of `ghostRoot` and gets swapped during a transform, only once `GhostMotion` is `.hidden`. `ghostRoot` is also reparented between anchors only while hidden.
- **Spots.** In face mode, head spots (`aboveHead`, `besideHead`, `inFrontOfFace`, `peekBehindHead`) are fixed offsets on the face anchor. Shoulder, chest and palm are tracked every frame on a second `AnchorEntity(world:)`: Vision body pose (shoulders, only requested while the ghost is there) or palm points are unprojected onto a screen-parallel plane at face depth (`worldPoint`), falling back to an estimate from the face position. In world mode, spots are offsets on the plane measured from the camera direction (`BodySpot.planeOffset`); the palm is tracked.
- **Story.** `StoryProgress` (pure, no timers) walks `playing(step) → celebrating → moving(to:) → … → finished`. `GhostARModel` advances it once `GhostMotion` is back to `.idle` after the reaction, and calls `arrive()` while the ghost is hidden. Only the gesture the current step expects is detected (plus clapping), which keeps gestures from being misread: punching works only on steps that ask for `.punch` (Mister Q True Form, Pixel). Clapping is allowed at any time except during `.hideFace`. Finished stories are saved in `@AppStorage(AppSettings.completedStories)` (`StoryCompletion`) and shown as badges on Home. In world mode, face gestures are replaced with `GhostGesture.worldFallback`.
- **Gestures.** `HandPoseProcessor` returns palms plus a `HandShape` per hand (`HandShapeClassifier`, pure, from joint distance ratios). `HandGestureDetector` handles clap, punch, held shapes, wave (`ReversalCounter`), touching the ghost, and covering the face. `FaceGestureDetector` reads `FaceSignals` (ARKit blend shapes plus gravity-relative head pitch/yaw/roll) for expressions, nod/shake/tilt and `holdStill`. Held gestures use `HoldTimer`, which forgives short Vision dropouts. In DEBUG, the AR screen shows raw hand shapes and blend shape values for tuning thresholds on device.
- Hand tracking has three stages:
  - `HandPoseProcessor` (nonisolated) runs Vision on the camera frame and returns palm centroids in normalized **raw camera image** coordinates, via `VisionGeometry.rawImagePoint`.
  - `GhostARModel` maps those points to the view with `ARFrame.displayTransform(for:viewportSize:)`, which handles orientation, crop and front-camera mirroring.
  - `HandGestureDetector` (pure) turns the normalized view points into punch and clap events.
  
  Only one Vision request is in flight at a time.
- Punch directions start in screen space and are unprojected onto the plane of the ghost (`worldDirection`), so they stay correct for either camera.

**Juice (animation and sound).** `GhostPose.stretch` adds squash and stretch (height × stretch, width ÷ √stretch). Each `MotionStyle` has its own `celebration(_:)` reaction; `GhostMotion.anticipation` (the current gesture progress) makes the ghost lean in and tremble, and `.nudging` makes it hop for attention after 7 s without a try. A successful step plays the ghost's `GhostVoice.cheer`, bursts particles in `Ghost.glow`, and pops the step's `cheer` word on screen; the finale adds a jingle, a big burst and SwiftUI confetti. Story lines type out letter by letter with "voice" blips: one short sample played through `AVAudioEngine` + `AVAudioUnitVarispeed` at the ghost's `GhostVoice.pitch`. Sounds are `.wav` files in `AR2/Sounds` (Kenney audio packs, CC0), converted from OGG with ffmpeg and peak-normalized; iOS cannot play OGG.

**Visual style.** `SpookyTheme.swift` holds the "cute-spooky" palette (`Spooky`: blood-red night, bone white, pumpkin orange), SF Rounded type (`Font.spooky`), Liquid Glass button and card styles, and `SpookyBackground`. The `spookyAccent` environment value is pumpkin for a cute ghost and bright red for an angry one (`Ghost.mood`). The AR screen and the shared photo both follow it. The ghost is driven by face and hand gestures only: there is no transform button and no tap-to-punch.

**Home hero and ghost picker.** Home shows the selected ghost; the user swipes the hero or taps the arrows to pick one of the ten. The choice is stored in `@AppStorage(AppSettings.selectedGhost)` (a `Ghost.id`). `ContentView` passes it to `GhostARView`, which starts `GhostARModel` at that index; clapping still cycles through the catalog from there. `GhostHeroView` renders the ghost with **SceneKit**, not RealityKit, and animates it with the same `MotionStyle` (`MotionStyle` is `nonisolated` because SceneKit calls it from its render thread). A `RealityView` with a virtual camera shown before the AR screen turns the `ARView` camera feed black on device: the ghost renders, the background doesn't. `ARViewContainer` also sets `environment.background = .cameraFeed()` explicitly for the same reason.

**Ghost models.** `GhostCatalog` in `Model/Ghost.swift` lists the ten forms: the USDZ file name, localized name and lore, `mood`, and credits (CC BY or CC0). All ghosts are shown at the same height: `makeGhostModel` (AR, `ARMode.ghostHeight`) and `GhostHeroScene` (Home) both use `GhostSizing`, which scales a model to the target height, caps very wide models at 2× that, and puts the pivot at bottom center. `GhostSizing` relies on the model's bounding box, so a node with a rotation makes a ghost look too small. The eight newer models (Kenney, Asset Quest, Nikki Morin, Robin Lamb) were converted from glTF/FBX with Blender's USD exporter (Y-up, transforms baked into the vertices) for that reason. `Captain_ghost` combines Asset Quest's Ghost 1 with the kit's pirate hat. To add a form, drop the `.usdz` into `AR2/`, add a `Ghost` entry with a unique `MotionStyle` and a `GhostStory` (in `Model/GhostStories.swift`; tests require 3 steps, a unique gesture code, and a different spot each step), and add its name, lore, story lines and finale to `Localizable.xcstrings`. Keep its attribution; the Credits screen lists it.

## Conventions

- Code comments are in **Indonesian**. User-facing strings are written in **English** in code (the source language) and translated in `Localizable.xcstrings` and `InfoPlist.xcstrings`. Add an `id` translation for every new string.
- Assets (`.usdz`, `.mp3`) are loaded by bare string name. Renaming a file breaks it silently at runtime and only logs through `os.Logger`.
