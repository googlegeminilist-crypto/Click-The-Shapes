//
//  Click_The_ShapesApp.swift
//  Click The Shapes
//
//  Created by Thomas Mellor on 30/01/2026.
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        UserDefaults.standard.removeObject(forKey: "lossCountSinceLastAd")
        #if canImport(GoogleMobileAds)
        DispatchQueue.global(qos: .utility).async {
            MobileAds.shared.start { status in
                print("[Ads] MobileAds started. Adapters: \(status.adapterStatusesByClassName.keys.joined(separator: ", "))")
                Task { @MainActor in
                    _ = InterstitialAdManager.shared
                }
            }
        }
        #endif
        return true
    }
}

@main
struct Click_The_ShapesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
