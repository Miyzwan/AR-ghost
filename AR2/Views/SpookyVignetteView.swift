//
//  SpookyVignetteView.swift
//  AR2
//

import SwiftUI

/// Kabut merah darah yang bernapas di tepi layar AR. Berpendar warna aksen
/// (oranye saat lucu, merah terang saat wujud asli).
struct SpookyVignetteView: View {
    var accent: SpookyAccent = .pumpkin

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                // Bayangan malam di pinggir agar kontrol tetap terbaca di atas kamera
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [.clear, .clear, Spooky.night.opacity(0.75)],
                            center: .center,
                            startRadius: min(w, h) * 0.35,
                            endRadius: max(w, h) * 0.75
                        )
                    )

                // Cahaya aksen di pinggir, bernapas pelan
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [.clear, .clear, accent.color.opacity(0.35), Spooky.crimson.opacity(0.6)],
                            center: .center,
                            startRadius: min(w, h) * 0.4,
                            endRadius: max(w, h) * 0.8
                        )
                    )
                    .opacity(isBreathing ? 1 : 0.55)

                // Kabut tebal di bawah, di belakang tombol
                Ellipse()
                    .fill(Spooky.crimson.opacity(0.55))
                    .frame(width: w * 1.6, height: h * 0.32)
                    .blur(radius: 60)
                    .position(x: w / 2, y: h * 1.04)
                    .offset(x: isBreathing ? 20 : -20)

                // Kabut tipis di atas
                Ellipse()
                    .fill(Spooky.night.opacity(0.7))
                    .frame(width: w * 1.6, height: h * 0.2)
                    .blur(radius: 50)
                    .position(x: w / 2, y: -h * 0.02)
            }
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 3.2).repeatForever(autoreverses: true),
                value: isBreathing
            )
            .animation(.easeInOut(duration: 0.6), value: accent)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            // Reduce Motion: kabut tetap tampil tapi diam
            isBreathing = !reduceMotion
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        SpookyVignetteView(accent: .blood)
    }
}
