import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../../models/content_mode.dart';
import '../../../models/category.dart' as cat;
import '../../../models/collection_data.dart';
import '../../../models/favorite_item.dart';

/// Resizable category sidebar with favorites, watchlist, history, collections, and categories.
class CategorySidebar extends StatelessWidget {
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

  // Favorites / Watchlist data
  final List<FavoriteItem> favItems;
  final List<FavoriteItem> wlItems;

  // Callbacks
  final void Function(String categoryId) onCategorySelected;
  final void Function(String specialCategory, List<Map<String, dynamic>> items) onSpecialCategorySelected;
  final VoidCallback onHistoryTap;
  final VoidCallback onCreateCollection;
  final void Function(String collectionId) onCollectionSelected;
  final void Function(String collectionId) onDeleteCollection;

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

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          child: _buildSidebarList(context),
        ),
        // Resize handle
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) {
              onWidthChanged(d.delta.dx);
            },
            onHorizontalDragEnd: (_) => onDragEnd(),
            child: Container(
              width: 5,
              color: Colors.transparent,
              child: Center(child: VerticalDivider(width: 1, color: tc.divider)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarList(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final modeCollections = collections.where((c) =>
        c.mode == null || c.mode == mode.key).toList();

    // Wrap the inner Scrollable in a Focus that refuses focus for itself
    // and its descendants. Without this, every click on a category tile
    // promotes the underlying ListView's Scrollable to primary focus and
    // Flutter draws a dashed rectangle around the whole sidebar — visible
    // as a flickering pointillé border on each click. The global
    // FocusHighlightStrategy.alwaysTouch we set in main() doesn't cover
    // Scrollable's own focus rendering; this does. Trade-off is no
    // keyboard PageUp/PageDown navigation inside the sidebar, which a
    // category list doesn't really need anyway.
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: ListView.builder(
      // Top padding reserves room for the translucent app bar above (the
      // Scaffold now has extendBodyBehindAppBar: true), so sidebar items
      // don't appear under the "UniStream" title.
      padding: EdgeInsets.fromLTRB(
        8,
        kToolbarHeight + MediaQuery.paddingOf(context).top + 8,
        8,
        8,
      ),
      itemCount: () {
        return categories.length + 3 + modeCollections.length + (modeCollections.isNotEmpty ? 1 : 0);
      }(),
      itemBuilder: (_, i) {
        final modeColList = modeCollections;

        // Favorites row
        if (i == 0) {
          final sel = selectedCategory == '__favorites__';
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.star, size: 16,
                  color: sel ? Colors.amber : Colors.amber.withValues(alpha: 0.5)),
              title: Text(l10n.favoris, style: TextStyle(fontSize: 13,
                  color: sel ? tc.textPrimary : tc.textSecondary,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              selected: sel,
              selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () {
                final modeFavs = favItems.where((e) => e.mode == mode.key).toList();
                onSpecialCategorySelected('__favorites__', modeFavs.map((e) => e.toJson()).toList());
              },
            ),
          );
        }

        // Watchlist row
        if (i == 1) {
          final sel = selectedCategory == '__watchlist__';
          final wlModeItems = wlItems.where((e) => e.mode == mode.key).toList();
          final wlCount = wlModeItems.length;
          final unwatchedCount = wlModeItems.where((e) {
            final id = mode == ContentMode.series ? e.seriesId : e.streamId;
            if (id == null) return true;
            final p = progress[id];
            return p == null || p <= 0.95;
          }).length;
          final countLabel = wlCount > 0
              ? (unwatchedCount < wlCount ? ' ($unwatchedCount/$wlCount)' : ' ($wlCount)')
              : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              dense: true,
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.bookmark, size: 16,
                      color: sel ? Colors.tealAccent : Colors.tealAccent.withValues(alpha: 0.5)),
                  if (unwatchedCount > 0)
                    Positioned(top: -4, right: -6,
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text('${l10n.aRegarder}$countLabel', style: TextStyle(fontSize: 13,
                  color: sel ? tc.textPrimary : tc.textSecondary,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              selected: sel,
              selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () {
                final modeWl = wlItems.where((e) => e.mode == mode.key).toList();
                onSpecialCategorySelected('__watchlist__', modeWl.map((e) => e.toJson()).toList());
              },
            ),
          );
        }

        // History row
        if (i == 2) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.history, size: 16, color: tc.textTertiary),
              title: Text(l10n.historique, style: TextStyle(fontSize: 13, color: tc.textSecondary)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: onHistoryTap,
            ),
          );
        }

        // Collections section
        final colHeaderIdx = 3;
        final colStartIdx = modeColList.isNotEmpty ? colHeaderIdx + 1 : colHeaderIdx;
        final colEndIdx = colStartIdx + modeColList.length;
        final catStartIdx = colEndIdx;

        if (modeColList.isNotEmpty && i == colHeaderIdx) {
          return Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2, left: 8, right: 4),
            child: Row(children: [
              Text(l10n.collectionsSection, style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.bold, color: tc.textDisabled, letterSpacing: 0.8)),
              const Spacer(),
              SizedBox(
                width: 24, height: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: Icon(Icons.add, color: tc.textDisabled),
                  tooltip: l10n.nouvelleCollection,
                  onPressed: onCreateCollection,
                ),
              ),
            ]),
          );
        }

        if (i >= colStartIdx && i < colEndIdx) {
          final col = modeColList[i - colStartIdx];
          final colId = '__col_${col.id}__';
          final sel = selectedCategory == colId;
          final items = col.items;
          final count = col.mode != null
              ? items.length
              : items.where((e) => e.mode == mode.key).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.folder_outlined, size: 16,
                  color: sel ? AppColors.primaryBlue : tc.textDisabled),
              title: Text('${col.name} ($count)', style: TextStyle(fontSize: 13,
                  color: sel ? tc.textPrimary : tc.textSecondary,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              selected: sel,
              selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () => onCollectionSelected(col.id),
              trailing: SizedBox(
                width: 24, height: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: Icon(Icons.delete_outline, size: 16, color: tc.borderColor),
                  tooltip: l10n.supprimer,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: tc.surface,
                        title: Text(l10n.confirmerSupprimerCollection,
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
                    if (confirmed == true) {
                      onDeleteCollection(col.id);
                    }
                  },
                ),
              ),
            ),
          );
        }

        // Regular categories
        final category = categories[i - catStartIdx];
        final id  = category.categoryId;
        final sel = selectedCategory == id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            dense: true,
            title: Text(category.categoryName,
                style: TextStyle(fontSize: 13,
                    color: sel ? tc.textPrimary : tc.textSecondary,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                overflow: TextOverflow.ellipsis),
            selected: sel,
            selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => onCategorySelected(id),
          ),
        );
      },
      ),
    );
  }
}
