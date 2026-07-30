import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../storage/app_database.dart';

/// Bridges real App Store purchases to the local [PremiumSettings] flag
/// (design doc §12, items 12-13). Restore Purchases is safe to wire up
/// before a real subscription product exists in App Store Connect: it just
/// asks the store for the signed-in Apple ID's purchase history for this
/// bundle ID, and finds nothing until a product is actually created there
/// and someone buys it — see [premiumProductId]'s doc comment.
///
/// `in_app_purchase` only ships Android/iOS platform implementations (no
/// Windows one) — verified 2026-07-30 that this doesn't break `flutter run
/// -d windows`; the Dart-side API is still callable everywhere, it would
/// just throw if actually invoked on an unsupported platform, which this
/// service's callers never do outside the Premium screen.
class PurchaseService {
  /// Placeholder — must exactly match a real auto-renewable subscription
  /// product created in App Store Connect (design doc §12, item 15; not
  /// done yet). Until then, [buyPremium] and [restorePurchases] will find
  /// nothing for this ID, which is expected, not a bug.
  static const premiumProductId = 'com.burakakkaya.onePad.premium_monthly';

  final AppDatabase db;
  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  PurchaseService({required this.db, InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Starts listening for purchase/restore updates — call once at app
  /// startup so a restore triggered from the Premium screen (or a purchase
  /// completing after the app was backgrounded) is picked up.
  void listen() {
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object _) {},
    );
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == premiumProductId) {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await db.setPremium(true);
          case PurchaseStatus.canceled:
          case PurchaseStatus.error:
          case PurchaseStatus.pending:
            break;
        }
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// Asks the store for this Apple ID's past purchases of [premiumProductId]
  /// — [_onPurchaseUpdate] applies any it finds via the same stream a fresh
  /// purchase would use.
  Future<void> restorePurchases() => _iap.restorePurchases();

  /// Throws [StateError] if [premiumProductId] doesn't exist in App Store
  /// Connect yet (design doc §12, item 15) — callers should catch this and
  /// fall back to the dev toggle rather than showing a raw exception.
  Future<void> buyPremium() async {
    final response = await _iap.queryProductDetails({premiumProductId});
    if (response.productDetails.isEmpty) {
      throw StateError(
        'Premium product not set up in App Store Connect yet.',
      );
    }
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
