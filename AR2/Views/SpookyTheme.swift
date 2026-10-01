//
//  SpookyTheme.swift
//  AR2
//

import SwiftUI

/// Palet "cute-spooky": malam merah darah, cahaya putih tulang, dan pendar labu.
enum Spooky {
    static let night = Color(red: 0.07, green: 0.016, blue: 0.024)
    static let dusk = Color(red: 0.17, green: 0.027, blue: 0.04)
    static let crimson = Color(red: 0.55, green: 0.04, blue: 0.07)
    static let mist = Color(red: 0.97, green: 0.92, blue: 0.88)
    static let mistDim = mist.opacity(0.68)
    static let pumpkin = Color(red: 1.0, green: 0.54, blue: 0.24)
    static let blood = Color(red: 1.0, green: 0.23, blue: 0.24)
}

/// Warna aksen UI: oranye labu, berubah merah terang saat hantu menampakkan wujud aslinya.
struct SpookyAccent: Equatable {
    let color: Color
    /// Warna teks/ikon di atas `color`.
    let onColor: Color

    static let pumpkin = SpookyAccent(color: Spooky.pumpkin, onColor: Spooky.night)
    static let blood = SpookyAccent(color: Spooky.blood, onColor: .white)

    static func `for`(_ ghost: Ghost) -> SpookyAccent {
        switch ghost.mood {
        case .cute: .pumpkin
        case .angry: .blood
        }
    }
}

extension EnvironmentValues {
    @Entry var spookyAccent: SpookyAccent = .pumpkin
}

extension Font {
    /// Semua teks memakai SF Rounded agar terasa lucu, bukan kaku.
    static func spooky(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

// MARK: - Tombol

/// Tombol utama: kapsul bercahaya warna aksen.
struct SpookyButtonStyle: ButtonStyle {
    @Environment(\.spookyAccent) private var accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.spooky(.title3, weight: .heavy))
            .tracking(1.5)
            .multilineTextAlignment(.center)
            .foregroundStyle(accent.onColor)
            .frame(maxWidth: 460)
            .padding(.vertical, 18)
            .padding(.horizontal, 24)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [accent.color, accent.color.mix(with: .white, by: 0.25)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: accent.color.opacity(configuration.isPressed ? 0.3 : 0.55), radius: 22, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Tombol ikon bulat dari kaca (Liquid Glass).
struct SpookyIconButtonStyle: ButtonStyle {
    var size: CGFloat = 52
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundStyle(Spooky.mist)
            .frame(width: size, height: size)
            // Seluruh lingkaran bisa disentuh, bukan hanya garis ikonnya (ikon tipis seperti "xmark"
            // dulu nyaris tidak bisa ditekan dan sentuhannya tembus ke ARView)
            .contentShape(.circle)
            .glassEffect(.regular.interactive(), in: .circle)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Tombol teks sekunder ("Skip", "Not Now").
struct SpookyTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.spooky(.body, weight: .semibold))
            .foregroundStyle(Spooky.mistDim)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

// MARK: - Kartu & lencana

/// Kartu kaca untuk teks di atas kamera atau latar.
struct SpookyCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: 500, alignment: .leading)
            .glassEffect(.regular.tint(Spooky.night.opacity(0.35)), in: .rect(cornerRadius: 28))
    }
}

/// Ikon SF Symbol di dalam bola merah gelap yang berpendar.
struct GlowOrb: View {
    let symbol: String
    var size: CGFloat = 132
    @Environment(\.spookyAccent) private var accent

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.color.opacity(0.28))
                .blur(radius: size * 0.3)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Spooky.crimson, Spooky.dusk],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .overlay(Circle().strokeBorder(accent.color.opacity(0.5), lineWidth: 1.5))
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Spooky.mist)
                .shadow(color: accent.color.opacity(0.8), radius: 12)
                .symbolEffect(.breathe)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Latar

/// Langit malam dengan kabut melayang dan bintang berkelip.
struct SpookyBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrifting = false

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let phase: Double
        let speed: Double
    }

    // Posisi bintang tetap (pseudo-acak deterministik) agar tidak meloncat saat view dibuat ulang
    private static let stars: [Star] = {
        var seed: UInt64 = 0x5EED
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        return (0..<70).map { _ in
            Star(
                x: next(),
                y: next() * 0.75,
                radius: 0.6 + next() * 1.4,
                phase: next() * .pi * 2,
                speed: 0.6 + next() * 1.6
            )
        }
    }()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Spooky.night, Spooky.dusk, Spooky.night], startPoint: .top, endPoint: .bottom)

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                Circle()
                    .fill(Spooky.crimson.opacity(0.55))
                    .frame(width: w * 0.9)
                    .blur(radius: 80)
                    .position(x: w * 0.15, y: h * 0.18)
                    .offset(x: isDrifting ? 30 : -20, y: isDrifting ? 20 : -10)

                Circle()
                    .fill(Spooky.pumpkin.opacity(0.12))
                    .frame(width: w * 0.8)
                    .blur(radius: 90)
                    .position(x: w * 0.9, y: h * 0.55)
                    .offset(x: isDrifting ? -40 : 10)

                Ellipse()
                    .fill(Spooky.crimson.opacity(0.5))
                    .frame(width: w * 1.4, height: h * 0.3)
                    .blur(radius: 70)
                    .position(x: w * 0.5, y: h * 1.02)
                    .offset(x: isDrifting ? 25 : -25)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 9).repeatForever(autoreverses: true), value: isDrifting)

            TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                Canvas { canvas, size in
                    for star in Self.stars {
                        let twinkle = reduceMotion ? 0.7 : 0.45 + 0.55 * (0.5 + 0.5 * sin(time * star.speed + star.phase))
                        let rect = CGRect(
                            x: star.x * size.width - star.radius,
                            y: star.y * size.height - star.radius,
                            width: star.radius * 2,
                            height: star.radius * 2
                        )
                        canvas.fill(Path(ellipseIn: rect), with: .color(Spooky.mist.opacity(twinkle * 0.8)))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear {
            isDrifting = !reduceMotion
        }
    }
}

#Preview {
    ZStack {
        SpookyBackground()
        VStack(spacing: 24) {
            GlowOrb(symbol: "sparkles")
            SpookyCard {
                Text(verbatim: "Mister Q").font(.spooky(.title))
            }
            Button("SUMMON THE GHOST") {}
                .buttonStyle(SpookyButtonStyle())
            Button {} label: { Image(systemName: "gearshape.fill") }
                .buttonStyle(SpookyIconButtonStyle())
        }
        .padding()
    }
}
