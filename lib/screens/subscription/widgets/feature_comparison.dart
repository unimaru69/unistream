import 'package:flutter/material.dart';
import '../../../core/colors.dart';
import '../../../l10n/app_localizations.dart';

/// Compares Basic vs Premium features in a two-column table.
class FeatureComparison extends StatelessWidget {
  const FeatureComparison({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final basicFeatures = [
      l10n.fonctionnaliteLiveVodSeries,
      l10n.fonctionnaliteEpg,
      l10n.fonctionnaliteRecherche,
      l10n.fonctionnaliteFavoris,
      l10n.fonctionnaliteThemes,
    ];

    final premiumFeatures = [
      l10n.fonctionnaliteCatchup,
      l10n.fonctionnaliteMiniPlayer,
      l10n.fonctionnaliteCollections,
      l10n.fonctionnaliteMultiProfils,
      l10n.fonctionnaliteParental,
      l10n.fonctionnaliteSousTitresAvances,
      l10n.fonctionnaliteCloudSync,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic features — included in both
        ...basicFeatures.map((f) => _FeatureRow(
              label: f,
              basicIncluded: true,
              premiumIncluded: true,
              isDark: isDark,
            )),
        const SizedBox(height: 8),
        Divider(color: isDark ? Colors.white12 : AppColors.lightDivider),
        const SizedBox(height: 8),
        // Premium-only features
        ...premiumFeatures.map((f) => _FeatureRow(
              label: f,
              basicIncluded: false,
              premiumIncluded: true,
              isDark: isDark,
            )),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final bool basicIncluded;
  final bool premiumIncluded;
  final bool isDark;

  const _FeatureRow({
    required this.label,
    required this.basicIncluded,
    required this.premiumIncluded,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: Icon(
                basicIncluded ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: basicIncluded
                    ? AppColors.accentGreen
                    : (isDark ? Colors.white24 : AppColors.lightTextDisabled),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: Icon(
                premiumIncluded ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: premiumIncluded
                    ? AppColors.accentGreen
                    : (isDark ? Colors.white24 : AppColors.lightTextDisabled),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
