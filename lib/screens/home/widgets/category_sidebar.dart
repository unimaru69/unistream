import 'package:flutter/material.dart';

import 'package:unistream/core/colors.dart';
import 'package:unistream/core/design_tokens.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/core/typography.dart';
import 'package:unistream/l10n/app_localizations.dart';

import '../../../models/category.dart' as cat;
import '../../../models/collection_data.dart';
import '../../../models/content_mode.dart';
import '../../../models/favorite_item.dart';

/// Resizable category sidebar. Apple-TV+-styled rows: hover lifts the
/// row with a translucent background and chipScale, selected rows wear
/// a teal accent fill + bold title. Mirror of
/// `tvos/.../CategoryRowLabel.swift` adapted for desktop (mouse hover
/// instead of focus engine).
///
/// Public API is intentionally identical to the previous implementation
/// — both the wide-layout split view and the narrow drawer in
/// `home_screen.dart` instantiate this widget the same way.
class CategorySidebar extends StatelessWidget {
  const CategorySidebar({
    super.key,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.onWidthChanged,
    required this.onDragEnd,
    required this.categories,
    required this.collections,
    required this.mode,
    required this.selectedCategory,
    required this.progress,
    required this.favItems,
    required this.wlItems,
    required this.onCategorySelected,
    required this.onSpecialCategorySelected,
    required this.onHistoryTap,
    required this.onCreateCollection,
    required this.onCollectionSelected,
    required this.onDeleteCollection,
  });

  final double width;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onDragEnd;

  final List<cat.Category> categories;
  final List<CollectionData> collections;
  final ContentMode mode;
  final String? selectedCategory;
  final Map<String, double> progress;

  final List<FavoriteItem> favItems;
  final List<FavoriteItem> wlItems;

