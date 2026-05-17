import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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
  int? _imageCacheBytes;

  @override
  void initState() {
    super.initState();
    _countPersistedEpg();
    _measureImageCache();
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

  /// Walks `flutter_cache_manager`'s temp directory and sums up
  /// every file's length so the Settings row can show a live
  /// estimate of the image-cache footprint. Mirror of tvOS
  /// `SettingsView.swift:166-187`. Async + best-effort — a failure
  /// just hides the row instead of crashing settings.
  Future<void> _measureImageCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/${AppCacheManager.key}');
      if (!await cacheDir.exists()) {
        if (mounted) setState(() => _imageCacheBytes = 0);
        return;
      }
      var total = 0;
      await for (final entity in cacheDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // Skip files we can't stat (race with cache eviction).
          }
        }
      }
      if (mounted) setState(() => _imageCacheBytes = total);
    } catch (e, st) {
      AppLogger.warning('settings', 'Failed to measure image cache',
          error: e, stackTrace: st);
    }
  }

  /// "12.4 Mo" / "843 Ko" / "612 o" — three-tier humaniser, FR units.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
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
        // Image cache disk size \u2014 mirror of tvOS Settings row.
        // Hidden while we don't have a measurement yet so the row
        // doesn't flash "0 o" then jump to the real value.
        if (_imageCacheBytes != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            ExcludeSemantics(child: Icon(Icons.photo_library_outlined, size: 20, color: tc.textTertiary)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    'Cache images : ${_formatBytes(_imageCacheBytes!)}',
                    style: TextStyle(fontSize: 13, color: tc.textSecondary))),
          ]),
        ],
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
              // Re-measure so the row drops back to a few KB (the
              // CacheManager keeps its sqlite metadata file).
              await _measureImageCache();
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
