import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../../core/colors.dart';
import '../../../core/theme_colors.dart';
import '../../../models/app_config.dart';
import '../../../models/content_mode.dart';

/// AppBar for the HomeScreen — profile switcher, content mode toggle,
/// sort / grid / EPG / search / settings / shortcuts buttons.
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
    required this.segment,
    required this.showGrid,
    required this.sortMode,
    required this.onSegmentChanged,
    required this.onGridToggle,
    required this.onSortChanged,
    required this.onEpgPressed,
    required this.onSearchPressed,
    required this.onFavoritesPressed,
    required this.onSettingsPressed,
    required this.onShortcutsPressed,
    required this.onProfileChanged,
    required this.selectedCategory,
    this.leadingMenuButton,
    this.isCompact = false,
    this.scrollOffset,
  });

  /// Optional scroll offset (of the main content below) used to fade the
  /// app bar background from transparent (at the top, over the hero) to
  /// opaque (as soon as tiles start scrolling behind it). `null` keeps the
  /// classic behaviour (solid background).
  final ValueListenable<double>? scrollOffset;

  final HomeSegment segment;
  final bool showGrid;
  final String sortMode;
  final ValueChanged<HomeSegment> onSegmentChanged;
  final VoidCallback onGridToggle;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onEpgPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onFavoritesPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onShortcutsPressed;
  final ValueChanged<String> onProfileChanged;
  final String? selectedCategory;
  final Widget? leadingMenuButton;
  final bool isCompact;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tc = AppThemeColors.of(context);

    // Fade from transparent (over the hero) to the theme's surface color as
    // the main content scrolls — otherwise tile typography bleeds through.
    if (scrollOffset != null) {
      return ValueListenableBuilder<double>(
        valueListenable: scrollOffset!,
        builder: (context, offset, _) {
          final t = (offset / 120).clamp(0.0, 1.0);
          return _buildBar(
            context,
            l10n,
            tc,
            backgroundColor: tc.surface.withValues(alpha: t),
            elevation: t > 0.9 ? 1 : 0,
          );
        },
      );
    }
    return _buildBar(context, l10n, tc,
        backgroundColor: Colors.transparent, elevation: 0);
  }

  Widget _buildBar(
    BuildContext context,
    AppLocalizations l10n,
    AppThemeColors tc, {
    required Color backgroundColor,
    required double elevation,
  }) {
    return AppBar(
      title: isCompact ? null : const Text('UniStream',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      backgroundColor: backgroundColor,
      elevation: elevation,
      leading: leadingMenuButton,
      automaticallyImplyLeading: false,
      actions: [
        if (!isCompact && AppConfig.profiles.length > 1)
          PopupMenuButton<String>(
            icon: Text(
              AppConfig.profiles
                  .firstWhere((p) => p.id == AppConfig.activeProfileId,
                      orElse: () => AppConfig.profiles.first)
                  .avatar,
              style: const TextStyle(fontSize: 22),
            ),
            tooltip: l10n.changerProfil,
            onSelected: onProfileChanged,
            itemBuilder: (_) => AppConfig.profiles
                .map((pr) => PopupMenuItem(
                      value: pr.id,
                      child: Row(children: [
                        Text(pr.avatar,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(pr.name,
                            style: const TextStyle(fontSize: 13)),
                        if (pr.id == AppConfig.activeProfileId) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check,
                              size: 16, color: AppColors.primaryBlue),
                        ],
                      ]),
                    ))
                .toList(),
          ),
        ToggleButtons(
          isSelected: <bool>[
            segment == HomeSegment.home,
            segment == HomeSegment.live,
            segment == HomeSegment.vod,
            segment == HomeSegment.series,
          ],
          onPressed: (i) => onSegmentChanged(HomeSegment.values[i]),
          borderRadius: BorderRadius.circular(8),
          selectedColor: tc.textPrimary,
          fillColor: AppColors.primaryBlue,
          children: <Widget>[
            Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16),
                child: Text(l10n.accueilTab)),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16),
                child: Text(l10n.live)),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16),
                child: Text(l10n.vod)),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16),
                child: Text(l10n.series)),
          ],
        ),
        const SizedBox(width: 4),
        // Grid + sort make no sense on Accueil — every section has its
        // own intrinsic ordering and there's no flat list to toggle.
        if (!isCompact && segment != HomeSegment.home)
          IconButton(
            icon: Icon(showGrid ? Icons.view_list : Icons.grid_view),
            tooltip:
                showGrid ? l10n.vueListe : l10n.vueGrille,
            onPressed: onGridToggle,
          ),
        if (!isCompact && segment != HomeSegment.home)
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.trier,
            onSelected: onSortChanged,
            itemBuilder: (_) => [
              _sortItem('default', l10n.ordreParDefaut),
              _sortItem('alpha', l10n.alphabetique),
              _sortItem('number', l10n.parNumero),
              _sortItem('favFirst', l10n.favorisPremier),
            ],
          ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: l10n.rechercheGlobale,
          onPressed: onSearchPressed,
        ),
        IconButton(
          icon: const Icon(Icons.favorite_border),
          tooltip: l10n.favoris,
          onPressed: onFavoritesPressed,
        ),
        if (!isCompact) ...[
          IconButton(
            icon: const Icon(Icons.live_tv),
            tooltip: l10n.guideTV,
            onPressed: onEpgPressed,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: onSettingsPressed,
            tooltip: l10n.parametres,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            onPressed: onShortcutsPressed,
            tooltip: '${l10n.raccourcisClavier} (Cmd+?)',
          ),
        ],
        if (isCompact)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'grid': onGridToggle();
                case 'epg': onEpgPressed();
                case 'settings': onSettingsPressed();
                case 'sort_default': onSortChanged('default');
                case 'sort_alpha': onSortChanged('alpha');
                case 'sort_number': onSortChanged('number');
                case 'sort_favFirst': onSortChanged('favFirst');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'grid', child: Row(children: [
                Icon(showGrid ? Icons.view_list : Icons.grid_view, size: 18),
                const SizedBox(width: 8),
                Text(showGrid ? l10n.vueListe : l10n.vueGrille),
              ])),
              PopupMenuItem(value: 'epg', child: Row(children: [
                const Icon(Icons.live_tv, size: 18),
                const SizedBox(width: 8),
                Text(l10n.guideTV),
              ])),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'sort_default', child: Row(children: [
                Icon(sortMode == 'default' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(l10n.ordreParDefaut),
              ])),
              PopupMenuItem(value: 'sort_alpha', child: Row(children: [
                Icon(sortMode == 'alpha' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(l10n.alphabetique),
              ])),
              PopupMenuItem(value: 'sort_number', child: Row(children: [
                Icon(sortMode == 'number' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(l10n.parNumero),
              ])),
              PopupMenuItem(value: 'sort_favFirst', child: Row(children: [
                Icon(sortMode == 'favFirst' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(l10n.favorisPremier),
              ])),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'settings', child: Row(children: [
                const Icon(Icons.settings_outlined, size: 18),
                const SizedBox(width: 8),
                Text(l10n.parametres),
              ])),
            ],
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(
          sortMode == value
              ? Icons.radio_button_checked
              : Icons.radio_button_off,
          size: 16,
          color: AppColors.primaryBlue,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }
}
