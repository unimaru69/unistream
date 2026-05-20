import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserIdentity;
import '../../core/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
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

          // Cross-device sign-in methods + email-linking action
          _CrossDeviceCard(),
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

/// Cross-device sync card.
///
/// Displays the user's currently-linked sign-in methods (Apple, magic-link
/// email, …) and offers a "change cross-device email" action that wraps
/// Supabase's `updateUser(email: …)`. The action exists primarily to
/// rescue users who signed up via Apple Sign-In with "Hide my email" —
/// those users have an Apple Private Relay address as their primary
/// email, which can't receive magic-link OTPs on the desktop builds.
/// Updating to a real address while keeping the Apple identity makes
/// cross-device sign-in work without manually merging accounts.
class _CrossDeviceCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CrossDeviceCard> createState() => _CrossDeviceCardState();
}

class _CrossDeviceCardState extends ConsumerState<_CrossDeviceCard> {
  bool _editing = false;
  bool _confirmationSent = false;
  String? _pendingEmail;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final identities = AuthService.instance.currentIdentities;
    final isPrivateRelay =
        auth.user?.email?.endsWith('@privaterelay.appleid.com') ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices, size: 20,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(l10n.crossDeviceTitre,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            // Explainer — calibrated to the most common foot-gun (Apple
            // Private Relay) but worded so it stays relevant for the
            // magic-link-first user too.
            Text(
              isPrivateRelay
                  ? l10n.crossDeviceExplainerPrivateRelay
                  : l10n.crossDeviceExplainerGeneric,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 16),
            // Linked identities
            ...identities.map(_buildIdentityRow),
            const SizedBox(height: 12),
            // Action: change primary email
            if (_confirmationSent) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.accentGreen.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.mark_email_read,
                          color: AppColors.accentGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.crossDeviceConfirmationEnvoyee(
                              _pendingEmail ?? ''),
                          style: const TextStyle(
                              color: AppColors.accentGreen, fontSize: 13),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      l10n.crossDeviceConfirmationDetail,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ] else if (_editing) ...[
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.crossDeviceNouvelEmail,
                    hintText: l10n.crossDeviceNouvelEmailHint,
                    prefixIcon: const Icon(Icons.alternate_email),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.champObligatoire;
                    if (!v.contains('@') || !v.contains('.')) return l10n.authEmailInvalide;
                    if (v.trim() == auth.user?.email) return l10n.crossDeviceEmailIdentique;
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (auth.error != null) ...[
                Text(auth.error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                const SizedBox(height: 8),
              ],
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: auth.isLoading
                        ? null
                        : () => setState(() => _editing = false),
                    child: Text(l10n.annuler),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(l10n.crossDeviceEnvoyerLien),
                  ),
                ),
              ]),
            ] else
              OutlinedButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.crossDeviceModifierEmail),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityRow(UserIdentity id) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final (icon, label) = switch (id.provider) {
      'apple'  => (Icons.apple,         l10n.crossDeviceIdApple),
      'google' => (Icons.g_mobiledata,  l10n.crossDeviceIdGoogle),
      'email'  => (Icons.mail_outline,  l10n.crossDeviceIdEmail),
      _        => (Icons.login,         id.provider),
    };
    // Display value: Apple identities expose the email through
    // identityData['email']; magic-link identities use the same field.
    final value = (id.identityData?['email'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500)),
                if (value.isNotEmpty)
                  Text(value,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).clearError();
    final email = _emailCtrl.text.trim();
    final ok = await ref.read(authProvider.notifier).updateEmail(email);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _editing = false;
        _confirmationSent = true;
        _pendingEmail = email;
      });
    }
    // Error path: the auth provider already populated `auth.error`
    // which the form surfaces above the Cancel/Send buttons.
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
