//
//  PhotoPreviewView.swift
//  AR2
//

import SwiftUI
import UIKit

struct CapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Menggabungkan snapshot AR dengan kabut tepi dan watermark "AR GHOST".
enum PhotoComposer {
    static func compose(_ snapshot: UIImage, accent: SpookyAccent) -> UIImage {
        let size = snapshot.size
        let bounds = CGRect(origin: .zero, size: size)

        // Kabut yang sama dengan di layar (versi diam)
        let overlayRenderer = ImageRenderer(
            content: SpookyVignetteView(accent: accent).frame(width: size.width, height: size.height)
        )
        overlayRenderer.scale = snapshot.scale
        let overlay = overlayRenderer.uiImage

        let format = UIGraphicsImageRendererFormat()
        format.scale = snapshot.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            snapshot.draw(in: bounds)
            overlay?.draw(in: bounds)

            let fontSize = max(size.width * 0.055, 18)
            let baseFont = UIFont.systemFont(ofSize: fontSize, weight: .black)
            let font = baseFont.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: fontSize) } ?? baseFont
            let shadow = NSShadow()
            shadow.shadowColor = UIColor(accent.color)
            shadow.shadowBlurRadius = fontSize * 0.5
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(Spooky.mist),
                .kern: fontSize * 0.12,
                .shadow: shadow,
            ]
            let watermark = NSAttributedString(string: "👻 AR GHOST", attributes: attributes)
            let textSize = watermark.size()
            let margin = fontSize * 0.8
            watermark.draw(at: CGPoint(x: size.width - textSize.width - margin, y: size.height - textSize.height - margin))
        }
    }
}

struct PhotoPreviewView: View {
    let photo: CapturedPhoto
    @Environment(\.dismiss) private var dismiss
    @Environment(\.spookyAccent) private var accent

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Spooky.mist.opacity(0.25), lineWidth: 1))
                    .shadow(color: accent.color.opacity(0.35), radius: 28)
                    .frame(maxHeight: .infinity)
                    .accessibilityLabel(Text("Your ghost photo"))

                ShareLink(
                    item: Image(uiImage: photo.image),
                    preview: SharePreview(Text(verbatim: "AR Ghost"), image: Image(uiImage: photo.image))
                ) {
                    Label("SHARE", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SpookyButtonStyle())
            }
            .padding(24)
            .background(SpookyBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .fontDesign(.rounded)
        .tint(Spooky.mist)
    }
}
