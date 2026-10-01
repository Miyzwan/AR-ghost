//
//  CameraPermissionView.swift
//  AR2
//

import AVFoundation
import SwiftUI

enum CameraPermission {
    /// Meminta izin kamera jika belum pernah ditanya. `true` jika kamera boleh dipakai.
    static func request() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            true
        case .notDetermined:
            await AVCaptureDevice.requestAccess(for: .video)
        default:
            false
        }
    }
}

/// Ditampilkan jika izin kamera ditolak, dengan jalan pintas ke Pengaturan.
struct CameraPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                GlowOrb(symbol: "camera.fill", size: 120)
                    .padding(.top, 16)

                Text("The ghost needs your camera")
                    .font(.spooky(.title, weight: .black))
                    .foregroundStyle(Spooky.mist)

                Text("AR Ghost uses the camera to show ghosts around you and to detect your hand gestures. Camera images are processed on your device and never leave it.")
                    .font(.spooky(.body, weight: .regular))
                    .foregroundStyle(Spooky.mistDim)

                Text("Allow camera access in Settings to summon the ghost.")
                    .font(.spooky(.body, weight: .semibold))
                    .foregroundStyle(Spooky.mist)

                Button("OPEN SETTINGS") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                    dismiss()
                }
                .buttonStyle(SpookyButtonStyle())
                .padding(.top, 8)

                Button("Not Now") {
                    dismiss()
                }
                .buttonStyle(SpookyTextButtonStyle())
            }
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(SpookyBackground())
        .fontDesign(.rounded)
    }
}

#Preview {
    CameraPermissionView()
}
