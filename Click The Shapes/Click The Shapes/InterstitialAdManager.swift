//
//  InterstitialAdManager.swift
//  Click The Shapes
//
//  Shows a Google AdMob interstitial ad after every 4th loss (any mode).
//  Currently wired to Google's TEST ad unit — swap `adUnitID` before release.
//

import Foundation
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class InterstitialAdManager: NSObject {
    static let shared = InterstitialAdManager()

    #if DEBUG
    // Google-provided test interstitial unit. Safe to click; never serves live ads.
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    // TODO: replace with your real AdMob interstitial unit ID before release.
    private let adUnitID = "ca-app-pub-3653784707595102/8072256270"
    #endif

    #if canImport(GoogleMobileAds)
    private var interstitial: InterstitialAd?
    private var isLoading = false
    #endif

    private override init() {
        super.init()
        loadAd()
    }

    func loadAd() {
        #if canImport(GoogleMobileAds)
        guard !isLoading, interstitial == nil else { return }
        isLoading = true
        let request = Request()
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            Task { @MainActor in
                self.isLoading = false
                if let error = error {
                    print("[Ads] Interstitial failed to load: \(error.localizedDescription)")
                    return
                }
                self.interstitial = ad
                self.interstitial?.fullScreenContentDelegate = self
                print("[Ads] Interstitial loaded and ready.")
            }
        }
        #endif
    }

    func showIfReady() {
        #if canImport(GoogleMobileAds)
        guard let ad = interstitial else {
            print("[Ads] showIfReady: no ad loaded yet — triggering load.")
            loadAd()
            return
        }
        guard let root = Self.topViewController() else {
            print("[Ads] showIfReady: no root VC found.")
            return
        }
        print("[Ads] Presenting interstitial.")
        ad.present(from: root)
        #endif
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
        if let nav = root as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = root as? UITabBarController, let sel = tab.selectedViewController { return topViewController(base: sel) }
        if let presented = root?.presentedViewController { return topViewController(base: presented) }
        return root
    }
}

#if canImport(GoogleMobileAds)
extension InterstitialAdManager: FullScreenContentDelegate {
    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[Ads] Interstitial failed to present: \(error.localizedDescription)")
        Task { @MainActor in
            self.interstitial = nil
            self.loadAd()
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.interstitial = nil
            self.loadAd()
        }
    }
}
#endif
