import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/content_mode.dart';

/// State for paginated stream display.
class PaginatedState {
  final List<dynamic> visibleItems;
  final bool hasMore;
  final int totalCount;
  final bool isLoadingMore;

  const PaginatedState({
    this.visibleItems = const [],
    this.hasMore = false,
    this.totalCount = 0,
    this.isLoadingMore = false,
  });

  PaginatedState copyWith({
    List<dynamic>? visibleItems,
    bool? hasMore,
    int? totalCount,
    bool? isLoadingMore,
  }) {
    return PaginatedState(
      visibleItems: visibleItems ?? this.visibleItems,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Page sizes per content mode.
int pageSizeForMode(ContentMode mode) {
  switch (mode) {
    case ContentMode.live:
      return 50;
    case ContentMode.vod:
    case ContentMode.series:
      return 30;
  }
}

/// StateNotifier that wraps a full stream list and exposes pages progressively.
class PaginatedStreamsNotifier extends StateNotifier<PaginatedState> {
  PaginatedStreamsNotifier() : super(const PaginatedState());

  List<dynamic> _allItems = [];
  int _page = 0;
  int _pageSize = 50;

  /// Reset with a new full list — shows first page immediately.
  void reset(List<dynamic> items, {int? pageSize}) {
    _allItems = items;
    _page = 0;
    _pageSize = pageSize ?? _pageSize;

    final end = _pageSize.clamp(0, _allItems.length);
    final visible = _allItems.sublist(0, end);
    _page = 1;

    state = PaginatedState(
      visibleItems: visible,
      hasMore: end < _allItems.length,
      totalCount: _allItems.length,
      isLoadingMore: false,
    );
  }

  /// Append the next page from the full list.
  void loadMore() {
    if (!state.hasMore || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);

    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, _allItems.length);

    if (start >= _allItems.length) {
      state = state.copyWith(hasMore: false, isLoadingMore: false);
      return;
    }

    final nextBatch = _allItems.sublist(start, end);
    final newVisible = [...state.visibleItems, ...nextBatch];
    _page++;

    state = PaginatedState(
      visibleItems: newVisible,
      hasMore: end < _allItems.length,
      totalCount: _allItems.length,
      isLoadingMore: false,
    );
  }
}

/// Global provider for paginated streams.
///
/// `autoDispose` so the visible-items list (which can hold the
/// full N-page accumulator, easily 10–30k items on a large catalogue)
/// is freed when the user leaves the home grid. Before this, the
/// state lived until session end even after the user moved to
/// Settings / a detail screen / another segment that doesn't use
/// pagination.
final paginatedStreamsProvider = StateNotifierProvider.autoDispose<
    PaginatedStreamsNotifier, PaginatedState>(
  (ref) => PaginatedStreamsNotifier(),
);
