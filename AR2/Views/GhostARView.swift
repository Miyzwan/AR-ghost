//
//  GhostARView.swift
//  AR2
//

import SwiftUI

struct GhostARView: View {
    @Binding var isARActive: Bool
    @State private var model: GhostARModel
    @State private var capturedPhoto: CapturedPhoto?
    @State private var isCapturing = false
    @State private var flashOpacity = 0.0
    @State private var showSettings = false
    @State private var isCheerVisible = false
    @State private var confettiStart: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppSettings.hapticsEnabled) private var hapticsEnabled = true

    private var accent: SpookyAccent { .for(model.activeGhost) }

    /// - Parameter ghost: wujud yang dipanggil pertama kali (pilihan di Home).
    init(isARActive: Binding<Bool>, ghost: Ghost) {
        _isARActive = isARActive
        _model = State(initialValue: GhostARModel(mode: .preferred, startIndex: GhostCatalog.index(ofID: ghost.id)))
    }

    var body: some View {
        ZStack {
            // Kamera AR dan 3D objek
            ARViewContainer(model: model)
                .ignoresSafeArea()

            SpookyVignetteView(accent: accent)

            if model.clapProgress > 0 {
                GestureProgressRing(progress: model.clapProgress, symbol: "hands.clap.fill")
                    .transition(.scale.combined(with: .opacity))
            } else if model.gestureProgress > 0, let gesture = model.storyGesture {
                GestureProgressRing(progress: model.gestureProgress, symbol: gesture.symbol)
                    .transition(.scale.combined(with: .opacity))
            }

            // Seruan saat gestur berhasil, di atas hantu
            if isCheerVisible, let cheer = model.cheer {
                CheerPopView(text: cheer)
                    .id(model.storySuccessCount)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 140)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if let confettiStart {
                ConfettiView(start: confettiStart)
                    .ignoresSafeArea()
            }

            statusOverlay

            VStack(spacing: 16) {
                topBar

                Spacer()

                if model.showGhostInfo {
                    GhostInfoCard(ghost: model.activeGhost)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if model.status == .running && model.isStoryVisible {
                    storyCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                controls
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Kilatan putih saat mengambil foto
            Color.white
                .ignoresSafeArea()
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
        .environment(\.spookyAccent, accent)
        .animation(.spring(), value: model.showGhostInfo)
        .animation(.easeInOut(duration: 0.2), value: model.clapProgress > 0)
        .animation(.easeInOut(duration: 0.2), value: model.gestureProgress > 0)
        .animation(.spring(), value: model.isStoryVisible)
        .animation(.spring(), value: model.storyStepIndex)
        .animation(.spring(), value: model.isAwaitingGesture)
        .animation(.spring(), value: model.isStoryComplete)
        .animation(.easeInOut(duration: 0.6), value: accent)
        .sensoryFeedback(trigger: model.punchCount) { _, _ in
            hapticsEnabled ? .impact(weight: .heavy) : nil
        }
        .sensoryFeedback(trigger: model.transformCount) { _, _ in
            hapticsEnabled ? .success : nil
        }
        .sensoryFeedback(trigger: model.storySuccessCount) { _, _ in
            hapticsEnabled ? .success : nil
        }
        .task(id: model.storySuccessCount) {
            guard model.storySuccessCount > 0 else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.6)) { isCheerVisible = true }
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(.easeIn(duration: 0.25)) { isCheerVisible = false }
        }
        .task(id: model.isStoryComplete) {
            guard model.isStoryComplete, !reduceMotion else { return }
            confettiStart = .now
            try? await Task.sleep(for: .seconds(4))
            confettiStart = nil
        }
        .sheet(item: $capturedPhoto) { photo in
            PhotoPreviewView(photo: photo)
                .environment(\.spookyAccent, accent)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func capturePhoto() async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        SoundManager.shared.playShutter()
        guard let snapshot = await model.snapshot() else { return }

        flashOpacity = 0.9
        withAnimation(.easeOut(duration: 0.4)) {
            flashOpacity = 0
        }
        capturedPhoto = CapturedPhoto(image: PhotoComposer.compose(snapshot, accent: accent))
    }

    // --- Cerita hantu: kalimat dan petunjuk gestur, atau penutup ---
    @ViewBuilder
    private var storyCard: some View {
        if model.isStoryComplete {
            StoryFinaleView(line: model.storyLine, nextGhost: model.nextGhost)
        } else {
            StoryCaptionView(
                ghost: model.activeGhost,
                line: model.storyLine,
                gesture: model.storyGesture,
                step: model.storyStepIndex,
                stepCount: model.storyStepCount,
                needsHand: model.needsHand,
                nudgeCount: model.nudgeCount
            )
        }
    }

    // --- Bar atas: keluar dan pengaturan ---
    private var topBar: some View {
        HStack {
            Button {
                isARActive = false
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(SpookyIconButtonStyle(size: 46))
            .accessibilityLabel(Text("BACK TO THE REAL WORLD"))

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(SpookyIconButtonStyle(size: 46))
            .accessibilityLabel(Text("Settings"))
        }
    }

    // --- Tombol bawah: info dan shutter. Hantu hanya bisa disentuh lewat gestur tangan. ---
    private var controls: some View {
        GlassEffectContainer(spacing: 28) {
            HStack(spacing: 28) {
                Button {
                    model.showGhostInfo.toggle()
                } label: {
                    Image(systemName: model.showGhostInfo ? "xmark" : "questionmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(SpookyIconButtonStyle(size: 58))
                .accessibilityLabel(Text("Ghost info"))

                Button {
                    Task { await capturePhoto() }
                } label: {
                    Image(systemName: "camera.fill")
                }
                .buttonStyle(ShutterButtonStyle())
                .disabled(model.status != .running || isCapturing)
                .accessibilityLabel(Text("Take a photo"))

                // Penyeimbang agar shutter tetap di tengah layar
                Color.clear
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)
            }
        }
    }

    // --- Status sesi AR ---
    @ViewBuilder
    private var statusOverlay: some View {
        switch model.status {
        case .loading:
            StatusCard {
                ProgressView().tint(accent.color)
                Text("Summoning the ghost…")
            }
        case .unsupported:
            StatusCard {
                Image(systemName: "eye.slash")
                Text("This device doesn't support augmented reality.")
            }
        case .interrupted:
            StatusCard {
                Image(systemName: "pause.circle")
                Text("The camera is paused.")
            }
        case .failed:
            StatusCard {
                Image(systemName: "exclamationmark.triangle")
                Text("The ghost couldn't be summoned.")
                Button("Try Again") { model.retry() }
                    .buttonStyle(SpookyButtonStyle())
            }
        case .running:
            // Mode dunia memakai coaching overlay bawaan ARKit untuk mencari permukaan
            if model.mode == .face && !model.isTargetFound {
                StatusCard {
                    Image(systemName: "face.smiling")
                        .symbolEffect(.breathe)
                    Text("Point the front camera at your face.")
                }
            }
        }
    }
}

// MARK: - Komponen

/// Tombol shutter besar: cincin kabut dengan isi warna aksen.
private struct ShutterButtonStyle: ButtonStyle {
    @Environment(\.spookyAccent) private var accent
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(accent.onColor)
            .frame(width: 66, height: 66)
            .background(Circle().fill(accent.color))
            .padding(6)
            .overlay(Circle().strokeBorder(Spooky.mist, lineWidth: 4))
            .shadow(color: accent.color.opacity(0.6), radius: 16)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

private struct StatusCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        SpookyCard {
            VStack(spacing: 12) {
                content
            }
            .font(.spooky(.headline, weight: .semibold))
            .foregroundStyle(Spooky.mist)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 40)
    }
}

private struct GhostInfoCard: View {
    let ghost: Ghost
    @Environment(\.spookyAccent) private var accent

    var body: some View {
        SpookyCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(ghost.name)
                    .font(.spooky(.title2, weight: .black))
                    .foregroundStyle(accent.color)

                Text(ghost.lore)
                    .font(.spooky(.body, weight: .medium))
                    .foregroundStyle(Spooky.mist)
            }
        }
    }
}
