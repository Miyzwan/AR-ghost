//
//  HomeView.swift
//  AR2
//

import SwiftUI

struct HomeView: View {
    @Binding var isARActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSettings = false
    @State private var isGlowing = false

    private let mode = ARMode.preferred

    var body: some View {
        ZStack {
            SpookyBackground()

            VStack(spacing: 0) {
                // Bintang utama: Mister Q dalam 3D
                GhostHeroView()
                    .frame(minHeight: 150, maxHeight: 340)
                    .padding(.top, 40)

                VStack(spacing: 14) {
                    Text(verbatim: "AR GHOST")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .tracking(6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(
                            LinearGradient(colors: [.white, Spooky.mist, Spooky.pumpkin], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: Spooky.pumpkin.opacity(isGlowing ? 0.7 : 0.3), radius: 18)
                        .accessibilityAddTraits(.isHeader)

                    Text("Meet Mister Q. Cute… until he isn't.")
                        .font(.spooky(.title3, weight: .medium))
                        .foregroundStyle(Spooky.mistDim)
                        .multilineTextAlignment(.center)

                    modeChip
                        .padding(.top, 4)
                }
                .padding(.top, 8)

                Spacer(minLength: 24)

                Button("SUMMON THE GHOST") {
                    isARActive = true
                }
                .buttonStyle(SpookyButtonStyle())
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: 600)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(SpookyIconButtonStyle())
            .accessibilityLabel(Text("Settings"))
            .padding(20)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }

    // Memberi tahu di mana hantu akan muncul, sesuai kamera perangkat
    private var modeChip: some View {
        Label {
            switch mode {
            case .face: Text("Appears above your head")
            case .world: Text("Appears on a floor or table")
            }
        } icon: {
            Image(systemName: mode == .face ? "face.smiling" : "square.3.layers.3d.down.right")
        }
        .font(.spooky(.subheadline, weight: .semibold))
        .foregroundStyle(Spooky.mist)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}

#Preview {
    ContentView() // Gunakan ContentView untuk preview agar state bisa dikelola dengan baik
}
