import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart' as cat;
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series_item.dart';
import '../models/episode.dart';
import '../models/content_mode.dart';
import '../repositories/content_repository.dart';

/// Categories for a given content mode
final categoriesProvider = FutureProvider.family<List<cat.Category>, ContentMode>((ref, mode) async {
  final repo = ref.read(contentRepositoryProvider);
  switch (mode) {
    case ContentMode.live:
      return repo.getLiveCategories();
    case ContentMode.vod:
      return repo.getVodCategories();
    case ContentMode.series:
      return repo.getSeriesCategories();
  }
});

/// Streams/items for a given content mode and optional category ID
final liveStreamsProvider = FutureProvider.family<List<Channel>, String?>((ref, catId) async {
  return ref.read(contentRepositoryProvider).getLiveStreams(catId);
});

final vodStreamsProvider = FutureProvider.family<List<VodItem>, String?>((ref, catId) async {
  return ref.read(contentRepositoryProvider).getVodStreams(catId);
});

final seriesListProvider = FutureProvider.family<List<SeriesItem>, String?>((ref, catId) async {
  return ref.read(contentRepositoryProvider).getSeries(catId);
});

/// Series episodes by season
final seriesEpisodesProvider = FutureProvider.family<Map<String, List<Episode>>, String>((ref, seriesId) async {
  return ref.read(contentRepositoryProvider).getSeriesEpisodes(seriesId);
});

/// Authentication check
final authProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(contentRepositoryProvider).authenticate();
});
