import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../../models/content_mode.dart';
import '../../../models/channel.dart';
import '../../../models/vod_item.dart';
import '../../../models/series_item.dart';
import '../../../services/xtream_api.dart';
import '../../../widgets/skeleton_list.dart';
import 'stream_tile.dart';

/// Main stream content area: search bar, selection bar, list/grid view.
class StreamListView extends StatefulWidget {
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
  final void Function(dynamic stream) onPlayStream;
  final void Function(dynamic stream) onToggleFavorite;
  final void Function(dynamic stream) onToggleWatchlist;
  final void Function(dynamic stream) onShowStreamInfo;
  final void Function(dynamic stream) onRemoveFromCollection;
  final String Function(String modeKey, dynamic stream) favKeyBuilder;
  final String Function(dynamic stream) itemSelectionKeyBuilder;
  final String? Function(dynamic stream) progressKeyBuilder;
  final Future<void> Function()? onRefresh;

  // Pagination
  final bool hasMore;
  final int totalCount;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;

  /// Optional widget inserted at the very top of the scroll view — scrolls away
  /// with the content, so the grid / list gradually fills the whole viewport.
  /// Used by home_screen to show the hero banner + continue watching + recently
  /// added rows without eating fixed vertical space.
  final Widget? headerChild;

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
    this.onRefresh,
    this.hasMore = false,
    this.totalCount = 0,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.headerChild,
  });

  @override
  State<StreamListView> createState() => _StreamListViewState();

  // ── Typed stream helpers ──
  static String getName(dynamic s) {
    if (s is Channel) return s.name;
    if (s is VodItem) return s.name;
    if (s is SeriesItem) return s.name;
    if (s is Map<String, dynamic>) return s['name']?.toString() ?? '';
    return '';
  }

  static String getStreamId(dynamic s) {
    if (s is Channel) return s.streamId.toString();
    if (s is VodItem) return s.streamId.toString();
    if (s is SeriesItem) return s.seriesId.toString();
    if (s is Map<String, dynamic>) return (s['series_id'] ?? s['stream_id'])?.toString() ?? '';
    return '';
  }
}

