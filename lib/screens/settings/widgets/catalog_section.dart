import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unistream/l10n/app_localizations.dart';
import '../../../core/theme_colors.dart';
import '../../../providers/catalog_refresh_provider.dart';
import '../../../utils/snackbar_helper.dart';

/// "Catalogue" settings block — when the app last pulled the provider's
/// catalogue, a button to do it now, and how often it should happen on
/// its own. Mirror of the tvOS `SettingsView` Catalogue section.
///
/// This is deliberately separate from the Cache block below it: clearing
/// caches is about disk usage, this is about content freshness.
class CatalogSection extends ConsumerWidget {
  const CatalogSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(catalogRefreshProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: tc.divider),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            header: true,
            child: Text(l10n.catalogueSection,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tc.textDisabled,
                    letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          ExcludeSemantics(
              child: Icon(Icons.update, size: 20, color: tc.textTertiary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.derniereActualisation(_ageLabel(context, state.lastRefresh)),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: state.isRefreshing
              ? null
              : () async {
                  final done = await ref
                      .read(catalogRefreshProvider.notifier)
                      .refresh();
                  if (!context.mounted || !done) return;
                  showAppSnackBar(context, l10n.catalogueActualise);
                },
          icon: state.isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh, size: 18),
          label: Text(l10n.actualiserCatalogue),
          style: OutlinedButton.styleFrom(
            foregroundColor: tc.textSecondary,
            side: BorderSide(color: tc.borderColor),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          ExcludeSemantics(
              child: Icon(Icons.schedule, size: 20, color: tc.textTertiary)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Text(l10n.actualisationAuto, style: const TextStyle(fontSize: 14)),
          ),
          DropdownButton<CatalogRefreshInterval>(
            value: state.interval,
            underline: const SizedBox.shrink(),
            onChanged: (value) {
              if (value == null) return;
              ref.read(catalogRefreshProvider.notifier).setInterval(value);
            },
            items: CatalogRefreshInterval.values
                .map((i) => DropdownMenuItem(
                      value: i,
                      child: Text(_intervalLabel(l10n, i),
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
          ),
        ]),
        const SizedBox(height: 8),
        Text(l10n.descriptionCatalogue,
            style: TextStyle(fontSize: 11, color: tc.textDisabled)),
      ],
    );
  }

  static String _intervalLabel(
      AppLocalizations l10n, CatalogRefreshInterval interval) {
    return switch (interval) {
      CatalogRefreshInterval.manual => l10n.actualisationManuelle,
      CatalogRefreshInterval.sixHours => l10n.actualisation6h,
      CatalogRefreshInterval.twelveHours => l10n.actualisation12h,
      CatalogRefreshInterval.daily => l10n.actualisationQuotidienne,
    };
  }

  static String _ageLabel(BuildContext context, DateTime? last) {
    final l10n = AppLocalizations.of(context)!;
    if (last == null) return l10n.jamais;
    final diff = DateTime.now().difference(last);
    if (diff.inMinutes < 1) return l10n.alInstant;
    if (diff.inHours < 1) return l10n.ilYaMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l10n.ilYaHeures(diff.inHours);
    return l10n.ilYaJours(diff.inDays);
  }
}
