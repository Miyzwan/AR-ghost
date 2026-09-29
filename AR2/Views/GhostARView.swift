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

    var body: some View {
        ZStack {
            // Kamera AR dan 3D objek
            ARViewContainer(model: model)
                .ignoresSafeArea()

            BloodOverlayView()

            #if DEBUG
            HandDebugView(point: model.handPoint)
            #endif

            if model.clapProgress > 0 {
                ClapIndicatorView(progress: model.clapProgress)
                    .transition(.scale.combined(with: .opacity))
            }

            statusOverlay

            VStack(spacing: 16) {
                Spacer()

                if model.showGhostInfo {
                    GhostInfoCard(ghost: model.activeGhost)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                controls
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Kilatan putih saat mengambil foto
            Color.white
                .ignoresSafeArea()
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
        .animation(.spring(), value: model.showGhostInfo)
        .animation(.easeInOut(duration: 0.2), value: model.clapProgress > 0)
        .sensoryFeedback(trigger: model.punchCount) { _, _ in
            hapticsEnabled ? .impact(weight: .heavy) : nil
        }
        .sensoryFeedback(trigger: model.transformCount) { _, _ in
            hapticsEnabled ? .success : nil
        }
        .sheet(item: $capturedPhoto) { photo in
            PhotoPreviewView(photo: photo)
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
        capturedPhoto = CapturedPhoto(image: PhotoComposer.compose(snapshot))
    }

    // --- Tombol-tombol ---
    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .buttonStyle(HauntedCircleButtonStyle())
                .accessibilityLabel(Text("Settings"))

                Button {
                    model.showGhostInfo.toggle()
                } label: {
                    Text(verbatim: "?")
                }
                .buttonStyle(HauntedCircleButtonStyle())
                .accessibilityLabel(Text("Ghost info"))

                Button {
                    model.transform()
                } label: {
                    Image(systemName: "hands.sparkles.fill")
                }
                .buttonStyle(HauntedCircleButtonStyle())
                .disabled(!model.canTransform)
                .accessibilityLabel(Text("Transform the ghost"))

                Button {
                    Task { await capturePhoto() }
                } label: {
                    Image(systemName: "camera.fill")
                }
                .buttonStyle(HauntedCircleButtonStyle())
                .disabled(model.status != .running || isCapturing)
                .accessibilityLabel(Text("Take a photo"))
            }

            Button("BACK TO THE REAL WORLD") {
                isARActive = false
            }
            .buttonStyle(HauntedButtonStyle())
        }
    }

    // --- Status sesi AR ---
    @ViewBuilder
    private var statusOverlay: some View {
        switch model.status {
        case .loading:
            StatusCard {
                ProgressView().tint(.red)
                Text("Summoning the ghost…")
            }
        case .unsupported:
            StatusCard {
                Text("This device doesn't support augmented reality.")
            }
        case .interrupted:
            StatusCard {
                Text("The camera is paused.")
            }
        case .failed:
            StatusCard {
                Text("The ghost couldn't be summoned.")
                Button("Try Again") { model.retry() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        case .running:
            // Mode dunia memakai coaching overlay bawaan ARKit untuk mencari permukaan
            if model.mode == .face && !model.isTargetFound {
                StatusCard {
                    Image(systemName: "face.smiling")
                    Text("Point the front camera at your face.")
                }
            }
        }
    }
}

// MARK: - Komponen

private struct StatusCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HauntedCard {
            VStack(spacing: 12) {
                content
            }
            .font(.system(.headline, design: .serif))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 40)
    }
}

private struct GhostInfoCard: View {
    let ghost: Ghost

    var body: some View {
        HauntedCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(ghost.name)
                    .font(.system(.title2, design: .serif, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color(red: 1.0, green: 0.2, blue: 0.2))

                Text(ghost.lore)
                    .font(.system(.body, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            }
        }
    }
}

// --- Indikator gestur tepuk (menyatukan tangan) ---
private struct ClapIndicatorView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.3), lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color(red: 0.8, green: 0, blue: 0), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
                .shadow(color: Color(red: 0.8, green: 0, blue: 0), radius: 10)

            Image(systemName: "hands.sparkles.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white)
                .symbolEffect(.rotate.clockwise.byLayer, options: .repeat(.continuous))
                .shadow(color: Color(red: 0.8, green: 0, blue: 0), radius: 10)
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
