//
//  AR2App.swift
//  AR2
//

import SwiftUI

@main
struct AR2App: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppSettings.registerDefaults()
        // Musik latar mulai saat aplikasi pertama kali terbuka
        SoundManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            SoundManager.shared.handleScenePhase(phase)
        }
    }
}
