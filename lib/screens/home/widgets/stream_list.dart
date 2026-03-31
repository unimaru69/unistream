import 'package:flutter/material.dart';
import '../../../models/content_mode.dart';
import '../../../services/xtream_api.dart';
import '../../../widgets/skeleton_list.dart';
import 'stream_tile.dart';

/// Main stream content area: search bar, selection bar, list/grid view.
class StreamListView extends StatelessWidget {
  final ContentMode mode;
  final String? selectedCategory;
  final bool loadingStreams;
  final bool showGrid;
  final List<dynamic> sortedStreams;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final Map<String, double> progress;
  final Set<String> favKeys;
  final Set<String> wlKeys;

  // Selection mode
  final bool selectionMode;
  final Set<String> selectedItems;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onExitSelectionMode;
  final VoidCallback onSelectAll;
  final VoidCallback onCreateCollectionFromSelected;
  final void Function(String key) onToggleSelection;

  // Active collection
  final String? activeCollectionId;

  // Callbacks
  final void Function(Map<String, dynamic> stream) onPlayStream;
  final void Function(Map<String, dynamic> stream) onToggleFavorite;
  final void Function(Map<String, dynamic> stream) onToggleWatchlist;
  final void Function(Map<String, dynamic> stream) onShowStreamInfo;
  final void Function(Map<String, dynamic> stream) onRemoveFromCollection;
  final String Function(String modeKey, Map<String, dynamic> stream) favKeyBuilder;
  final String Function(Map<String, dynamic> stream) itemSelectionKeyBuilder;
  final String? Function(Map<String, dynamic> stream) progressKeyBuilder;

