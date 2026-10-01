//
//  GhostARView.swift
//  AR2
//

import SwiftUI

struct GhostARView: View {
    @Binding var isARActive: Bool
    @State private var model = GhostARModel(mode: .preferred)
    @State private var capturedPhoto: CapturedPhoto?
    @State private var isCapturing = false
    @State private var flashOpacity = 0.0
    @State private var showSettings = false
    @AppStorage(AppSettings.hapticsEnabled) private var hapticsEnabled = true

    private var accent: SpookyAccent { .for(model.activeGhost) }

    var body: some View {
        ZStack {
            // Kamera AR dan 3D objek
            ARViewContainer(model: model)
                .ignoresSafeArea()

            SpookyVignetteView(accent: accent)

            #if DEBUG
            HandDebugView(point: model.handPoint)
            #endif

            if model.clapProgress > 0 {
                ClapIndicatorView(progress: model.clapProgress)
                    .transition(.scale.combined(with: .opacity))
            }

            statusOverlay

            VStack(spacing: 16) {
                topBar

                Spacer()

                if model.showGhostInfo {
                    GhostInfoCard(ghost: model.activeGhost)
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
        .animation(.easeInOut(duration: 0.6), value: accent)
        .sensoryFeedback(trigger: model.punchCount) { _, _ in
            hapticsEnabled ? .impact(weight: .heavy) : nil
        }
        .sensoryFeedback(trigger: model.transformCount) { _, _ in
            hapticsEnabled ? .success : nil
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

// --- Indikator gestur tepuk (menyatukan tangan) ---
private struct ClapIndicatorView: View {
    let progress: Double
    @Environment(\.spookyAccent) private var accent

    var body: some View {
        ZStack {
            Circle()
                .fill(Spooky.night.opacity(0.35))

            Circle()
                .stroke(Spooky.mist.opacity(0.25), lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
                .shadow(color: accent.color, radius: 10)

            Image(systemName: "hands.sparkles.fill")
                .font(.system(size: 50))
                .foregroundStyle(Spooky.mist)
                .symbolEffect(.rotate.clockwise.byLayer, options: .repeat(.continuous))
                .shadow(color: accent.color, radius: 10)
                .scaleEffect(1.0 + progress * 0.2)
                .animation(.easeInOut(duration: 0.2), value: progress)
        }
        .frame(width: 120, height: 120)
        .accessibilityHidden(true)
    }
}

#if DEBUG
// Lingkaran hijau yang mengikuti tangan, untuk mengecek tracking di perangkat
private struct HandDebugView: View {
    let point: CGPoint?

    var body: some View {
        // Ruang koordinat sama dengan ARView (mengabaikan safe area)
        Color.clear
            .ignoresSafeArea()
            .overlay(alignment: .topLeading) {
                if let point {
                    Circle()
                        .stroke(.green, lineWidth: 4)
                        .background(Circle().fill(.green.opacity(0.3)))
                        .frame(width: 80, height: 80)
                        .position(point)
                        .animation(.linear(duration: 0.1), value: point)
                }
            }
            .allowsHitTesting(false)
    }
}
#endif
