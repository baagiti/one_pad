import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart'
    show PurchasesErrorCode, PurchasesErrorHelper;

import '../../infrastructure/iap/purchase_service.dart';
import '../../infrastructure/storage/app_database.dart';
import '../theme/app_theme.dart';

/// The real paywall screen (2026-07-27) — what "Go Premium" actually opens
/// now, instead of jumping straight to a confirm dialog. `_subscribe` and
/// `_restore` (2026-08-25) go through the real
/// [PurchaseService.buyPremium]/[PurchaseService.restorePurchases], backed
/// by RevenueCat — both are wrapped in try/catch because the platform's IAP
/// implementation isn't guaranteed present (e.g. this screen is still
/// reachable on Windows during dev testing), and `_subscribe` treats
/// [PurchasesErrorCode.purchaseCancelledError] as a silent no-op rather than
/// an error worth surfacing.
///
/// The in-app price is shown as a bare `$4` (2026-08-25 decision) rather
/// than the store-formatted `$4.00` — deliberately simplified marketing
/// copy for this screen only. The actual App Store checkout sheet still
/// shows Apple's own formatted price (`$4.00` and each storefront's
/// converted equivalent), which this app has no control over and doesn't
/// need to match.
class PremiumScreen extends StatelessWidget {
  final AppDatabase db;
  final PurchaseService purchases;

  const PremiumScreen({super.key, required this.db, required this.purchases});

  static const _features = [
    (
      Icons.all_inclusive,
      'Every skill, unlocked',
      'All 20 lessons in the curriculum, not just the first three.',
    ),
    (
      Icons.today_outlined,
      'Unlimited daily practice',
      "No 3-lesson daily cap — practice as much as you want, any day.",
    ),
    (
      Icons.speed,
      'Each lesson at its own tempo',
      'Skip the fixed 60 BPM free-tier start — begin at the tempo each '
          'skill was actually designed for.',
    ),
    (
      Icons.mic_none,
      'Record and get scored',
      'Record your playing and see a real timing-accuracy score, not just '
          'a completion count.',
    ),
  ];

  Future<void> _subscribe(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await purchases.isAvailable()) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Can't reach the App Store right now.")),
        );
        return;
      }
      await purchases.buyPremium();
      if (context.mounted) Navigator.of(context).pop();
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't complete the purchase.")),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't complete the purchase.")),
      );
    }
  }

  Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await purchases.isAvailable()) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Can't reach the App Store right now.")),
        );
        return;
      }
      await purchases.restorePurchases();
      messenger.showSnackBar(
        const SnackBar(content: Text('Checked for past purchases.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't restore purchases.")),
      );
    }
  }

  Future<void> _unsubscribe(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Premium (dev)'),
        content: const Text('Turn the local dev Premium flag back off?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Premium'),
          ),
        ],
      ),
    );
    if (confirmed == true) await db.setPremium(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: StreamBuilder<bool>(
        stream: db.watchPremium(),
        builder: (context, snapshot) {
          final premium = snapshot.data ?? false;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Icon(
                premium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                size: 56,
                color: AppColors.secondary,
              ),
              const SizedBox(height: 12),
              Text(
                premium ? "You're Premium" : 'Practice without limits',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                premium
                    ? 'Every skill, unlimited sessions, full-tempo lessons, '
                        'and recording are all unlocked.'
                    : 'Unlock the full curriculum and record your playing.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              for (final (icon, title, subtitle) in _features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (!premium) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Column(
                    children: [
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.headlineSmall,
                          children: const [
                            TextSpan(text: '\$4'),
                            TextSpan(
                              text: ' / month',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Shown in USD — the App Store displays your own '
                        "currency's equivalent price at checkout.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => _subscribe(context),
                  child: const Text('Subscribe'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _restore(context),
                  child: const Text('Restore Purchases'),
                ),
              ] else
                OutlinedButton(
                  onPressed: () => _unsubscribe(context),
                  child: const Text('Cancel Premium'),
                ),
            ],
          );
        },
      ),
    );
  }
}
