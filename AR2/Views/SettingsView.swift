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
                    Toggle(isOn: $musicEnabled) {
                        SettingsLabel("Music", symbol: "music.note", color: Spooky.crimson)
                    }
                    Toggle(isOn: $soundEffectsEnabled) {
                        SettingsLabel("Sound Effects", symbol: "speaker.wave.2.fill", color: Spooky.pumpkin)
                    }
                    Toggle(isOn: $hapticsEnabled) {
                        SettingsLabel("Vibration", symbol: "iphone.radiowaves.left.and.right", color: Spooky.blood)
                    }
                }
                .listRowBackground(Spooky.mist.opacity(0.07))

                Section {
                    Button {
                        // ContentView menampilkan tutorial begitu flag ini kembali false
                        hasSeenOnboarding = false
                        dismiss()
                    } label: {
                        SettingsLabel("Show Tutorial", symbol: "sparkles", color: Spooky.blood)
                    }
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        SettingsLabel("Privacy", symbol: "hand.raised.fill", color: Spooky.crimson)
                    }
                    NavigationLink {
                        CreditsView()
                    } label: {
                        SettingsLabel("Credits", symbol: "heart.fill", color: Spooky.pumpkin)
                    }
                } footer: {
                    Text(verbatim: "👻 AR Ghost \(Bundle.main.appVersion)")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }
                .listRowBackground(Spooky.mist.opacity(0.07))

                #if DEBUG
                Section("Debug") {
                    // Menguji mode kamera belakang di perangkat yang punya Face ID
                    Toggle("Force world mode", isOn: $forceWorldMode)
                }
                .listRowBackground(Spooky.mist.opacity(0.07))
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(SpookyBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fontDesign(.rounded)
        .tint(Spooky.pumpkin)
        .onChange(of: musicEnabled) {
            SoundManager.shared.updateMusicPlayback()
        }
    }
}

/// Ikon berwarna dalam kotak bulat, seperti di app Pengaturan iOS.
private struct SettingsLabel: View {
    let title: LocalizedStringKey
    let symbol: String
    let color: Color

    init(_ title: LocalizedStringKey, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(Spooky.mist)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: .rect(cornerRadius: 8))
        }
    }
}

private struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlowOrb(symbol: "lock.shield.fill", size: 96)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                Text("AR Ghost does not collect, store, or share any personal data.")
                    .font(.spooky(.title3, weight: .bold))
                    .foregroundStyle(Spooky.mist)
                Group {
                    Text("The camera is used only while the ghost is on screen, to show it in augmented reality and to detect your face and hand gestures. All camera images are processed on your device in real time and are never saved or sent anywhere.")
                    Text("Photos you take are kept only in memory until you share or save them yourself.")
                    Text("The app has no accounts, no analytics, no ads, and no tracking.")
                }
                .font(.spooky(.body, weight: .regular))
                .foregroundStyle(Spooky.mistDim)
            }
            .padding(24)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(SpookyBackground())
        .navigationTitle("Privacy")
    }
}

private struct CreditsView: View {
    var body: some View {
        List {
            Section("3D Models") {
                ForEach(GhostCatalog.all) { ghost in
                    Link(destination: ghost.credit.url) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: "“\(ghost.credit.title)”")
                                    .font(.spooky(.body, weight: .semibold))
                                    .foregroundStyle(Spooky.mist)
                                Text("by \(ghost.credit.author), licensed under \(ghost.credit.license)")
                                    .font(.footnote)
                                    .foregroundStyle(Spooky.mistDim)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(Spooky.mistDim)
                        }
                    }
                }
            }
            .listRowBackground(Spooky.mist.opacity(0.07))

            // Efek suara cerita (AR2/Sounds)
            Section("Sound Effects") {
                Link(destination: URL(string: "https://kenney.nl/assets/category:Audio")!) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: "“Interface Sounds, Digital Audio, Impact Sounds, Music Jingles, RPG Audio”")
                                .font(.spooky(.body, weight: .semibold))
                                .foregroundStyle(Spooky.mist)
                            Text("by \("Kenney"), licensed under \("CC0 1.0")")
                                .font(.footnote)
                                .foregroundStyle(Spooky.mistDim)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(Spooky.mistDim)
                    }
                }
            }
            .listRowBackground(Spooky.mist.opacity(0.07))
        }
        .scrollContentBackground(.hidden)
        .background(SpookyBackground())
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
