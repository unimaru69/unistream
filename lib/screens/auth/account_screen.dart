import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../subscription/paywall_screen.dart';
import 'auth_gate.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.compteTitre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryBlue.withAlpha(30),
                        child: const Icon(Icons.person, color: AppColors.primaryBlue, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user?.email ?? '',
                              style: theme.textTheme.titleMedium,
                            ),
                            if (auth.accountInfo?.createdAt != null)
                              Text(
                                l10n.compteCreeLe(_formatDate(auth.accountInfo!.createdAt!)),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.white54 : AppColors.lightTextTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Subscription status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tierLabel(l10n, auth.accountInfo?.subscriptionTier ?? 'trial'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (auth.accountInfo?.isTrial == true) ...[
                    if (auth.accountInfo!.isTrialActive)
                      _StatusRow(
                        icon: Icons.schedule,
                        text: l10n.compteEssaiJoursRestants(auth.accountInfo!.trialDaysRemaining),
                        color: AppColors.primaryBlue,
                      )
                    else
                      _StatusRow(
                        icon: Icons.warning_amber,
                        text: l10n.compteEssaiExpire,
                        color: Colors.orange,
                      ),
                  ],
                  if (auth.accountInfo?.crossPlatformLicense == true)
                    _StatusRow(
                      icon: Icons.devices,
                      text: l10n.compteLicenceCrossplateforme,
                      color: AppColors.accentGreen,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Upgrade / Manage subscription button
          if (auth.accountInfo?.isPremium != true)
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              ),
              icon: const Icon(Icons.star),
              label: Text(
                auth.accountInfo?.isBasicOrAbove == true
                    ? l10n.abonnementUpgrade
                    : l10n.abonnementSAbonner,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

          if (auth.accountInfo?.isPremium == true)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              ),
              icon: const Icon(Icons.settings),
              label: Text(l10n.abonnementGerer),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

          const SizedBox(height: 16),

          // Sign out
          OutlinedButton.icon(
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout),
            label: Text(l10n.compteDeconnexion),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),

          // Delete account
          TextButton.icon(
            onPressed: () => _confirmDelete(context, ref, l10n),
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            label: Text(l10n.compteSupprimerCompte,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  String _tierLabel(AppLocalizations l10n, String tier) {
    switch (tier) {
      case 'basic':
        return l10n.compteAbonnementBasic;
      case 'premium':
        return l10n.compteAbonnementPremium;
      default:
        return l10n.compteEssaiGratuit;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.compteSupprimerCompte),
        content: Text(l10n.compteSupprimerConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.annuler),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.compteSupprimerBouton),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await ref.read(authProvider.notifier).deleteAccount();
      if (!context.mounted) return;
      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      } else {
        final error = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'An error occurred')),
        );
      }
    }
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StatusRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
