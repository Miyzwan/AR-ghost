//
//  StoryOverlayView.swift
//  AR2
//

import SwiftUI

/// Isi gelembung cerita: kalimat singkat hantu (muncul huruf demi huruf dengan "suara" hantu)
/// dan perintah gestur yang terisi selama gestur ditahan.
struct StoryCaptionView: View {
    let ghost: Ghost
    let line: LocalizedStringResource
    let gesture: GhostGesture
    let step: Int
    let stepCount: Int
    /// Hantu menunggu di telapak tetapi tangan belum terlihat.
    let needsHand: Bool
    /// 0...1 menuju gestur yang diminta.
    let progress: Double
    /// Bertambah tiap hantu mencari perhatian; perintah berdenyut.
    let nudgeCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0

    private var text: String { String(localized: line) }
    private var isTyping: Bool { revealed < text.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Huruf yang belum muncul dibuat transparan supaya ukuran gelembung tidak melompat
            Text(typedText)
                .font(.spooky(.callout, weight: .bold))
                .foregroundStyle(Spooky.mist)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(line))

            HStack(spacing: 8) {
                HintChip(
                    symbol: needsHand ? "hand.raised.fill" : gesture.symbol,
                    text: needsHand ? "Raise your hand" : gesture.instruction,
                    progress: progress,
                    nudgeCount: nudgeCount
                )
                Spacer(minLength: 0)
                StepDots(count: stepCount, current: step)
            }
            // Perintah muncul setelah kalimat selesai, tetapi ruangnya sudah disiapkan
            .opacity(isTyping ? 0 : 1)
            .scaleEffect(isTyping ? 0.6 : 1, anchor: .leading)
            .animation(.spring(duration: 0.4, bounce: 0.5), value: isTyping)
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

/// Lapisan gelembung cerita. Gelembung mengikuti hantu di layar dan mencari tempat yang tidak
/// menutupi hantu maupun wajah pengguna (`StoryBubbleLayout`).
struct StoryBubbleLayer<Content: View>: View {
    let model: GhostARModel
    /// Berubah tiap langkah cerita; posisi gelembung dicari ulang dari awal.
    let key: String
    @ViewBuilder var content: Content
    @Environment(\.spookyAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var size: CGSize = .zero
    @State private var slot: StoryBubbleLayout.Slot?
    @State private var appeared = false

    /// Ruang bar atas dan tombol bawah yang tidak boleh tertutup.
    private static var topInset: CGFloat { 64 }
    private static var bottomInset: CGFloat { 104 }

    var body: some View {
        GeometryReader { proxy in
            // Kotak dari model dalam koordinat ARView (layar penuh); lapisan ini di dalam safe area
            let origin = proxy.frame(in: .global).origin
            let local = { (rect: CGRect) in rect.offsetBy(dx: -origin.x, dy: -origin.y) }
            let bounds = CGRect(
                x: 0, y: Self.topInset,
                width: proxy.size.width, height: max(proxy.size.height - Self.topInset - Self.bottomInset, 0)
            )
            let screen = model.screenLayout
            let layout = StoryBubbleLayout.place(
                size: size,
                ghost: screen.map { local($0.ghost) },
                face: screen?.face.map(local),
                in: bounds,
                preferring: slot
            )

            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(StoryBubbleLayout.tailLength)
                .frame(width: min(270, proxy.size.width))
                .background {
                    SpeechBubbleShape(tail: layout.tail, tailOffset: layout.tailOffset)
                        .fill(Spooky.night.opacity(0.55))
                        .glassEffect(.regular.tint(accent.color.opacity(0.12)), in: SpeechBubbleShape(tail: layout.tail, tailOffset: layout.tailOffset))
                        .overlay {
                            SpeechBubbleShape(tail: layout.tail, tailOffset: layout.tailOffset)
                                .stroke(accent.color.opacity(0.8), lineWidth: 1.5)
                        }
                        .shadow(color: accent.color.opacity(0.35), radius: 10)
                }
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                // Meletup dari ujung ekor, seperti keluar dari mulut hantu
                .scaleEffect(appeared ? 1 : 0.3, anchor: Self.anchor(of: layout))
                .opacity(size == .zero || !appeared ? 0 : 1)
                .position(x: layout.frame.midX, y: layout.frame.midY)
                .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: layout)
                .onChange(of: layout.slot) { _, newSlot in slot = newSlot }
                .onChange(of: key) { slot = nil }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.5)) { appeared = true }
        }
    }

    private static func anchor(of layout: StoryBubbleLayout) -> UnitPoint {
        let frame = layout.frame
        guard frame.width > 0, frame.height > 0 else { return .center }
        return switch layout.tail {
        case .none: .top
        case .bottom: UnitPoint(x: layout.tailOffset / frame.width, y: 1)
        case .top: UnitPoint(x: layout.tailOffset / frame.width, y: 0)
        case .leading: UnitPoint(x: 0, y: layout.tailOffset / frame.height)
        case .trailing: UnitPoint(x: 1, y: layout.tailOffset / frame.height)
        }
    }
}

