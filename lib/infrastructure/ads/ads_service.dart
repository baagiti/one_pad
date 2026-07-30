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
/// Ad unit IDs below are Google's published *test* IDs (safe to ship in
/// debug/TestFlight builds, always fill, never earn real revenue) — swap
/// for real IDs from a real AdMob account before a production release
/// (design doc open topic).
///
/// `google_mobile_ads` only ships Android/iOS platform implementations —
/// same shape of risk as `in_app_purchase` (design doc §12, item 15);
/// verified 2026-07-30 that adding it doesn't break `flutter run -d
/// windows`. [supported] gates every real call so nothing here is ever
/// invoked on an unsupported platform.
class AdsService {
  static const testBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';
  static const testRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  String get bannerAdUnitId => testBannerAdUnitId;

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
      adUnitId: testInterstitialAdUnitId,
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
      adUnitId: testRewardedAdUnitId,
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
