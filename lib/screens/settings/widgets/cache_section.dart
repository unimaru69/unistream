import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/cache_config.dart';
import '../../../core/logger.dart';
import '../../../core/theme_colors.dart';
import '../../../models/app_config.dart';
import '../../../utils/snackbar_helper.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/repositories/content_repository.dart';
import 'package:unistream/repositories/preferences_repository.dart';

class CacheSection extends ConsumerStatefulWidget {
  const CacheSection({super.key});

  @override
  ConsumerState<CacheSection> createState() => _CacheSectionState();
}

class _CacheSectionState extends ConsumerState<CacheSection> {
  int _persistedEpgEntries = 0;

  @override
  void initState() {
    super.initState();
    _countPersistedEpg();
  }

  Future<void> _countPersistedEpg() async {
    try {
      final prefs = ref.read(preferencesRepositoryProvider);
      final count = await prefs.countPersistedEpgEntries(AppConfig.activeProfileId);
      if (mounted) setState(() => _persistedEpgEntries = count);
    } catch (e, st) {
      AppLogger.warning('settings', 'Failed to count persisted EPG entries', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final contentRepo = ref.read(contentRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: tc.divider),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            header: true,
            child: Text(l10n.cacheSection,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tc.textDisabled,
                    letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 12),
        // In-memory EPG cache
        Row(children: [
          ExcludeSemantics(child: Icon(Icons.data_usage, size: 20, color: tc.textTertiary)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(l10n.cacheEpgEntrees(contentRepo.epgCacheSize),
                  style: const TextStyle(fontSize: 14))),
        ]),
        const SizedBox(height: 4),
        // Persisted EPG cache
        Row(children: [
          ExcludeSemantics(child: Icon(Icons.save_outlined, size: 20, color: tc.textTertiary)),
          const SizedBox(width: 12),
          Expanded(
              child: Text('$_persistedEpgEntries ${_persistedEpgEntries == 1 ? 'entr\u00e9e' : 'entr\u00e9es'} EPG sur disque',
                  style: TextStyle(fontSize: 13, color: tc.textSecondary))),
        ]),
        const SizedBox(height: 12),
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
              await ref.read(contentRepositoryProvider).clearAllEpgCache();
              setState(() => _persistedEpgEntries = 0);
              if (!context.mounted) return;
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
              if (context.mounted) {
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
