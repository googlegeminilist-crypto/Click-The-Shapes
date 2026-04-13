//
//  RewardedAdManager.swift
//  Click The Shapes
//
//  Shows a Google AdMob rewarded ad; grants the reward via a callback once
//  the user finishes watching. Used by the "Watch Ad to restart with same
//  score" flow on the game-over screen.
//

import Foundation
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class RewardedAdManager: NSObject {
    static let shared = RewardedAdManager()

    #if DEBUG
    // Google test rewarded unit — never serves live ads.
    private let adUnitID = "ca-app-pub-3940256099942544/1712485313"
    #else
    // TODO: replace with your real AdMob rewarded unit ID before release.
    private let adUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
    #endif

    #if canImport(GoogleMobileAds)
    private var rewarded: RewardedAd?
    private var isLoading = false
    #endif

    private var pendingReward: (() -> Void)?
    private var rewardEarned = false

    private override init() {
        super.init()
        loadAd()
    }

    func loadAd() {
        #if canImport(GoogleMobileAds)
        guard !isLoading, rewarded == nil else { return }
        isLoading = true
        let request = Request()
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            Task { @MainActor in
                self.isLoading = false
                if let error = error {
                    print("[Ads] Rewarded failed to load: \(error.localizedDescription)")
                    return
                }
                self.rewarded = ad
                self.rewarded?.fullScreenContentDelegate = self
                print("[Ads] Rewarded loaded and ready.")
            }
        }
        #endif
    }

    var isReady: Bool {
        #if canImport(GoogleMobileAds)
        return rewarded != nil
        #else
        return false
        #endif
    }

    /// Presents the rewarded ad. `onReward` fires only if the user earns the reward.
    func show(onReward: @escaping () -> Void) {
        #if canImport(GoogleMobileAds)
        guard let ad = rewarded, let root = Self.topViewController() else {
            print("[Ads] Rewarded not ready — triggering load.")
            loadAd()
            return
        }
        pendingReward = onReward
        rewardEarned = false
        ad.present(from: root) { [weak self] in
            // User earned reward
            self?.rewardEarned = true
        }
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
extension RewardedAdManager: FullScreenContentDelegate {
    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[Ads] Rewarded failed to present: \(error.localizedDescription)")
        Task { @MainActor in
            self.rewarded = nil
            self.pendingReward = nil
            self.loadAd()
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            let earned = self.rewardEarned
            let cb = self.pendingReward
            self.pendingReward = nil
            self.rewarded = nil
            self.loadAd()
            if earned { cb?() }
        }
    }
}
#endif
