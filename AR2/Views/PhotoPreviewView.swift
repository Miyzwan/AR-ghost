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

/// Menggabungkan snapshot AR dengan efek darah dan watermark "AR GHOST".
enum PhotoComposer {
    static func compose(_ snapshot: UIImage) -> UIImage {
        let size = snapshot.size
        let bounds = CGRect(origin: .zero, size: size)

        // Efek darah yang sama dengan di layar (versi diam)
        let overlayRenderer = ImageRenderer(content: BloodOverlayView().frame(width: size.width, height: size.height))
        overlayRenderer.scale = snapshot.scale
        let overlay = overlayRenderer.uiImage

        let format = UIGraphicsImageRendererFormat()
        format.scale = snapshot.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            snapshot.draw(in: bounds)
            overlay?.draw(in: bounds)

            let fontSize = max(size.width * 0.06, 18)
            let baseFont = UIFont.systemFont(ofSize: fontSize, weight: .black)
            let font = baseFont.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: fontSize) } ?? baseFont
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.red
            shadow.shadowBlurRadius = fontSize * 0.4
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .kern: fontSize * 0.15,
                .shadow: shadow,
            ]
            let watermark = NSAttributedString(string: "AR GHOST", attributes: attributes)
            let textSize = watermark.size()
            let margin = fontSize * 0.8
            watermark.draw(at: CGPoint(x: size.width - textSize.width - margin, y: size.height - textSize.height - margin))
        }
    }
}

struct PhotoPreviewView: View {
    let photo: CapturedPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.red, lineWidth: 2))
                    .shadow(color: .red.opacity(0.6), radius: 20)
                    .frame(maxHeight: .infinity)
                    .accessibilityLabel(Text("Your ghost photo"))

                ShareLink(
                    item: Image(uiImage: photo.image),
                    preview: SharePreview(Text(verbatim: "AR Ghost"), image: Image(uiImage: photo.image))
                ) {
                    Label("SHARE", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(HauntedButtonStyle())
            }
            .padding(24)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(.red)
    }
}
