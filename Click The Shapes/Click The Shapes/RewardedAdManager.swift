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
                guard error == nil else { return }
                self.rewarded = ad
                self.rewarded?.fullScreenContentDelegate = self
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
        // If a previous presentation's completion wasn't fired (e.g. SDK
        // swallowed a delegate callback last time), settle it now so the
        // state is clean. We pass `true` so the previous caller isn't
        // penalised either.
        if let stale = completion {
            completion = nil
            stale(true)
        }
        guard let root = Self.topViewController() else {
            // No root VC to present on — user already tapped the button, so
            // honor that intent and grant the reward anyway.
            onComplete(true)
            return
        }
        if let ad = rewarded {
            presentAd(ad, from: root, onComplete: onComplete)
            return
        }
        // Ad not ready — kick off a load and poll briefly before falling back.
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
        ad.present(from: root) { [weak self, weak root] in
            guard let self = self else { return }
            self.rewardEarned = true
            // Grant the reward and resume gameplay immediately — don't wait
            // for the ad to dismiss. Some ads show a post-roll / CTA page
            // that doesn't auto-close; by firing completion now we unstick
            // the game. The adDidDismissFullScreenContent delegate can fire
            // afterwards — finish() guards against double-calling by nil'ing
            // completion after the first invocation.
            self.finish(earned: true)
            // Also try to auto-dismiss the ad view so the user visually
            // returns to the game. If the SDK has already started its own
            // dismissal this is a harmless no-op.
            DispatchQueue.main.async {
                root?.presentedViewController?.dismiss(animated: true)
            }
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
        Task { @MainActor in
            // Grant the reward even if the ad couldn't present — the user
            // already committed to the "Watch Ad to Keep Score" flow. No
            // point punishing them for AdMob being unable to serve an ad.
            self.finish(earned: true)
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            // Grant the reward once the ad dismisses: AdMob's rewarded ads
            // can't be skipped until they complete, so a natural dismissal
            // means the user watched the ad. This also guards against the
            // userDidEarnReward callback not firing in some SDK versions or
            // edge cases — without this, the game would stall on the Game
            // Over overlay after the ad ended.
            self.finish(earned: true)
        }
    }
}
#endif
