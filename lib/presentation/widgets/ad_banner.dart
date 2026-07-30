import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../infrastructure/ads/ads_service.dart';

/// Free-tier banner ad. Callers gate on `!premium` before including this in
/// the tree — it never checks premium itself. Renders nothing on
/// unsupported platforms (Windows dev) or before the ad has loaded, so it's
/// always safe to drop into a layout unconditionally otherwise.
class AdBanner extends StatefulWidget {
  final AdsService ads;

  const AdBanner({super.key, required this.ads});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    if (AdsService.supported) _load();
  }

  void _load() {
    final banner = BannerAd(
      adUnitId: widget.ads.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _banner = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (banner == null) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
  }
}
