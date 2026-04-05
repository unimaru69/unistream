import 'package:flutter/material.dart';
import '../../../core/cache_config.dart';
import '../../../core/theme_colors.dart';
import '../../../services/xtream_api.dart';
import '../../../utils/snackbar_helper.dart';
import 'package:unistream/l10n/app_localizations.dart';

class CacheSection extends StatefulWidget {
  const CacheSection({super.key});

  @override
  State<CacheSection> createState() => _CacheSectionState();
}

class _CacheSectionState extends State<CacheSection> {
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: tc.divider),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.cacheSection,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tc.textDisabled,
                  letterSpacing: 1)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.data_usage, size: 20, color: tc.textTertiary),
          const SizedBox(width: 12),
          Expanded(
              child: Text(l10n.cacheEpgEntrees(XtreamApi.epgCacheSize),
                  style: const TextStyle(fontSize: 14))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: tc.surface,
                  title: Text(l10n.confirmerViderCache,
                      style: const TextStyle(fontSize: 16)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.annuler),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.supprimer,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              XtreamApi.clearEpgCache();
              setState(() {});
              if (!mounted) return;
              showAppSnackBar(context, l10n.cacheEpgVide);
            },
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: Text(l10n.viderCacheEpg),
            style: OutlinedButton.styleFrom(
              foregroundColor: tc.textSecondary,
              side: BorderSide(color: tc.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton.icon(
            onPressed: () async {
              await AppCacheManager.instance.emptyCache();
              if (mounted) {
                showAppSnackBar(context, l10n.cacheImagesVide);
              }
            },
            icon: const Icon(Icons.image_not_supported_outlined, size: 18),
            label: Text(l10n.viderCacheImages),
            style: OutlinedButton.styleFrom(
              foregroundColor: tc.textSecondary,
              side: BorderSide(color: tc.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          )),
        ]),
        const SizedBox(height: 8),
        Text(l10n.descriptionCache,
            style: TextStyle(fontSize: 11, color: tc.textDisabled)),
      ],
    );
  }
}
