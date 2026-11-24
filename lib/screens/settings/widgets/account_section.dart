import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../auth/account_screen.dart';

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
              Text(
                auth.user!.email ?? '',
                style: TextStyle(color: tc.textPrimary),
              ),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
