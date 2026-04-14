import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/colors.dart';
import '../../../core/theme_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../auth/account_screen.dart';
import '../../subscription/paywall_screen.dart';

class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);
    final tc = AppThemeColors.of(context);

    return Card(
      color: tc.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, size: 20, color: tc.textSecondary),
                const SizedBox(width: 8),
                Text(l10n.compteTitre,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tc.textPrimary)),
              ],
            ),
            const Divider(height: 24),
            if (auth.user != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      auth.user!.email ?? '',
                      style: TextStyle(color: tc.textPrimary),
                    ),
                  ),
                  if (auth.accountInfo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _tierLabel(l10n, auth.accountInfo!.subscriptionTier),
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (auth.accountInfo?.isTrialActive == true) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.compteEssaiJoursRestants(
                      auth.accountInfo!.trialDaysRemaining),
                  style: TextStyle(color: tc.textSecondary, fontSize: 13),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountScreen()),
                    ),
                    child: Text(l10n.compteMonCompte),
                  ),
                ),
                if (auth.accountInfo?.isPremium != true) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PaywallScreen()),
                    ),
                    icon: const Icon(Icons.star, size: 16),
                    label: Text(l10n.abonnementUpgrade),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _tierLabel(AppLocalizations l10n, String tier) {
    switch (tier) {
      case 'basic':
        return 'Basic';
      case 'premium':
        return 'Premium';
      default:
        return l10n.compteEssaiGratuit;
    }
  }
}
