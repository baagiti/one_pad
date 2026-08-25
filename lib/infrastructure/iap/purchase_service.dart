import 'package:purchases_flutter/purchases_flutter.dart';

import '../storage/app_database.dart';

/// Bridges RevenueCat (design doc §12, items 12-13) to the local
/// [PremiumSettings] flag. RevenueCat wraps StoreKit directly — this app
/// doesn't talk to `in_app_purchase` at all — and is the source of truth for
/// entitlement state; [db]'s premium flag is just a locally-cached mirror of
/// [entitlementId] so the rest of the app can keep reading a simple
/// `Stream<bool>` via [AppDatabase.watchPremium].
///
/// The RevenueCat project ("Stick Trainer"), its "Stick Trainer Premium"
/// entitlement, and the `com.burakakkaya.onePad.premium_monthly` product
/// (App Store Connect subscription, §14 pricing) were set up 2026-08-25 —
/// see the App Store Connect / RevenueCat dashboards, not this file, for
/// product/pricing changes.
///
/// `purchases_flutter` only ships Android/iOS/macOS/web platform
/// implementations (no Windows one) — callers must guard [configure] the
/// same way [AdsService.init] guards itself, since this screen is still
/// reachable on Windows during dev testing.
class PurchaseService {
  static const _apiKey = 'appl_PjugeasOqgWNUUfnwZuyhiByVAs';

  /// Matches the entitlement identifier created in the RevenueCat dashboard
  /// — grants access when [buyPremium] or [restorePurchases] finds it active.
  static const entitlementId = 'stick_trainer_premium';

  final AppDatabase db;
  CustomerInfoUpdateListener? _listener;

  PurchaseService({required this.db});

  /// Starts the SDK and begins mirroring entitlement state into [db] — call
  /// once at app startup, matching [AdsService.init]'s platform guard.
  Future<void> configure() async {
    await Purchases.configure(PurchasesConfiguration(_apiKey));
    _listener = _syncPremium;
    Purchases.addCustomerInfoUpdateListener(_listener!);
    await _syncPremium(await Purchases.getCustomerInfo());
  }

  Future<void> _syncPremium(CustomerInfo info) =>
      db.setPremium(info.entitlements.active.containsKey(entitlementId));

  Future<bool> isAvailable() => Purchases.canMakePayments();

  /// Throws if no offering/package is configured yet, or a [PlatformException]
  /// (check `PurchasesErrorHelper.getErrorCode` for
  /// [PurchasesErrorCode.purchaseCancelledError]) if the purchase sheet fails
  /// or the user cancels — callers should catch both and show a friendly
  /// message rather than a raw exception.
  Future<void> buyPremium() async {
    final offerings = await Purchases.getOfferings();
    final package = offerings.current?.monthly;
    if (package == null) {
      throw StateError('Premium package not available yet.');
    }
    final result =
        await Purchases.purchase(PurchaseParams.package(package));
    await _syncPremium(result.customerInfo);
  }

  Future<void> restorePurchases() async {
    await _syncPremium(await Purchases.restorePurchases());
  }

  void dispose() {
    final listener = _listener;
    if (listener != null) Purchases.removeCustomerInfoUpdateListener(listener);
  }
}
