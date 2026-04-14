import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../providers/auth_provider.dart';
import '../utils/feature_access.dart';

/// Wraps a child widget and shows a locked overlay when the user's
/// subscription tier does not include [feature].
///
/// Tapping the locked state navigates to the paywall screen.
class PremiumGate extends ConsumerWidget {
  final Feature feature;
  final Widget child;
  final Widget? lockedChild;

  const PremiumGate({
    super.key,
    required this.feature,
    required this.child,
    this.lockedChild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).accountInfo;
    if (FeatureAccess.canUse(feature, account)) {
      return child;
    }
    return lockedChild ?? _DefaultLockedWidget(feature: feature);
  }
}

/// Checks access and opens the paywall if the feature is locked.
///
/// Use this as an imperative guard before performing an action:
/// ```dart
/// if (!checkPremiumAccess(context, ref, Feature.collections)) return;
/// ```
bool checkPremiumAccess(BuildContext context, WidgetRef ref, Feature feature) {
  final account = ref.read(authProvider).accountInfo;
  if (FeatureAccess.canUse(feature, account)) return true;
  showPremiumRequiredDialog(context);
  return false;
}

/// Shows a dialog informing the user that this feature requires Premium.
void showPremiumRequiredDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Premium'),
      content: const Text(
        'Cette fonctionnalité nécessite un abonnement Premium.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _DefaultLockedWidget extends StatelessWidget {
  final Feature feature;
  const _DefaultLockedWidget({required this.feature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPremiumRequiredDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 16, color: AppColors.primaryBlue.withAlpha(150)),
            const SizedBox(width: 6),
            Text(
              'Premium',
              style: TextStyle(
                color: AppColors.primaryBlue.withAlpha(180),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
