//
//  HomeView.swift
//  AR2
//

import SwiftUI

struct HomeView: View {
    @Binding var isARActive: Bool
    /// `Ghost.id` yang akan dipanggil ke AR.
    @Binding var selectedGhostID: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppSettings.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppSettings.completedStories) private var completedStories = ""
    @State private var showSettings = false
    @State private var isGlowing = false

    private let mode = ARMode.preferred

    private var selectedIndex: Int { GhostCatalog.index(ofID: selectedGhostID) }
    private var selectedGhost: Ghost { GhostCatalog.all[selectedIndex] }
    private var completedIDs: Set<String> { StoryCompletion.ids(in: completedStories) }
    private var isSelectedComplete: Bool { completedIDs.contains(selectedGhost.id) }
    private var completedCount: Int { GhostCatalog.all.filter { completedIDs.contains($0.id) }.count }

    var body: some View {
        ZStack {
            SpookyBackground()

            VStack(spacing: 0) {
                // Bintang utama: hantu pilihan dalam 3D, geser untuk ganti
                GhostHeroView(ghost: selectedGhost)
                    .id(selectedGhost.id)
                    // Hantu lama memudar mengecil, hantu baru muncul membesar
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity))
                    .frame(minHeight: 150, maxHeight: 320)
                    .padding(.top, 40)
                    .contentShape(.rect)
                    .gesture(swipeGesture)

                ghostPicker

                VStack(spacing: 14) {
                    Text(verbatim: "AR GHOST")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .tracking(6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(
                            LinearGradient(colors: [.white, Spooky.mist, Spooky.pumpkin], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: Spooky.pumpkin.opacity(isGlowing ? 0.7 : 0.3), radius: 18)
                        .accessibilityAddTraits(.isHeader)

                    Text("Pick your ghost. Cute… until it isn't.")
                        .font(.spooky(.title3, weight: .medium))
                        .foregroundStyle(Spooky.mistDim)
                        .multilineTextAlignment(.center)

                    modeChip
                        .padding(.top, 4)
                }
                .padding(.top, 20)

                Spacer(minLength: 24)

                Button("SUMMON THE GHOST") {
                    isARActive = true
                }
                .buttonStyle(SpookyButtonStyle())
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: 600)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(SpookyIconButtonStyle())
            .accessibilityLabel(Text("Settings"))
            .padding(20)
        }
        .environment(\.spookyAccent, .for(selectedGhost))
        .animation(.easeInOut(duration: 0.4), value: selectedGhost.mood)
        .sensoryFeedback(trigger: selectedGhostID) { _, _ in
            hapticsEnabled ? .selection : nil
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }

    // --- Pemilih hantu: panah kiri/kanan, nama, dan titik halaman ---
    private var ghostPicker: some View {
        HStack(spacing: 12) {
            Button {
                select(offset: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(SpookyIconButtonStyle(size: 44))
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text(selectedGhost.name)
                        .font(.spooky(.headline, weight: .heavy))
                        .foregroundStyle(Spooky.mist)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.opacity)

                    // Lencana: cerita hantu ini sudah selesai
                    if isSelectedComplete {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Spooky.pumpkin)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)

                PageDots(count: GhostCatalog.all.count, current: selectedIndex, completed: GhostCatalog.all.map { completedIDs.contains($0.id) })

                Text("\(completedCount) of \(GhostCatalog.all.count) stories complete")
                    .font(.spooky(.caption, weight: .semibold))
                    .foregroundStyle(Spooky.mistDim)
            }

            Button {
                select(offset: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(SpookyIconButtonStyle(size: 44))
            .accessibilityHidden(true)
        }
        // VoiceOver: satu elemen yang bisa digeser naik/turun
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Ghost"))
        .accessibilityValue(
            isSelectedComplete
                ? Text("\(String(localized: selectedGhost.name)), \(selectedIndex + 1) of \(GhostCatalog.all.count), story complete")
                : Text("\(String(localized: selectedGhost.name)), \(selectedIndex + 1) of \(GhostCatalog.all.count)")
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(offset: 1)
            case .decrement: select(offset: -1)
            @unknown default: break
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                select(offset: value.translation.width < 0 ? 1 : -1)
            }
    }

    /// Pindah ke hantu sebelah (berputar di ujung daftar).
    private func select(offset: Int) {
        let count = GhostCatalog.all.count
        let next = (selectedIndex + offset + count) % count
        withAnimation(.spring(duration: 0.45)) {
            selectedGhostID = GhostCatalog.all[next].id
        }
    }

    // Memberi tahu di mana hantu akan muncul, sesuai kamera perangkat
    private var modeChip: some View {
        Label {
            switch mode {
            case .face: Text("Hides around your head, shoulders, and hands")
            case .world: Text("Appears on a floor or table")
            }
        } icon: {
            Image(systemName: mode == .face ? "face.smiling" : "square.3.layers.3d.down.right")
        }
        .font(.spooky(.subheadline, weight: .semibold))
        .foregroundStyle(Spooky.mist)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Titik-titik kecil penanda hantu ke berapa yang dipilih; hantu yang ceritanya selesai lebih terang.
private struct PageDots: View {
    let count: Int
    let current: Int
    let completed: [Bool]
    @Environment(\.spookyAccent) private var accent

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? accent.color : Spooky.mist.opacity(completed[index] ? 0.8 : 0.3))
                    .frame(width: index == current ? 18 : 6, height: 6)
            }
        }
        .animation(.spring(duration: 0.3), value: current)
    }
}

#Preview {
    ContentView() // Gunakan ContentView untuk preview agar state bisa dikelola dengan baik
}