class _StreamListViewState extends State<StreamListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (widget.selectedCategory == null) {
      return Center(child: Text(l10n.selectionneCategorie,
          style: TextStyle(color: tc.textDisabled, fontSize: 16)));
    }
    if (widget.loadingStreams) {
      return SkeletonList(count: widget.showGrid ? 16 : 12, isGrid: widget.showGrid);
    }

    return Column(children: [
      // Selection bar stays above the scroll view — it's modal UI.
      if (widget.selectionMode) _buildSelectionBar(l10n),
      Expanded(child: Builder(builder: (ctx) {
        final filtered = widget.searchQuery.isEmpty
            ? widget.sortedStreams
            : widget.sortedStreams.where((s) => StreamListView.getName(s)
                .toLowerCase().contains(widget.searchQuery)).toList();
        // Single CustomScrollView so the optional [headerChild] scrolls away
        // along with the list/grid (vs being fixed above and squashing it).
        // The search bar + count indicator are now INSIDE the scroll view,
        // right after the hero, so they slide away with the rest of the
        // header instead of sitting fixed below the app bar.
        final searchBarChild = widget.selectionMode
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: _buildSearchBar(l10n),
              );
        final countIndicator = (widget.totalCount > 0 &&
                widget.sortedStreams.isNotEmpty)
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${widget.sortedStreams.length} / ${_formatNumber(widget.totalCount)}',
                    style: TextStyle(fontSize: 11, color: tc.textDisabled),
                  ),
                ),
              )
            : null;
        final slivers = <Widget>[
          if (widget.headerChild != null)
            SliverToBoxAdapter(child: widget.headerChild!),
          if (searchBarChild != null)
            SliverToBoxAdapter(child: searchBarChild),
          if (countIndicator != null)
            SliverToBoxAdapter(child: countIndicator),
          if (widget.showGrid)
            _buildGridSliver(filtered)
          else
            _buildListSliver(filtered, l10n),
        ];
        final child = CustomScrollView(
          controller: _scrollController,
          slivers: slivers,
        );
        if (widget.onRefresh != null) {
          return RefreshIndicator(onRefresh: widget.onRefresh!, child: child);
        }
        return child;
      })),
    ]);
  }

  static String _formatNumber(int n) {
    if (n < 1000) return n.toString();
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _buildSelectionBar(AppLocalizations l10n) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(children: [
        Text(l10n.xSelectionnes(widget.selectedItems.length),
            style: TextStyle(fontSize: 13, color: tc.textSecondary)),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.select_all, size: 16),
          label: Text(l10n.tout, style: const TextStyle(fontSize: 12)),
          onPressed: widget.onSelectAll,
        ),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: AppColors.primaryBlue),
          label: Text(l10n.creerCollection, style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
          onPressed: widget.selectedItems.isEmpty ? null : widget.onCreateCollectionFromSelected,
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.close, size: 18, color: tc.textTertiary),
          tooltip: l10n.annulerSelection,
          onPressed: widget.onExitSelectionMode,
        ),
      ]),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    final tc = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Expanded(child: TextField(
          controller: widget.searchCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: l10n.rechercherDots,
            hintStyle: TextStyle(color: tc.textDisabled),
            prefixIcon: Icon(Icons.search, color: tc.textDisabled, size: 20),
            suffixIcon: widget.searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: tc.textDisabled, size: 18),
                    onPressed: widget.onClearSearch,
                  )
                : null,
            isDense: true, filled: true, fillColor: tc.inputFill,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onChanged: widget.onSearchChanged,
        )),
        if (widget.selectedCategory == '__favorites__' || widget.selectedCategory == '__watchlist__')
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Tooltip(
              message: l10n.selectionnerPourCollection,
              child: IconButton(
                icon: const Icon(Icons.checklist, size: 20, color: AppColors.primaryBlue),
                onPressed: widget.sortedStreams.isEmpty ? null : widget.onEnterSelectionMode,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildListSliver(List<dynamic> items, AppLocalizations l10n) {
    final tc = AppThemeColors.of(context);
    final itemCount = widget.hasMore ? items.length + 1 : items.length;
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList.builder(
        itemCount: itemCount,
        itemBuilder: (_, i) {
        // Loading indicator at the bottom
        if (i >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final s = items[i];
        final pKey = widget.progressKeyBuilder(s);
        final prog = pKey != null ? widget.progress[pKey] : null;
        // For live channels, show cached current program as subtitle
        String? liveEpgTitle;
        if (widget.mode == ContentMode.live) {
          final sid = StreamListView.getStreamId(s);
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
                    backgroundColor: tc.divider,
                    color: Colors.amber,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          );
        }
        final selKey = widget.itemSelectionKeyBuilder(s);
        final isSelected = widget.selectionMode && widget.selectedItems.contains(selKey);
        final streamName = StreamListView.getName(s);
        final sid = StreamListView.getStreamId(s);
        return Padding(
          key: ValueKey('list_$sid'),
          padding: const EdgeInsets.only(bottom: 4),
          child: GestureDetector(
            onSecondaryTapUp: widget.selectionMode ? null : (_) => widget.onShowStreamInfo(s),
            child: ListTile(
              leading: widget.selectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => widget.onToggleSelection(selKey),
                      activeColor: AppColors.primaryBlue,
                    )
                  : listIconTyped(s, widget.mode, context),
              title: Text(streamName.isEmpty ? l10n.sansTitre : streamName,
                  style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
              subtitle: subtitle,
              trailing: widget.selectionMode ? null : Row(mainAxisSize: MainAxisSize.min, children: [
                if (widget.mode == ContentMode.live && streamHasCatchup(s))
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.accentGreen.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Replay', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (widget.activeCollectionId != null) IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                  tooltip: l10n.retirerCollection,
                  onPressed: () => widget.onRemoveFromCollection(s),
                ),
                if (widget.mode != ContentMode.live) IconButton(
                  icon: Icon(
                    widget.wlKeys.contains(widget.favKeyBuilder(widget.mode.key, s)) ? Icons.bookmark : Icons.bookmark_border,
                    color: widget.wlKeys.contains(widget.favKeyBuilder(widget.mode.key, s)) ? Colors.tealAccent : tc.borderColor,
                    size: 20,
                  ),
                  onPressed: () => widget.onToggleWatchlist(s),
                  tooltip: l10n.aRegarderPlusTard,
                ),
                IconButton(
                  icon: Icon(
                    widget.favKeys.contains(widget.favKeyBuilder(widget.mode.key, s)) ? Icons.star : Icons.star_border,
                    color: widget.favKeys.contains(widget.favKeyBuilder(widget.mode.key, s)) ? Colors.amber : tc.borderColor,
                    size: 20,
                  ),
                  onPressed: () => widget.onToggleFavorite(s),
                ),
              ]),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              hoverColor: AppColors.primaryBlue.withValues(alpha: 0.15),
              selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.1),
              selected: isSelected,
              onTap: widget.selectionMode
                  ? () => widget.onToggleSelection(selKey)
                  : () => widget.onPlayStream(s),
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildGridSliver(List<dynamic> items) {
    // We need a LayoutBuilder-equivalent inside a sliver — use
    // SliverLayoutBuilder so the responsive crossAxisCount still works.
    return SliverLayoutBuilder(builder: (context, constraints) {
      // Live channel logos look best in short, dense tiles (logo + name +
      // current program). Posters for films/series stay tall (2:3 ratio).
      final isLive = widget.mode == ContentMode.live;
      final int targetTileWidth = isLive ? 140 : 200;
      // Live tiles almost square so logos aren't lost in a tall column.
      final double aspect = isLive ? 1.0 : 0.58;
      final int maxColumns = isLive ? 12 : 6;
      final int crossAxisCount =
          (constraints.crossAxisExtent / targetTileWidth).floor().clamp(2, maxColumns);
      final itemCount = widget.hasMore ? items.length + 1 : items.length;
      return SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: aspect,
          ),
          itemCount: itemCount,
          itemBuilder: (_, i) {
        if (i >= items.length) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final s = items[i];
        final pKey = widget.progressKeyBuilder(s);
        final prog = pKey != null ? widget.progress[pKey] : null;
        final isFav = widget.favKeys.contains(widget.favKeyBuilder(widget.mode.key, s));
        final isWl = widget.wlKeys.contains(widget.favKeyBuilder(widget.mode.key, s));
        final selKey = widget.itemSelectionKeyBuilder(s);
        final isSelected = widget.selectionMode && widget.selectedItems.contains(selKey);

        // Live tiles: surface the cached "now playing" program underneath
        // the channel name so the grid carries as much info as tvOS cards.
        String? liveNow;
        if (widget.mode == ContentMode.live) {
          final sid = StreamListView.getStreamId(s);
          if (sid.isNotEmpty) liveNow = XtreamApi.getCachedEpgNow(sid);
        }

        return StreamGridTile(
          key: ValueKey('grid_${StreamListView.getStreamId(s)}'),
          stream: s,
          mode: widget.mode,
          progress: prog,
          isFav: isFav,
          isInWatchlist: isWl,
          isInCollection: widget.activeCollectionId != null,
          selectionMode: widget.selectionMode,
          isSelected: isSelected,
          onTap: widget.selectionMode
              ? () => widget.onToggleSelection(selKey)
              : () => widget.onPlayStream(s),
          onToggleFavorite: () => widget.onToggleFavorite(s),
          onToggleWatchlist: () => widget.onToggleWatchlist(s),
          onRemoveFromCollection: () => widget.onRemoveFromCollection(s),
          onSecondaryTap: (_) => widget.onShowStreamInfo(s),
          subtitle: liveNow,
        );
      },
        ),
      );
    });
  }
}
