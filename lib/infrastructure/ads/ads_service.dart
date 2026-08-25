import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Free-tier ad monetization (design doc, 2026-07-30): banners on Home,
/// Today's Session and Results, a post-session interstitial, and a rewarded
/// ad that grants one bonus daily session slot ([freeBonusSlotCap] in
/// access_policy.dart). Premium users never see any of this — every call
/// site gates on `!premium` before touching [AdsService].
///
/// Ad unit IDs below are real production IDs from the "Stick Trainer" app
/// on the studio's AdMob account (podegitim@gmail.com), created 2026-08-25 —
/// see [PurchaseService] for the equivalent RevenueCat/App Store Connect
/// setup for the Premium subscription.
///
/// `google_mobile_ads` only ships Android/iOS platform implementations —
/// same shape of risk as `purchases_flutter` (design doc §12, item 15);
/// verified 2026-07-30 that adding it doesn't break `flutter run -d
/// windows`. [supported] gates every real call so nothing here is ever
/// invoked on an unsupported platform.
class AdsService {
  static const bannerAdUnitId = 'ca-app-pub-7842996095218621/7035016862';
  static const interstitialAdUnitId =
      'ca-app-pub-7842996095218621/5598696598';
  static const rewardedAdUnitId = 'ca-app-pub-7842996095218621/5248176952';

  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  Future<void> init() async {
    if (!supported) return;
    // Request App Tracking Transparency before initializing the ad SDK
    // (Google's recommended order) — iOS-only concept, a no-op on Android.
    // Declining just means non-personalized, lower-eCPM ads, not no ads.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }
    await MobileAds.instance.initialize();
    preloadInterstitial();
    preloadRewarded();
  }

  void preloadInterstitial() {
    if (!supported) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// No-op if nothing is loaded yet (e.g. shown right after app start) —
  /// callers fire this and move on, an ad is a bonus, never a blocker.
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
    );
    await ad.show();
    await completer.future;
  }

  void preloadRewarded() {
    if (!supported) return;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  bool get rewardedReady => _rewarded != null;

  /// Resolves once the ad is dismissed, with whether the reward was
  /// actually earned (user watched through, not just opened-and-closed).
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;
    var earned = false;
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (ad, reward) => earned = true);
    return completer.future;
  }
}
