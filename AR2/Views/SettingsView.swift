//
//  SettingsView.swift
//  AR2
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.musicEnabled) private var musicEnabled = true
    @AppStorage(AppSettings.soundEffectsEnabled) private var soundEffectsEnabled = true
    @AppStorage(AppSettings.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppSettings.hasSeenOnboarding) private var hasSeenOnboarding = false
    #if DEBUG
    @AppStorage(ARMode.forceWorldModeKey) private var forceWorldMode = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("Sound & Haptics") {
                    Toggle("Music", isOn: $musicEnabled)
                    Toggle("Sound Effects", isOn: $soundEffectsEnabled)
                    Toggle("Vibration", isOn: $hapticsEnabled)
                }

                Section {
                    Button("Show Tutorial") {
                        // ContentView menampilkan tutorial begitu flag ini kembali false
                        hasSeenOnboarding = false
                        dismiss()
                    }
                    NavigationLink("Privacy") {
                        PrivacyView()
                    }
                    NavigationLink("Credits") {
                        CreditsView()
                    }
                } footer: {
                    Text(verbatim: "AR Ghost \(Bundle.main.appVersion)")
                }

                #if DEBUG
                Section("Debug") {
                    // Menguji mode kamera belakang di perangkat yang punya Face ID
                    Toggle("Force world mode", isOn: $forceWorldMode)
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(.red)
        .onChange(of: musicEnabled) {
            SoundManager.shared.updateMusicPlayback()
        }
    }
}

private struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("AR Ghost does not collect, store, or share any personal data.")
                    .font(.headline)
                Text("The camera is used only while the ghost is on screen, to show it in augmented reality and to detect your face and hand gestures. All camera images are processed on your device in real time and are never saved or sent anywhere.")
                Text("Photos you take are kept only in memory until you share or save them yourself.")
                Text("The app has no accounts, no analytics, no ads, and no tracking.")
            }
            .padding()
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Privacy")
    }
}

private struct CreditsView: View {
    var body: some View {
        List {
            Section("3D Models") {
                ForEach(GhostCatalog.all) { ghost in
                    Link(destination: ghost.credit.url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: "“\(ghost.credit.title)”")
                                .foregroundStyle(.primary)
                            Text("by \(ghost.credit.author), licensed under \(ghost.credit.license)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Credits")
    }
}

extension Bundle {
    /// Contoh: "1.0 (3)"
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
