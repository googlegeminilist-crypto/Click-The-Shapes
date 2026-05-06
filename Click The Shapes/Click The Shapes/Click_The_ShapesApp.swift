//
//  Click_The_ShapesApp.swift
//  Click The Shapes
//
//  Created by Thomas Mellor on 30/01/2026.
//

import SwiftUI
import Combine
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

#if canImport(FirebaseAppCheck)
/// Use Apple's App Attest to prove to Firebase that requests really come
/// from the genuine, signed Click The Shapes app on a real iPhone.
/// Anything else (scripts, simulators in production, modified binaries)
/// can't produce a valid attestation token, so server-side App Check
/// enforcement will reject their requests.
final class CTSAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }
}
#endif

final class LaunchGate: ObservableObject {
    @Published var adsReady = false
    @Published var firstFrameReady = false
    @Published var introReady = false
    var ready: Bool { adsReady && firstFrameReady && introReady }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static let launchGate = LaunchGate()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // App Check provider MUST be set BEFORE FirebaseApp.configure() so
        // every Firebase service (Firestore especially) is wrapped from the
        // first request.
        #if canImport(FirebaseAppCheck)
        AppCheck.setAppCheckProviderFactory(CTSAppCheckProviderFactory())
        #endif
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        UserDefaults.standard.removeObject(forKey: "lossCountSinceLastAd")

        // Consent (UMP) must run before MobileAds.start. Also required before ATT.
        requestConsentThenStartAds()

        // Don't make the splash wait on ads — let the SDK warm up in the
        // background while the player sees the intro. The ad managers will
        // present a brief spinner if a player taps Watch Ad before load
        // completes. This drops typical splash time from ~5–8s to <500ms.
        AppDelegate.launchGate.adsReady = true
        AppDelegate.launchGate.introReady = true

        // Hard safety: ensure the splash never sticks for more than 2s
        // even if firstFrameReady somehow doesn't fire.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            AppDelegate.launchGate.firstFrameReady = true
        }
        return true
    }

    private func requestConsentThenStartAds() {
        #if canImport(UserMessagingPlatform)
        let params = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] _ in
            DispatchQueue.main.async {
                ConsentForm.loadAndPresentIfRequired(from: nil) { _ in
                    self?.afterConsentResolved()
                }
            }
        }
        #else
        afterConsentResolved()
        #endif
    }

    private func afterConsentResolved() {
        // ATT must come AFTER UMP resolves (Google's guidance).
        requestTrackingAuthorization { [weak self] in
            self?.startAdsSDK()
        }
    }

    private func requestTrackingAuthorization(completion: @escaping () -> Void) {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14.5, *) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async { completion() }
            }
        } else {
            completion()
        }
        #else
        completion()
        #endif
    }

    private func startAdsSDK() {
        #if canImport(GoogleMobileAds)
        // Tighten ad-content settings BEFORE starting the SDK so the very
        // first ad request honours them. Aim is to block "scareware"-style
        // ads ("your phone is hacked!", fake virus warnings, etc.).
        let cfg = MobileAds.shared.requestConfiguration
        // General audience rating — strictest. Filters out PG/T/MA creatives.
        cfg.maxAdContentRating = .general
        // Treat the user as an unknown-age EU user — extra protections.
        cfg.tagForUnderAgeOfConsent = false
        cfg.tagForChildDirectedTreatment = false

        DispatchQueue.global(qos: .utility).async {
            MobileAds.shared.start { _ in
                Task { @MainActor in
                    _ = InterstitialAdManager.shared
                    _ = RewardedAdManager.shared
                    AppDelegate.launchGate.adsReady = true
                }
            }
        }
        #else
        AppDelegate.launchGate.adsReady = true
        #endif
    }
}

struct SnakeLoadingView: View {
    @State private var t: CGFloat = 0
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    // Returns a point on the rounded-rect perimeter of size (w, h) with inset `pad`,
    // where `u` is in [0, 1) measuring fraction around the loop.
    private func perimeterPoint(u: CGFloat, w: CGFloat, h: CGFloat, pad: CGFloat) -> CGPoint {
        let x0 = pad, y0 = pad
        let x1 = w - pad, y1 = h - pad
        let W = x1 - x0, H = y1 - y0
        let perim = 2 * (W + H)
        let d = (u.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * perim
        if d < W { return CGPoint(x: x0 + d, y: y0) }
        if d < W + H { return CGPoint(x: x1, y: y0 + (d - W)) }
        if d < 2 * W + H { return CGPoint(x: x1 - (d - W - H), y: y1) }
        return CGPoint(x: x0, y: y1 - (d - 2 * W - H))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.02, green: 0.02, blue: 0.08).ignoresSafeArea()

                Canvas { ctx, sz in
                    let segments = 18
                    let pad: CGFloat = 30
                    let perim = 2 * ((sz.width - 2 * pad) + (sz.height - 2 * pad))
                    let spacing: CGFloat = max(7, min(11, perim / CGFloat(segments * 4)))

                    for i in 0..<segments {
                        // Head at u, each segment slightly behind along perimeter
                        let u = t - CGFloat(i) * (spacing / perim)
                        let p = perimeterPoint(u: u, w: sz.width, h: sz.height, pad: pad)
                        let isHead = i == 0
                        let radius: CGFloat = isHead ? 8 : max(2.5, 7 - CGFloat(i) * 0.25)
                        let hue = Double((CGFloat(i) * 0.025 + t * 0.6).truncatingRemainder(dividingBy: 1))
                        let color = Color(hue: hue, saturation: 0.9, brightness: 1.0)
                        ctx.fill(
                            Circle().path(in: CGRect(x: p.x - radius * 1.8, y: p.y - radius * 1.8, width: radius * 3.6, height: radius * 3.6)),
                            with: .color(color.opacity(0.18))
                        )
                        ctx.fill(
                            Circle().path(in: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
                            with: .color(color)
                        )
                        if isHead {
                            ctx.fill(Circle().path(in: CGRect(x: p.x - 2.5, y: p.y - 3, width: 2, height: 2)), with: .color(.white))
                            ctx.fill(Circle().path(in: CGRect(x: p.x + 0.5, y: p.y - 3, width: 2, height: 2)), with: .color(.white))
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .drawingGroup()

                VStack(spacing: 14) {
                    Text("CLICK THE SHAPES")
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .cyan.opacity(0.8), radius: 6)
                    Text("LOADING…")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
        }
        .onReceive(timer) { _ in
            t += 0.009
            if t > 100 { t -= 100 }
        }
    }
}

struct RootView: View {
    @ObservedObject var gate = AppDelegate.launchGate
    var body: some View {
        ZStack {
            // ContentView is always present so its heavy SwiftUI tree
            // (GameViewModel, shape array, animated canvases) warms up
            // while the splash is showing — that means zero stutter on
            // the first scroll/tap once the splash dismisses.
            //
            // It's hidden behind a fully-opaque splash via `.opacity(0)`,
            // and has hit-testing disabled, so the player can never see
            // or interact with it during launch.
            ContentView()
                .opacity(gate.ready ? 1 : 0)
                .allowsHitTesting(gate.ready)
                .onAppear {
                    DispatchQueue.main.async {
                        AppDelegate.launchGate.firstFrameReady = true
                    }
                }

            // Splash sits on top of the (invisible) ContentView. No
            // cross-fade — when gate.ready flips, both the opacity flip
            // on ContentView and the splash removal happen on the same
            // frame, so there's no moment where the game peeks through.
            if !gate.ready {
                SnakeLoadingView()
            }
        }
    }
}

@main
struct Click_The_ShapesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