  const StreamListView({
    super.key,
    required this.mode,
    required this.selectedCategory,
    required this.loadingStreams,
    required this.showGrid,
    required this.sortedStreams,
    required this.searchQuery,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.progress,
    required this.favKeys,
    required this.wlKeys,
    required this.selectionMode,
    required this.selectedItems,
    required this.onEnterSelectionMode,
    required this.onExitSelectionMode,
    required this.onSelectAll,
    required this.onCreateCollectionFromSelected,
    required this.onToggleSelection,
    required this.activeCollectionId,
    required this.onPlayStream,
    required this.onToggleFavorite,
    required this.onToggleWatchlist,
    required this.onShowStreamInfo,
    required this.onRemoveFromCollection,
    required this.favKeyBuilder,
    required this.itemSelectionKeyBuilder,
    required this.progressKeyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCategory == null) {
      return const Center(child: Text('Sélectionne une catégorie',
          style: TextStyle(color: Colors.white38, fontSize: 16)));
    }
    if (loadingStreams) {
      return SkeletonList(count: showGrid ? 16 : 12, isGrid: showGrid);
    }

    return Column(children: [
      // Selection bar or search bar
      if (selectionMode)
        _buildSelectionBar()
      else
        _buildSearchBar(),
      Expanded(child: Builder(builder: (ctx) {
        final filtered = searchQuery.isEmpty
            ? sortedStreams
            : sortedStreams.where((s) => (s['name'] ?? '')
                .toString().toLowerCase().contains(searchQuery)).toList();
        if (showGrid) return _buildGrid(filtered);
        return _buildList(filtered);
      })),
    ]);
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(children: [
        Text('${selectedItems.length} sélectionné${selectedItems.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 13, color: Colors.white70)),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.select_all, size: 16),
          label: const Text('Tout', style: TextStyle(fontSize: 12)),
          onPressed: onSelectAll,
        ),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: Color(0xFF4A90D9)),
          label: const Text('Créer collection', style: TextStyle(fontSize: 12, color: Color(0xFF4A90D9))),
          onPressed: selectedItems.isEmpty ? null : onCreateCollectionFromSelected,
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: Colors.white54),
          tooltip: 'Annuler la sélection',
          onPressed: onExitSelectionMode,
        ),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Expanded(child: TextField(
          controller: searchCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Rechercher...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                    onPressed: onClearSearch,
                  )
                : null,
            isDense: true, filled: true, fillColor: Colors.white10,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onChanged: onSearchChanged,
        )),
        if (selectedCategory == '__favorites__' || selectedCategory == '__watchlist__')
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Tooltip(
              message: 'Sélectionner pour créer une collection',
              child: IconButton(
                icon: const Icon(Icons.checklist, size: 20, color: Color(0xFF4A90D9)),
                onPressed: sortedStreams.isEmpty ? null : onEnterSelectionMode,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildList(List<dynamic> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final s = items[i] as Map<String, dynamic>;
        final pKey = progressKeyBuilder(s);
        final prog = pKey != null ? progress[pKey] : null;
        // For live channels, show cached current program as subtitle
        String? liveEpgTitle;
        if (mode == ContentMode.live) {
          final sid = s['stream_id']?.toString() ?? '';
          if (sid.isNotEmpty) liveEpgTitle = XtreamApi.getCachedEpgNow(sid);
        }
        Widget? subtitle;
        if (prog != null || liveEpgTitle != null) {
          subtitle = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (liveEpgTitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(liveEpgTitle, style: const TextStyle(fontSize: 11, color: Colors.tealAccent),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              if (prog != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LinearProgressIndicator(
                    value: prog,
                    backgroundColor: Colors.white12,
                    color: Colors.amber,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          );
        }
        final selKey = itemSelectionKeyBuilder(s);
        final isSelected = selectionMode && selectedItems.contains(selKey);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: GestureDetector(
            onSecondaryTapUp: selectionMode ? null : (_) => onShowStreamInfo(s),
            child: ListTile(
              leading: selectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggleSelection(selKey),
                      activeColor: const Color(0xFF4A90D9),
                    )
                  : listIcon(s, mode),
              title: Text(s['name'] ?? 'Sans titre',
                  style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
              subtitle: subtitle,
              trailing: selectionMode ? null : Row(mainAxisSize: MainAxisSize.min, children: [
                if (activeCollectionId != null) IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                  tooltip: 'Retirer de la collection',
                  onPressed: () => onRemoveFromCollection(s),
                ),
                if (mode != ContentMode.live) IconButton(
                  icon: Icon(
                    wlKeys.contains(favKeyBuilder(mode.key, s)) ? Icons.bookmark : Icons.bookmark_border,
                    color: wlKeys.contains(favKeyBuilder(mode.key, s)) ? Colors.tealAccent : Colors.white24,
                    size: 20,
                  ),
                  onPressed: () => onToggleWatchlist(s),
                  tooltip: 'À regarder plus tard',
                ),
                IconButton(
                  icon: Icon(
                    favKeys.contains(favKeyBuilder(mode.key, s)) ? Icons.star : Icons.star_border,
                    color: favKeys.contains(favKeyBuilder(mode.key, s)) ? Colors.amber : Colors.white24,
                    size: 20,
                  ),
                  onPressed: () => onToggleFavorite(s),
                ),
              ]),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              hoverColor: const Color(0xFF4A90D9).withValues(alpha: 0.15),
              selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.1),
              selected: isSelected,
              onTap: selectionMode
                  ? () => onToggleSelection(selKey)
                  : () => onPlayStream(s),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<dynamic> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.58,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final s = items[i] as Map<String, dynamic>;
        final pKey = progressKeyBuilder(s);
        final prog = pKey != null ? progress[pKey] : null;
        final isFav = favKeys.contains(favKeyBuilder(mode.key, s));
        final isWl = wlKeys.contains(favKeyBuilder(mode.key, s));
        final selKey = itemSelectionKeyBuilder(s);
        final isSelected = selectionMode && selectedItems.contains(selKey);

        return StreamGridTile(
          stream: s,
          mode: mode,
          progress: prog,
          isFav: isFav,
          isInWatchlist: isWl,
          isInCollection: activeCollectionId != null,
          selectionMode: selectionMode,
          isSelected: isSelected,
          onTap: selectionMode
              ? () => onToggleSelection(selKey)
              : () => onPlayStream(s),
          onToggleFavorite: () => onToggleFavorite(s),
          onToggleWatchlist: () => onToggleWatchlist(s),
          onRemoveFromCollection: () => onRemoveFromCollection(s),
          onSecondaryTap: (_) => onShowStreamInfo(s),
        );
      },
    );
  }
}