  final void Function(String categoryId) onCategorySelected;
  final void Function(
    String specialCategory,
    List<Map<String, dynamic>> items,
  ) onSpecialCategorySelected;
  final VoidCallback onHistoryTap;
  final VoidCallback onCreateCollection;
  final void Function(String collectionId) onCollectionSelected;
  final void Function(String collectionId) onDeleteCollection;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: width,
          child: _SidebarList(
            categories: categories,
            collections: collections,
            mode: mode,
            selectedCategory: selectedCategory,
            progress: progress,
            favItems: favItems,
            wlItems: wlItems,
            onCategorySelected: onCategorySelected,
            onSpecialCategorySelected: onSpecialCategorySelected,
            onHistoryTap: onHistoryTap,
            onCreateCollection: onCreateCollection,
            onCollectionSelected: onCollectionSelected,
            onDeleteCollection: onDeleteCollection,
          ),
        ),
        // Resize handle. RepaintBoundary stops a setState in the parent
        // (every category click rebuilds home_screen) from forcing a
        // full repaint of the divider; without it the 1-px line's
        // subpixel AA produces a visible flicker. Plain Container
        // instead of VerticalDivider — the latter has documented
        // rendering quirks at 1 px on EGL / high-DPI.
        RepaintBoundary(
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (d) => onWidthChanged(d.delta.dx),
              onHorizontalDragEnd: (_) => onDragEnd(),
              child: SizedBox(
                width: 5,
                child: Center(
                  child: SizedBox(
                    width: 1,
                    height: double.infinity,
                    child: ColoredBox(color: tc.divider),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarList extends StatelessWidget {
  const _SidebarList({
    required this.categories,
    required this.collections,
    required this.mode,
    required this.selectedCategory,
    required this.progress,
    required this.favItems,
    required this.wlItems,
    required this.onCategorySelected,
    required this.onSpecialCategorySelected,
    required this.onHistoryTap,
    required this.onCreateCollection,
    required this.onCollectionSelected,
    required this.onDeleteCollection,
  });

  final List<cat.Category> categories;
  final List<CollectionData> collections;
  final ContentMode mode;
  final String? selectedCategory;
  final Map<String, double> progress;
  final List<FavoriteItem> favItems;
  final List<FavoriteItem> wlItems;
  final void Function(String) onCategorySelected;
  final void Function(String, List<Map<String, dynamic>>) onSpecialCategorySelected;
  final VoidCallback onHistoryTap;
  final VoidCallback onCreateCollection;
  final void Function(String) onCollectionSelected;
  final void Function(String) onDeleteCollection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tc = AppThemeColors.of(context);

    final modeCollections = collections
        .where((c) => c.mode == null || c.mode == mode.key)
        .toList();
    final modeWl = wlItems.where((e) => e.mode == mode.key).toList();
    final unwatchedCount = modeWl.where((e) {
      final id = mode == ContentMode.series ? e.seriesId : e.streamId;
      if (id == null) return true;
      final p = progress[id];
      return p == null || p <= 0.95;
    }).length;
    final wlCount = modeWl.length;
    final wlSuffix = wlCount > 0
        ? (unwatchedCount < wlCount
            ? ' ($unwatchedCount/$wlCount)'
            : ' ($wlCount)')
        : '';

    final children = <Widget>[
      // Top padding lifts the first row below the translucent app bar
      // (Scaffold.extendBodyBehindAppBar = true on home).
      SizedBox(
        height: kToolbarHeight + MediaQuery.paddingOf(context).top + DS.space.xs,
      ),

      _SidebarRow(
        icon: Icons.favorite,
        iconActiveColor: AppColors.accentWarm,
        title: l10n.favoris,
        selected: selectedCategory == '__favorites__',
        onTap: () {
          final modeFavs =
              favItems.where((e) => e.mode == mode.key).toList();
          onSpecialCategorySelected(
            '__favorites__',
            modeFavs.map((e) => e.toJson()).toList(),
          );
        },
      ),

      _SidebarRow(
        icon: Icons.bookmark,
        iconActiveColor: AppColors.primaryBlue,
        title: '${l10n.aRegarder}$wlSuffix',
        selected: selectedCategory == '__watchlist__',
        unreadDot: unwatchedCount > 0,
        onTap: () {
          onSpecialCategorySelected(
            '__watchlist__',
            modeWl.map((e) => e.toJson()).toList(),
          );
        },
      ),

      _SidebarRow(
        icon: Icons.history,
        title: l10n.historique,
        selected: false,
        onTap: onHistoryTap,
      ),

      if (modeCollections.isNotEmpty)
        _SidebarSectionHeader(
          label: l10n.collectionsSection,
          trailing: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 16,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon: Icon(Icons.add, color: DS.colour.textTertiary),
            tooltip: l10n.nouvelleCollection,
            onPressed: onCreateCollection,
          ),
        ),

      ...modeCollections.map((col) {
        final colId = '__col_${col.id}__';
        final selected = selectedCategory == colId;
        final items = col.items;
        final count = col.mode != null
            ? items.length
            : items.where((e) => e.mode == mode.key).length;
        return _SidebarRow(
          icon: Icons.folder_outlined,
          iconActiveColor: AppColors.primaryBlue,
          title: '${col.name} ($count)',
          selected: selected,
          onTap: () => onCollectionSelected(col.id),
          trailing: _DeleteCollectionButton(
            onConfirmed: () => onDeleteCollection(col.id),
            backgroundColor: tc.surface,
          ),
        );
      }),

      if (categories.isNotEmpty)
        _SidebarSectionHeader(label: l10n.categoriesHeader),

      ...categories.map((category) {
        final id = category.categoryId;
        return _SidebarRow(
          icon: Icons.folder_outlined,
          title: category.categoryName,
          selected: selectedCategory == id,
          onTap: () => onCategorySelected(id),
        );
      }),

      SizedBox(height: DS.space.lg),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: children,
    );
  }
}

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconActiveColor,
    this.trailing,
    this.unreadDot = false,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Colour the icon picks up when the row is selected. Defaults to
  /// the brand teal — pass `AppColors.accentWarm` for the favourites
  /// row, etc.
  final Color? iconActiveColor;
  final Widget? trailing;
  final bool unreadDot;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;

  void _setHover(bool v) {
    if (_hovered == v) return;
    setState(() => _hovered = v);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final hovered = _hovered;

    final Color bg;
    final Color iconColor;
    final Color textColor;
    final FontWeight weight;

    if (selected) {
      bg = AppColors.primaryBlue.withValues(alpha: 0.25);
      iconColor = widget.iconActiveColor ?? AppColors.primaryBlue;
      textColor = Colors.white;
      weight = FontWeight.w600;
    } else if (hovered) {
      bg = Colors.white.withValues(alpha: 0.08);
      iconColor = Colors.white;
      textColor = Colors.white;
      weight = FontWeight.w500;
    } else {
      bg = Colors.transparent;
      iconColor = DS.colour.textTertiary;
      textColor = DS.colour.textSecondary;
      weight = FontWeight.w400;
    }

    final scale = hovered && !selected ? DS.focus.chipScale : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: scale,
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          child: AnimatedContainer(
            duration: DS.focus.animation,
            curve: DS.focus.curve,
            margin: EdgeInsets.symmetric(
              horizontal: DS.space.xs,
              vertical: 1,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: DS.space.sm,
              vertical: DS.space.sm,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(DS.radius.card),
            ),
            child: Row(
              children: <Widget>[
                if (widget.icon != null) ...<Widget>[
                  _IconWithDot(
                    icon: widget.icon!,
                    color: iconColor,
                    showDot: widget.unreadDot,
                  ),
                  SizedBox(width: DS.space.sm),
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: DSText.body.copyWith(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: weight,
                    ),
                  ),
                ),
                if (widget.trailing != null) ...<Widget>[
                  SizedBox(width: DS.space.xxs),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconWithDot extends StatelessWidget {
  const _IconWithDot({
    required this.icon,
    required this.color,
    required this.showDot,
  });

  final IconData icon;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final base = Icon(icon, size: 18, color: color);
    if (!showDot) return base;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        base,
        Positioned(
          top: -3,
          right: -4,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.darkBackground,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DS.space.md,
        DS.space.md,
        DS.space.xs,
        DS.space.xxs,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: DSText.label.copyWith(
                color: DS.colour.textTertiary,
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _DeleteCollectionButton extends StatelessWidget {
  const _DeleteCollectionButton({
    required this.onConfirmed,
    required this.backgroundColor,
  });

  final VoidCallback onConfirmed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(
          Icons.delete_outline,
          size: 16,
          color: DS.colour.textTertiary,
        ),
        tooltip: l10n.supprimer,
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: backgroundColor,
              title: Text(
                l10n.confirmerSupprimerCollection,
                style: DSText.title3,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.annuler),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    l10n.supprimer,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );
          if (confirmed == true) onConfirmed();
        },
      ),
    );
  }
}
