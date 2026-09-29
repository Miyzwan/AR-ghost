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
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                    .shadow(color: .red, radius: 20)
                    .accessibilityHidden(true)

                Text("The ghost needs your camera")
                    .font(.system(.title, design: .serif, weight: .black))
                    .foregroundStyle(.white)

                Text("AR Ghost uses the camera to show ghosts around you and to detect your hand gestures. Camera images are processed on your device and never leave it.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.gray)

                Text("Allow camera access in Settings to summon the ghost.")
                    .font(.system(.body, design: .serif, weight: .semibold))
                    .foregroundStyle(.white)

                Button("OPEN SETTINGS") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                    dismiss()
                }
                .buttonStyle(HauntedButtonStyle())
                .padding(.top, 8)

                Button("Not Now") {
                    dismiss()
                }
                .font(.system(.body, design: .serif))
                .foregroundStyle(.gray)
            }
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    CameraPermissionView()
}
