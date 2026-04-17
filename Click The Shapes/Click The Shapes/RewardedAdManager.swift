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
    private let adUnitID = "ca-app-pub-3653784707595102/9872748267"
    #endif

    // Max time we'll wait for an ad to load after the user taps the button
    // before falling back to granting the reward. Keeps the UI responsive
    // on slow networks or when AdMob can't fill the request.
    private let loadTimeout: TimeInterval = 4.0

    #if canImport(GoogleMobileAds)
    private var rewarded: RewardedAd?
    private var isLoading = false
    #endif

    private var completion: ((Bool) -> Void)?
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

    /// Presents the rewarded ad. `onComplete(true)` fires if the user earned
    /// the reward OR if the ad couldn't be loaded in time (graceful fallback
    /// so the UI is never stuck). `onComplete(false)` fires if the user
    /// dismissed the ad without earning, or the ad failed to present.
    func show(onComplete: @escaping (_ earned: Bool) -> Void) {
        #if canImport(GoogleMobileAds)
        guard completion == nil else {
            // A previous presentation is still in flight — ignore re-entry.
            return
        }
        guard let root = Self.topViewController() else {
            onComplete(false)
            return
        }
        if let ad = rewarded {
            presentAd(ad, from: root, onComplete: onComplete)
            return
        }
        // Ad not ready — kick off a load and poll briefly before falling back.
        print("[Ads] Rewarded not ready — loading with \(loadTimeout)s timeout.")
        loadAd()
        waitForAd(deadline: Date().addingTimeInterval(loadTimeout),
                  root: root,
                  onComplete: onComplete)
        #else
        onComplete(true)
        #endif
    }

    #if canImport(GoogleMobileAds)
    private func waitForAd(deadline: Date,
                           root: UIViewController,
                           onComplete: @escaping (Bool) -> Void) {
        if let ad = rewarded {
            presentAd(ad, from: root, onComplete: onComplete)
            return
        }
        if Date() >= deadline {
            print("[Ads] Rewarded load timed out — granting reward as fallback.")
            onComplete(true)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.waitForAd(deadline: deadline, root: root, onComplete: onComplete)
        }
    }

    private func presentAd(_ ad: RewardedAd,
                           from root: UIViewController,
                           onComplete: @escaping (Bool) -> Void) {
        completion = onComplete
        rewardEarned = false
        ad.present(from: root) { [weak self] in
            self?.rewardEarned = true
        }
    }

    private func finish(earned: Bool) {
        let cb = completion
        completion = nil
        rewarded = nil
        loadAd()
        cb?(earned)
    }
    #endif

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
            self.finish(earned: false)
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.finish(earned: self.rewardEarned)
        }
    }
}
#endif
