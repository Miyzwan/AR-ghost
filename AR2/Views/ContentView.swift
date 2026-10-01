//
//  ContentView.swift
//  AR2
//
//  Created by Dimas Dwi Ismaunnizam on 26/03/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isARActive = false
    /// 0 = portal terbuka penuh (tak terlihat), 1 = layar tertutup kabut.
    @State private var portalCover: CGFloat = 0
    // Mencegah transisi ganda jika tombol ditekan berkali-kali selama animasi portal
    @State private var isTransitioning = false
    @State private var showCameraPermission = false
    @AppStorage(AppSettings.hasSeenOnboarding) private var hasSeenOnboarding = false
    @AppStorage(AppSettings.selectedGhost) private var selectedGhostID = GhostCatalog.all[0].id

    private var isARActiveBinding: Binding<Bool> {
        Binding<Bool>(
            get: { isARActive },
            set: { newValue in
                guard !isTransitioning, newValue != isARActive else { return }
                Task {
                    if newValue {
                        await enterAR()
                    } else {
                        await returnHome()
                    }
                }
            }
        )
    }

    var body: some View {
        ZStack {
            Spooky.night.ignoresSafeArea()

            // Tampilan Utama (Home / AR)
            if isARActive {
                GhostARView(isARActive: isARActiveBinding, ghost: GhostCatalog.ghost(withID: selectedGhostID))
            } else {
                HomeView(isARActive: isARActiveBinding, selectedGhostID: $selectedGhostID)
            }

            PortalTransitionView(cover: portalCover, reduceMotion: reduceMotion)
                .allowsHitTesting(false) // Tombol di belakangnya tetap bisa ditekan jika portal terbuka
        }
        .fontDesign(.rounded)
        .tint(Spooky.pumpkin)
        .statusBarHidden()
        .sheet(isPresented: $showCameraPermission) {
            CameraPermissionView()
        }
        // Tutorial saat pertama kali dibuka, atau saat dipilih lagi dari Pengaturan
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { isPresented in
                if !isPresented { hasSeenOnboarding = true }
            }
        )) {
            OnboardingView(mode: .preferred) {
                hasSeenOnboarding = true
            }
        }
    }

    // Masuk ke alam gaib: portal menutup, berganti ke AR, lalu terbuka lagi
    private func enterAR() async {
        isTransitioning = true
        defer { isTransitioning = false }

        // Tanpa izin kamera, layar AR hanya akan hitam
        guard await CameraPermission.request() else {
            showCameraPermission = true
            return
        }

        withAnimation(.easeIn(duration: 0.7)) {
            portalCover = 1
        }
        try? await Task.sleep(for: .seconds(0.85))
        isARActive = true

        withAnimation(.timingCurve(0.3, 0.0, 0.1, 1.0, duration: 1.4)) {
            portalCover = 0
        }
        try? await Task.sleep(for: .seconds(1.4))
    }

    // Kembali ke dunia nyata
    private func returnHome() async {
        isTransitioning = true
        defer { isTransitioning = false }

        withAnimation(.easeInOut(duration: 0.7)) {
            portalCover = 1
        }
        try? await Task.sleep(for: .seconds(0.8))
        isARActive = false

        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 1.1)) {
            portalCover = 0
        }
        try? await Task.sleep(for: .seconds(1.1))
    }
}

/// Kabut malam yang menutup layar seperti iris mata, dengan cincin labu
/// di tepi lubangnya dan hantu kecil di tengah saat tertutup penuh.
struct PortalTransitionView: View, Animatable {
    var cover: CGFloat
    let reduceMotion: Bool

    // Body dihitung ulang tiap frame animasi, jadi cincin dan hantu mengikuti nilai antara
    var animatableData: CGFloat {
        get { cover }
        set { cover = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let diagonal = hypot(proxy.size.width, proxy.size.height)
            // Reduce Motion: cukup memudar, tanpa iris yang bergerak
            let holeDiameter = reduceMotion ? 0 : diagonal * 1.15 * (1 - cover)

            ZStack {
                ZStack {
                    LinearGradient(colors: [Spooky.dusk, Spooky.night], startPoint: .top, endPoint: .bottom)
                    RadialGradient(
                        colors: [Spooky.crimson.opacity(0.8), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: diagonal * 0.4
                    )
                }
                .mask {
                    Rectangle()
                        .overlay {
                            Circle()
                                .frame(width: holeDiameter, height: holeDiameter)
                                .blur(radius: 24)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }

                // Cincin bercahaya di tepi portal
                Circle()
                    .stroke(Spooky.pumpkin, lineWidth: 6)
                    .blur(radius: 10)
                    .frame(width: holeDiameter, height: holeDiameter)
                    .opacity(cover > 0 && cover < 1 ? 0.9 : 0)

                Text(verbatim: "👻")
                    .font(.system(size: 72))
                    .shadow(color: Spooky.pumpkin.opacity(0.8), radius: 20)
                    .scaleEffect(0.6 + cover * 0.4)
                    .opacity(cover > 0.85 ? Double((cover - 0.85) / 0.15) : 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .opacity(reduceMotion ? Double(cover) : (cover > 0 ? 1 : 0))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    ContentView()
}