/// Seruan yang meletup tepat di atas hantu; di tepi atas bila hantu tidak terlihat.
struct CheerLayer: View {
    let model: GhostARModel
    let text: LocalizedStringResource

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            let ghost = model.screenLayout?.ghost.offsetBy(dx: -origin.x, dy: -origin.y)
            CheerPopView(text: text)
                .fixedSize()
                .position(
                    x: min(max(ghost?.midX ?? proxy.size.width / 2, 110), proxy.size.width - 110),
                    y: max((ghost?.minY ?? 0) - 36, 120)
                )
        }
        .allowsHitTesting(false)
    }
}

/// Gelembung bicara: kotak membulat dengan ekor di satu sisi yang menunjuk hantu.
/// Kotaknya menjorok `StoryBubbleLayout.tailLength` dari tiap tepi untuk ruang ekor.
struct SpeechBubbleShape: Shape {
    var tail: StoryBubbleLayout.Tail
    /// Posisi ujung ekor sepanjang sisinya, dari kiri (atas/bawah) atau dari atas (samping).
    var tailOffset: CGFloat

    var animatableData: CGFloat {
        get { tailOffset }
        set { tailOffset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let length = StoryBubbleLayout.tailLength
        let body = rect.insetBy(dx: length, dy: length)
        let bubble = Path(roundedRect: body, cornerRadius: 20, style: .continuous)
        let half: CGFloat = 9
        var pointer = Path()
        switch tail {
        case .none:
            return bubble
        case .bottom:
            let x = rect.minX + tailOffset
            pointer.addLines([CGPoint(x: x - half, y: body.maxY - 1), CGPoint(x: x, y: rect.maxY), CGPoint(x: x + half, y: body.maxY - 1)])
        case .top:
            let x = rect.minX + tailOffset
            pointer.addLines([CGPoint(x: x - half, y: body.minY + 1), CGPoint(x: x, y: rect.minY), CGPoint(x: x + half, y: body.minY + 1)])
        case .leading:
            let y = rect.minY + tailOffset
            pointer.addLines([CGPoint(x: body.minX + 1, y: y - half), CGPoint(x: rect.minX, y: y), CGPoint(x: body.minX + 1, y: y + half)])
        case .trailing:
            let y = rect.minY + tailOffset
            pointer.addLines([CGPoint(x: body.maxX - 1, y: y - half), CGPoint(x: rect.maxX, y: y), CGPoint(x: body.maxX - 1, y: y + half)])
        }
        pointer.closeSubpath()
        return bubble.union(pointer)
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

/// Isi gelembung penutup: rahasia terakhir dan ajakan bertepuk tangan untuk hantu berikutnya.
struct StoryFinaleView: View {
    let line: LocalizedStringResource
    let nextGhost: Ghost
    /// 0...1 menuju tepuk tangan.
    let clapProgress: Double
    @Environment(\.spookyAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Story complete!", systemImage: "checkmark.seal.fill")
                .font(.spooky(.caption, weight: .heavy))
                .foregroundStyle(accent.color)

            Text(line)
                .font(.spooky(.callout, weight: .bold))
                .foregroundStyle(Spooky.mist)
                .fixedSize(horizontal: false, vertical: true)

            HintChip(
                symbol: "hands.clap.fill",
                text: "Clap to meet \(String(localized: nextGhost.name))",
                progress: clapProgress,
                nudgeCount: 0,
                bounces: true
            )
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

/// Perintah gestur: ikon dan kata kerja singkat. Terisi selama gestur ditahan, dan berdenyut
/// saat hantu mencari perhatian.
private struct HintChip: View {
    let symbol: String
    let text: LocalizedStringResource
    let progress: Double
    let nudgeCount: Int
    /// Ikon terus memantul (ajakan tepuk tangan di penutup).
    var bounces = false
    @Environment(\.spookyAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label {
            Text(text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .symbolEffect(.bounce, value: nudgeCount)
                .symbolEffect(.bounce, options: .repeat(.continuous), isActive: bounces && !reduceMotion)
        }
        .font(.spooky(.subheadline, weight: .heavy))
        .foregroundStyle(accent.onColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(accent.color)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(.white.opacity(0.4))
                            .frame(width: proxy.size.width * min(max(progress, 0), 1))
                    }
                }
                .clipShape(.rect(cornerRadius: 17, style: .continuous))
                .animation(.linear(duration: 0.1), value: progress)
        }
        .shadow(color: accent.color.opacity(0.6), radius: 8)
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
            GestureProgressRing(progress: 0.6, symbol: "hands.clap.fill")
            CheerPopView(text: ghost.story.steps[0].cheer)
            StoryCaptionView(ghost: ghost, line: ghost.story.steps[0].line, gesture: .smile, step: 0, stepCount: 3, needsHand: false, progress: 0.4, nudgeCount: 0)
                .padding(26)
                .frame(width: 270)
                .background(SpeechBubbleShape(tail: .bottom, tailOffset: 135).fill(Spooky.night.opacity(0.8)))
            StoryFinaleView(line: ghost.story.finale, nextGhost: GhostCatalog.all[1], clapProgress: 0.3)
                .padding(26)
                .frame(width: 270)
                .background(SpeechBubbleShape(tail: .leading, tailOffset: 40).fill(Spooky.night.opacity(0.8)))
        }
        .padding(20)
    }
}
