//
//  AppDelegate.swift
//  AR2
//
//  Created by Dimas Dwi Ismaunnizam on 26/03/26.
//

import UIKit
import SwiftUI
import AVFoundation

// MARK: - Sound Manager
class SoundManager {
    static let shared = SoundManager()
    var bgmPlayer: AVAudioPlayer?
    var sfxPlayer: AVAudioPlayer?

    private init() {}

    func playBackgroundMusic(filename: String, type: String = "mp3") {
        if let path = Bundle.main.path(forResource: filename, ofType: type) {
            do {
                bgmPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                bgmPlayer?.numberOfLoops = -1 // Loop indefinitely (-1)
                bgmPlayer?.prepareToPlay()
                bgmPlayer?.play()
            } catch {
                print("Error playing BGM: \(error.localizedDescription)")
            }
        } else {
            print("BGM file '\(filename).\(type)' not found in bundle.")
        }
    }
    
    func playSFX(filename: String, type: String = "mp3") {
        if let path = Bundle.main.path(forResource: filename, ofType: type) {
            do {
                sfxPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                sfxPlayer?.prepareToPlay()
                sfxPlayer?.play()
            } catch {
                print("Error playing SFX: \(error.localizedDescription)")
            }
        } else {
            print("SFX file '\(filename).\(type)' not found in bundle.")
        }
    }
    
    func stopBackgroundMusic() {
        bgmPlayer?.stop()
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Konfigurasi AVAudioSession agar musik tetap berbunyi walaupun iPhone dalam mode silent (Penting untuk AR/Game)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }

        // Mulai mainkan musik dari file "backsound.mp3" saat aplikasi pertama kali terbuka.
        // Catatan: Pastikan Anda menambahkan file "backsound.mp3" ke dalam project Xcode Anda (harus masuk ke Target Membership).
        SoundManager.shared.playBackgroundMusic(filename: "backsound", type: "mp3")

        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()

        // Use a UIHostingController as window root view controller.
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

}

