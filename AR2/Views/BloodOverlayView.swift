//
//  BloodOverlayView.swift
//  AR2
//

import SwiftUI

/// Efek darah berdenyut dan menetes di tepi layar AR.
struct BloodOverlayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    /// Satu tetesan darah: ketebalan, panjang saat berdenyut/diam, tingkat merah, dan ritme animasi.
    private struct Drip {
        let thickness: CGFloat
        let pulsedLength: CGFloat
        let restingLength: CGFloat
        let red: Double
        let duration: Double
        let delay: Double
    }

    private enum Edge {
        case top, bottom, leading, trailing
    }

    private let topDrips = [
        Drip(thickness: 10, pulsedLength: 150, restingLength: 80, red: 0.5, duration: 1.5, delay: 0),
        Drip(thickness: 15, pulsedLength: 90, restingLength: 180, red: 0.4, duration: 2.5, delay: 0.5),
        Drip(thickness: 8, pulsedLength: 120, restingLength: 60, red: 0.7, duration: 1.8, delay: 0.2),
        Drip(thickness: 22, pulsedLength: 200, restingLength: 130, red: 0.3, duration: 3.0, delay: 1.0),
        Drip(thickness: 12, pulsedLength: 100, restingLength: 50, red: 0.55, duration: 2.0, delay: 0.7),
    ]
    private let bottomDrips = [
        Drip(thickness: 12, pulsedLength: 120, restingLength: 70, red: 0.5, duration: 2.0, delay: 0.3),
        Drip(thickness: 18, pulsedLength: 80, restingLength: 140, red: 0.4, duration: 2.8, delay: 0.8),
        Drip(thickness: 10, pulsedLength: 100, restingLength: 55, red: 0.6, duration: 1.6, delay: 0.1),
        Drip(thickness: 25, pulsedLength: 160, restingLength: 100, red: 0.35, duration: 3.2, delay: 1.2),
    ]
    private let leadingDrips = [
        Drip(thickness: 10, pulsedLength: 130, restingLength: 70, red: 0.5, duration: 2.2, delay: 0.4),
        Drip(thickness: 14, pulsedLength: 80, restingLength: 140, red: 0.6, duration: 2.8, delay: 0.9),
        Drip(thickness: 8, pulsedLength: 110, restingLength: 50, red: 0.4, duration: 1.9, delay: 0.6),
        Drip(thickness: 20, pulsedLength: 170, restingLength: 90, red: 0.55, duration: 3.5, delay: 1.1),
    ]
    private let trailingDrips = [
        Drip(thickness: 12, pulsedLength: 100, restingLength: 55, red: 0.45, duration: 2.4, delay: 0.5),
        Drip(thickness: 16, pulsedLength: 150, restingLength: 80, red: 0.6, duration: 2.0, delay: 0.2),
        Drip(thickness: 10, pulsedLength: 90, restingLength: 160, red: 0.35, duration: 3.0, delay: 1.0),
        Drip(thickness: 22, pulsedLength: 120, restingLength: 65, red: 0.5, duration: 2.6, delay: 0.8),
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                // Vignette radial merah
                Rectangle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.clear, .clear, Color(red: 0.6, green: 0, blue: 0)]),
                            center: .center,
                            startRadius: min(w, h) * 0.3,
                            endRadius: max(w, h) * 0.7
                        )
                    )
                    .opacity(isPulsing ? 1.0 : 0.4)
                    .animation(pulse(duration: 2.0), value: isPulsing)

                // Vignette merah di tiap sisi
                edgeGlow(.leading, size: 80, strong: 0.6, weak: 0.4, strongOpacity: 0.9, weakOpacity: 0.3, duration: 2.5, delay: 0)
                edgeGlow(.trailing, size: 80, strong: 0.6, weak: 0.4, strongOpacity: 0.9, weakOpacity: 0.3, duration: 2.8, delay: 0.3)
                edgeGlow(.top, size: 70, strong: 0.5, weak: 0.3, strongOpacity: 0.8, weakOpacity: 0.2, duration: 2.2, delay: 0.5)
                edgeGlow(.bottom, size: 70, strong: 0.5, weak: 0.3, strongOpacity: 0.8, weakOpacity: 0.2, duration: 2.6, delay: 0.7)

                // Tetesan darah di keempat sisi
                HStack(alignment: .top, spacing: w / 7) { drips(topDrips, from: .top) }
                    .position(x: w / 2, y: 0)
                HStack(alignment: .bottom, spacing: w / 6) { drips(bottomDrips, from: .bottom) }
                    .position(x: w / 2, y: h)
                VStack(alignment: .leading, spacing: h / 7) { drips(leadingDrips, from: .leading) }
                    .position(x: 0, y: h / 2)
                VStack(alignment: .trailing, spacing: h / 7) { drips(trailingDrips, from: .trailing) }
                    .position(x: w, y: h / 2)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            // Reduce Motion: efek tetap tampil tapi tidak berdenyut
            isPulsing = !reduceMotion
        }
    }

    private func pulse(duration: Double, delay: Double = 0) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)
    }

    @ViewBuilder
    private func drips(_ drips: [Drip], from edge: Edge) -> some View {
        ForEach(drips.indices, id: \.self) { index in
            let drip = drips[index]
            let length = isPulsing ? drip.pulsedLength : drip.restingLength
            let isVertical = edge == .top || edge == .bottom
            Capsule()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color(red: drip.red, green: 0, blue: 0), .clear]),
                    startPoint: startPoint(for: edge),
                    endPoint: endPoint(for: edge)
                ))
                .frame(
                    width: isVertical ? drip.thickness : length,
                    height: isVertical ? length : drip.thickness
                )
                .animation(pulse(duration: drip.duration, delay: drip.delay), value: isPulsing)
        }
    }

    @ViewBuilder
    private func edgeGlow(
        _ edge: Edge, size: CGFloat, strong: Double, weak: Double,
        strongOpacity: Double, weakOpacity: Double, duration: Double, delay: Double
    ) -> some View {
        let gradient = LinearGradient(
            gradient: Gradient(colors: [
                Color(red: strong, green: 0, blue: 0).opacity(strongOpacity),
                Color(red: weak, green: 0, blue: 0).opacity(weakOpacity),
                .clear,
            ]),
            startPoint: startPoint(for: edge),
            endPoint: endPoint(for: edge)
        )
        let isVertical = edge == .top || edge == .bottom
        Rectangle()
            .fill(gradient)
            .frame(width: isVertical ? nil : size, height: isVertical ? size : nil)
            .opacity(isPulsing ? 1.0 : 0.5)
            .animation(pulse(duration: duration, delay: delay), value: isPulsing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: edge))
    }

    private func startPoint(for edge: Edge) -> UnitPoint {
        switch edge {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }

    private func endPoint(for edge: Edge) -> UnitPoint {
        switch edge {
        case .top: .bottom
        case .bottom: .top
        case .leading: .trailing
        case .trailing: .leading
        }
    }

    private func alignment(for edge: Edge) -> Alignment {
        switch edge {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }
}
