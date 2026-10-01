//
//  OnboardingView.swift
//  AR2
//

import SwiftUI

/// Tutorial singkat saat pertama kali membuka app. Isinya menyesuaikan mode AR perangkat.
struct OnboardingView: View {
    let mode: ARMode
    var onFinish: () -> Void

    @State private var page = 0

    private struct Page {
        let symbol: String
        let title: LocalizedStringResource
        let message: LocalizedStringResource
    }

    private var pages: [Page] {
        switch mode {
        case .face:
            [
                Page(
                    symbol: "sparkles",
                    title: "Meet Mister Q",
                    message: "A mischievous ghost is waiting to haunt you. Summon him and he'll rise from behind your head and settle right on top of it."
                ),
                Page(
                    symbol: "hand.raised.fill",
                    title: "Punch him away",
                    message: "Swing your hand quickly toward the ghost to knock him flying."
                ),
                Page(
                    symbol: "hands.sparkles.fill",
                    title: "Change his form",
                    message: "Hold both hands together in front of the camera until the circle fills up. He might not stay cute..."
                ),
            ]
        case .world:
            [
                Page(
                    symbol: "sparkles",
                    title: "Meet Mister Q",
                    message: "A mischievous ghost is waiting to haunt you. Point your camera at the floor or a table and he'll rise right out of it."
                ),
                Page(
                    symbol: "hand.raised.fill",
                    title: "Punch him away",
                    message: "Swing your hand quickly in front of the camera to knock him flying."
                ),
                Page(
                    symbol: "hands.sparkles.fill",
                    title: "Change his form",
                    message: "Hold both hands together in front of the camera until the circle fills up. He might not stay cute..."
                ),
            ]
        }
    }

    var body: some View {
        ZStack {
            SpookyBackground()

            VStack(spacing: 20) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator

                Button(page < pages.count - 1 ? LocalizedStringKey("NEXT") : LocalizedStringKey("LET'S GO")) {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                }
                .buttonStyle(SpookyButtonStyle())
                .padding(.horizontal, 32)

                Button("Skip") {
                    onFinish()
                }
                .buttonStyle(SpookyTextButtonStyle())
                .opacity(page < pages.count - 1 ? 1 : 0)
                .disabled(page == pages.count - 1)
            }
            .padding(.bottom, 16)
        }
        .fontDesign(.rounded)
        .statusBarHidden()
    }

    // Titik halaman: kapsul memanjang untuk halaman aktif
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Spooky.pumpkin : Spooky.mist.opacity(0.25))
                    .frame(width: index == page ? 28 : 8, height: 8)
            }
        }
        .animation(.spring(duration: 0.35), value: page)
        .accessibilityHidden(true)
    }

    private func pageView(_ page: Page) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                GlowOrb(symbol: page.symbol, size: 150)
                    .padding(.top, 72)

                Text(page.title)
                    .font(.spooky(.largeTitle, weight: .black))
                    .foregroundStyle(Spooky.mist)
                    .accessibilityAddTraits(.isHeader)

                Text(page.message)
                    .font(.spooky(.title3, weight: .medium))
                    .foregroundStyle(Spooky.mistDim)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview {
    OnboardingView(mode: .face) {}
}
