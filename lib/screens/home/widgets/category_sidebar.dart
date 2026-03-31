import 'package:flutter/material.dart';
import '../../../models/content_mode.dart';

/// Resizable category sidebar with favorites, watchlist, history, collections, and categories.
class CategorySidebar extends StatelessWidget {
  final double width;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onDragEnd;

  final List<dynamic> categories;
  final List<Map<String, dynamic>> collections;
  final ContentMode mode;
  final String? selectedCategory;
  final Map<String, double> progress;

  // Favorites / Watchlist data
  final List<Map<String, dynamic>> favItems;
  final List<Map<String, dynamic>> wlItems;

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          child: _buildSidebarList(),
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
              child: const Center(child: VerticalDivider(width: 1, color: Colors.white12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarList() {
    final modeCollections = collections.where((c) =>
        c['mode'] == null || c['mode'] == mode.key).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
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
              title: Text('Favoris', style: TextStyle(fontSize: 13,
                  color: sel ? Colors.white : Colors.white60,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              selected: sel,
              selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () {
                final modeFavs = favItems.where((e) => e['_mode'] == mode.key).toList();
                onSpecialCategorySelected('__favorites__', modeFavs);
              },
            ),
          );
        }

        // Watchlist row
        if (i == 1) {
          final sel = selectedCategory == '__watchlist__';
          final wlModeItems = wlItems.where((e) => e['_mode'] == mode.key).toList();
          final wlCount = wlModeItems.length;
          final unwatchedCount = wlModeItems.where((e) {
            final id = mode == ContentMode.series ? e['series_id']?.toString() : e['stream_id']?.toString();
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
                          color: Color(0xFF4A90D9),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text('À regarder$countLabel', style: TextStyle(fontSize: 13,
                  color: sel ? Colors.white : Colors.white60,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              selected: sel,
              selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () {
                final modeWl = wlItems.where((e) => e['_mode'] == mode.key).toList();
                onSpecialCategorySelected('__watchlist__', modeWl);
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
              leading: const Icon(Icons.history, size: 16, color: Colors.white54),
              title: const Text('Historique', style: TextStyle(fontSize: 13, color: Colors.white60)),
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
              const Text('COLLECTIONS', style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 0.8)),
              const Spacer(),
              SizedBox(
                width: 24, height: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.add, color: Colors.white38),
                  tooltip: 'Nouvelle collection',
                  onPressed: onCreateCollection,
                ),
              ),
            ]),
          );
        }

        if (i >= colStartIdx && i < colEndIdx) {
          final col = modeColList[i - colStartIdx];
          final colId = '__col_${col['id']}__';
          final sel = selectedCategory == colId;
          final items = (col['items'] as List?) ?? [];
          final count = col['mode'] != null
              ? items.length
              : items.where((e) => e['mode'] == mode.key).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.folder_outlined, size: 16,
                  color: sel ? const Color(0xFF4A90D9) : Colors.white38),
              title: Text('${col['name']} ($count)', style: TextStyle(fontSize: 13,
                  color: sel ? Colors.white : Colors.white60,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              selected: sel,
              selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () => onCollectionSelected(col['id'] as String),
              trailing: SizedBox(
                width: 24, height: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white24),
                  tooltip: 'Supprimer',
                  onPressed: () => onDeleteCollection(col['id'] as String),
                ),
              ),
            ),
          );
        }

        // Regular categories
        final cat = categories[i - catStartIdx];
        final id  = cat['category_id'].toString();
        final sel = selectedCategory == id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            dense: true,
            title: Text(cat['category_name'] ?? '',
                style: TextStyle(fontSize: 13,
                    color: sel ? Colors.white : Colors.white60,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                overflow: TextOverflow.ellipsis),
            selected: sel,
            selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => onCategorySelected(id),
          ),
        );
      },
    );
  }
}
