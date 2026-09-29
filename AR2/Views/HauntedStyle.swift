//
//  HauntedStyle.swift
//  AR2
//

import SwiftUI

/// Tombol utama bergaya seram (gradasi merah-hitam, huruf serif).
struct HauntedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .serif, weight: .bold))
            .tracking(3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .frame(maxWidth: 500)
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.6, green: 0, blue: 0), .black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.red, lineWidth: 2))
            .shadow(color: .red.opacity(0.8), radius: 20, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Tombol bulat kecil untuk ikon (info, ubah wujud, foto, pengaturan).
struct HauntedCircleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title2, design: .serif, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 55, height: 55)
            .background(
                Circle().fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(red: 0.5, green: 0, blue: 0), .black]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(Circle().stroke(.red, lineWidth: 2))
            .shadow(color: .red.opacity(0.8), radius: 15, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Kartu gelap berbingkai merah untuk teks di atas kamera.
struct HauntedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: 500, alignment: .leading)
            .background(.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.red, lineWidth: 2))
            .shadow(color: .red, radius: 20)
    }
}
