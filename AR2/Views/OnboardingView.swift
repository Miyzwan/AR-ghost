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
                    message: "Swing your hand quickly toward the ghost to knock him flying. You can also just tap him."
                ),
                Page(
                    symbol: "hands.sparkles.fill",
                    title: "Change his form",
                    message: "Hold both hands together in front of the camera until the circle fills up, or press the sparkle button. He might not stay cute..."
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
                    symbol: "hand.tap.fill",
                    title: "Punch him away",
                    message: "Tap the ghost, or swing your hand quickly in front of the camera, to knock him flying."
                ),
                Page(
                    symbol: "hands.sparkles.fill",
                    title: "Change his form",
                    message: "Press the sparkle button to transform him. He might not stay cute..."
                ),
            ]
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page < pages.count - 1 ? LocalizedStringKey("NEXT") : LocalizedStringKey("LET'S GO")) {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            }
            .buttonStyle(HauntedButtonStyle())
            .padding(.horizontal, 40)

            Button("Skip") {
                onFinish()
            }
            .font(.system(.body, design: .serif))
            .foregroundStyle(.gray)
            .opacity(page < pages.count - 1 ? 1 : 0)
            .disabled(page == pages.count - 1)
        }
        .padding(.bottom, 24)
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
    }

    private func pageView(_ page: Page) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: page.symbol)
                    .font(.system(size: 90))
                    .foregroundStyle(.white)
                    .shadow(color: .red, radius: 25)
                    .padding(.top, 60)
                    .accessibilityHidden(true)

                Text(page.title)
                    .font(.system(.largeTitle, design: .serif, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .red, radius: 10)
                    .accessibilityAddTraits(.isHeader)

                Text(page.message)
                    .font(.system(.title3, design: .serif))
                    .italic()
                    .foregroundStyle(.gray)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    OnboardingView(mode: .face) {}
}
