//
//  HomeView.swift
//  AR2
//

import SwiftUI

struct HomeView: View {
    @Binding var isARActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // State untuk animasi floating dan denyut
    @State private var isAnimating = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // 1. Latar Belakang Gelap
            Color.black.ignoresSafeArea()

            // 2. Efek Bercak Darah (Background Layer)
            GeometryReader { geometry in
                // Bercak Kiri Atas
                Circle()
                    .fill(Color(red: 0.6, green: 0, blue: 0).opacity(0.6))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .position(x: geometry.size.width * 0.1, y: geometry.size.height * 0.1)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)

                // Tetesan Darah Kanan
                Capsule()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: 40, height: 180)
                    .blur(radius: 20)
                    .position(x: geometry.size.width * 0.85, y: geometry.size.height * 0.4)

                // Bercak Bawah
                Ellipse()
                    .fill(Color(red: 0.8, green: 0, blue: 0).opacity(0.7))
                    .frame(width: 250, height: 120)
                    .blur(radius: 50)
                    .position(x: geometry.size.width * 0.3, y: geometry.size.height * 0.8)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            // 3. Setan-Setan Lucu Melayang (Background Layer)
            GeometryReader { geometry in
                // Setan Kanan Atas
                Text(verbatim: "👻")
                    .font(.system(size: 45))
                    .foregroundStyle(.white.opacity(0.2))
                    .position(x: geometry.size.width * 0.8, y: geometry.size.height * 0.2)
                    .offset(y: isAnimating ? -20 : 20)
                    .animation(float(duration: 2.5), value: isAnimating)

                // Setan Kiri Tengah
                Text(verbatim: "👻")
                    .font(.system(size: 65))
                    .foregroundStyle(.purple.opacity(0.3))
                    .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.5)
                    .offset(x: isAnimating ? -15 : 15, y: isAnimating ? 30 : -30)
                    .animation(float(duration: 3.5), value: isAnimating)

                // Setan Kanan Bawah
                Text(verbatim: "👻")
                    .font(.system(size: 35))
                    .foregroundStyle(.white.opacity(0.15))
                    .position(x: geometry.size.width * 0.85, y: geometry.size.height * 0.7)
                    .offset(y: isAnimating ? 15 : -15)
                    .animation(float(duration: 2), value: isAnimating)
            }
            .accessibilityHidden(true)

            // 4. Konten Utama (Foreground Layer)
            VStack(spacing: 20) {
                Spacer()

                // Icon Hantu Utama
                Text(verbatim: "👻")
                    .font(.system(size: 130))
                    .shadow(color: .red, radius: 30)
                    .offset(y: isAnimating ? -10 : 10)
                    .animation(float(duration: 2), value: isAnimating)
                    .padding(.bottom, 10)
                    .accessibilityHidden(true)

                Text(verbatim: "AR GHOST")
                    .font(.system(size: 52, weight: .black, design: .serif))
                    .tracking(10)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
                    .shadow(color: .red, radius: 15, x: 0, y: 5)
                    .accessibilityAddTraits(.isHeader)

                Text("Find the cute ghost that rises from behind you and settles on top of your head...")
                    .font(.system(.body, design: .serif))
                    .italic()
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 5)

                Spacer()

                // Tombol Start Seram
                Button("SUMMON THE GHOST") {
                    isARActive = true
                }
                .buttonStyle(HauntedButtonStyle())
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: 600)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(HauntedCircleButtonStyle())
            .accessibilityLabel(Text("Settings"))
            .padding(20)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            // Memulai semua animasi saat view muncul (kecuali Reduce Motion aktif)
            isAnimating = !reduceMotion
        }
    }

    private func float(duration: Double) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
}

#Preview {
    ContentView() // Gunakan ContentView untuk preview agar state bisa dikelola dengan baik
}
