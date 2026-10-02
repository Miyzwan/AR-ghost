//
//  StoryOverlayView.swift
//  AR2
//

import SwiftUI

/// Gelembung cerita di layar AR: kalimat hantu (muncul huruf demi huruf dengan "suara" hantu),
/// petunjuk gestur, dan kemajuan langkah.
struct StoryCaptionView: View {
    let ghost: Ghost
    let line: LocalizedStringResource
    /// `nil` saat hantu sedang bereaksi atau pindah titik.
    let gesture: GhostGesture?
    let step: Int
    let stepCount: Int
    /// Hantu menunggu di telapak tetapi tangan belum terlihat.
    let needsHand: Bool
    /// Bertambah tiap hantu mencari perhatian; chip petunjuk berdenyut.
    let nudgeCount: Int
    @Environment(\.spookyAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0

    private var text: String { String(localized: line) }
    private var isTyping: Bool { revealed < text.count }

    var body: some View {
        SpookyCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ghost.name)
                        .font(.spooky(.subheadline, weight: .heavy))
                        .foregroundStyle(accent.color)
                        .lineLimit(1)
                    Spacer()
                    StepDots(count: stepCount, current: step)
                }

                // Huruf yang belum muncul dibuat transparan supaya tinggi kartu tidak melompat
                Text(typedText)
                    .font(.spooky(.body, weight: .semibold))
                    .foregroundStyle(Spooky.mist)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(line))

                if let gesture, !isTyping {
                    HintChip(
                        symbol: needsHand ? "hand.raised.fill" : gesture.symbol,
                        text: needsHand ? "Raise your hand" : gesture.instruction,
                        nudgeCount: nudgeCount
                    )
                    .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.4), value: isTyping)
        }
        .accessibilityElement(children: .combine)
        .task(id: "\(ghost.id)-\(step)") { await typeLine() }
    }

    private var typedText: AttributedString {
        var attributed = AttributedString(text)
        let shown = min(revealed, attributed.characters.count)
        let hiddenStart = attributed.characters.index(attributed.startIndex, offsetBy: shown)
        attributed[hiddenStart...].foregroundColor = .clear
        return attributed
    }

    /// Mengetik kalimat dan memainkan suku kata "bicara" hantu tiap beberapa huruf.
    private func typeLine() async {
        let characters = Array(text)
        guard !reduceMotion else {
            revealed = characters.count
            SoundManager.shared.playVoice(ghost.voice)
            return
        }
        revealed = 0
        for index in characters.indices {
            try? await Task.sleep(for: .milliseconds(characters[index].isPunctuation ? 90 : 28))
            guard !Task.isCancelled else { return }
            revealed = index + 1
            if index % 3 == 0, characters[index].isLetter {
                SoundManager.shared.playVoice(ghost.voice)
            }
        }
    }
}

/// Seruan besar yang meletup di layar saat gestur berhasil ("Yum!", "ARRR!").
struct CheerPopView: View {
    let text: LocalizedStringResource
    @Environment(\.spookyAccent) private var accent

    var body: some View {
        Text(text)
            .font(.system(size: 48, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: [.white, accent.color], startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: accent.color.opacity(0.9), radius: 14)
            .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
            .rotationEffect(.degrees(-6))
            .multilineTextAlignment(.center)
            .accessibilityHidden(true)
    }
}

/// Hujan confetti singkat saat cerita selesai.
struct ConfettiView: View {
    /// Waktu mulai; confetti jatuh sekali lalu habis.
    let start: Date
    @Environment(\.spookyAccent) private var accent

    private struct Piece {
        var x: Double, delay: Double, speed: Double, spin: Double, size: Double, sway: Double, hue: Int
    }

    private static let pieces: [Piece] = {
        // Acak tetap (deterministik) supaya tidak berubah tiap render
        var seed: UInt64 = 0x5EED
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt64(1) << 31)
        }
        return (0..<70).map { _ in
            Piece(x: next(), delay: next() * 0.6, speed: 0.35 + next() * 0.35, spin: next() * 8 - 4, size: 6 + next() * 7, sway: next() * 2 * .pi, hue: Int(next() * 4))
        }
    }()

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start)
            Canvas { canvas, size in
                let colors: [Color] = [accent.color, Spooky.mist, Spooky.blood, Spooky.pumpkin]
                for piece in Self.pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + t * piece.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 3 + piece.sway) * 24
                    var context = canvas
                    context.translateBy(x: x, y: y)
                    context.rotate(by: .radians(t * piece.spin))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(colors[piece.hue]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Kartu penutup cerita: rahasia terakhir dan ajakan bertepuk tangan untuk hantu berikutnya.
struct StoryFinaleView: View {
    let line: LocalizedStringResource
    let nextGhost: Ghost
    @Environment(\.spookyAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SpookyCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Story complete!", systemImage: "checkmark.seal.fill")
                    .font(.spooky(.headline, weight: .heavy))
                    .foregroundStyle(accent.color)

                Text(line)
                    .font(.spooky(.body, weight: .semibold))
                    .foregroundStyle(Spooky.mist)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Image(systemName: "hands.clap.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(accent.color)
                        .symbolEffect(.bounce, options: .repeat(.continuous), isActive: !reduceMotion)
                        .accessibilityHidden(true)
                    Text("Clap to summon \(String(localized: nextGhost.name))")
                        .font(.spooky(.subheadline, weight: .bold))
                        .foregroundStyle(Spooky.mist)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(accent.color.opacity(0.18), in: .capsule)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Cincin progres di tengah layar selama gestur ditahan (tepuk atau gestur cerita).
struct GestureProgressRing: View {
    let progress: Double
    let symbol: String
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

            Image(systemName: symbol)
                .font(.system(size: 50))
                .foregroundStyle(Spooky.mist)
                .shadow(color: accent.color, radius: 10)
                .scaleEffect(1.0 + progress * 0.2)
                .animation(.easeInOut(duration: 0.2), value: progress)
        }
        .frame(width: 120, height: 120)
        .accessibilityHidden(true)
    }
}

/// Chip petunjuk: ikon gestur dan instruksi singkat. Berdenyut saat hantu mencari perhatian.
private struct HintChip: View {
    let symbol: String
    let text: LocalizedStringResource
    let nudgeCount: Int
    @Environment(\.spookyAccent) private var accent

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .symbolEffect(.bounce, value: nudgeCount)
        }
        .font(.spooky(.subheadline, weight: .bold))
        .foregroundStyle(accent.onColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(accent.color, in: .capsule)
        .shadow(color: accent.color.opacity(0.6), radius: 10)
        .keyframeAnimator(initialValue: 1.0, trigger: nudgeCount) { content, scale in
            content.scaleEffect(scale, anchor: .leading)
        } keyframes: { _ in
            SpringKeyframe(1.18, duration: 0.18)
            SpringKeyframe(0.96, duration: 0.18)
            SpringKeyframe(1.0, duration: 0.3)
        }
    }
}

/// Titik langkah cerita: yang sudah lewat terisi, langkah saat ini memanjang.
private struct StepDots: View {
    let count: Int
    let current: Int
    @Environment(\.spookyAccent) private var accent

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? accent.color : Spooky.mist.opacity(0.3))
                    .frame(width: index == current ? 16 : 6, height: 6)
            }
        }
        .animation(.spring(duration: 0.3), value: current)
        .accessibilityHidden(true)
    }
}

#Preview {
    let ghost = GhostCatalog.all[0]
    ZStack {
        SpookyBackground()
        VStack(spacing: 20) {
            GestureProgressRing(progress: 0.6, symbol: GhostGesture.smile.symbol)
            CheerPopView(text: ghost.story.steps[0].cheer)
            StoryCaptionView(ghost: ghost, line: ghost.story.steps[0].line, gesture: .smile, step: 0, stepCount: 3, needsHand: false, nudgeCount: 0)
            StoryFinaleView(line: ghost.story.finale, nextGhost: GhostCatalog.all[1])
        }
        .padding(20)
    }
}
