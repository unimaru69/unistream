import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart' as cat;
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series_item.dart';
import '../models/episode.dart';
import '../models/content_mode.dart';
import '../services/xtream_api.dart';

/// Categories for a given content mode
final categoriesProvider = FutureProvider.family<List<cat.Category>, ContentMode>((ref, mode) async {
  switch (mode) {
    case ContentMode.live:
      return XtreamApi.getLiveCategoriesTyped();
    case ContentMode.vod:
      return XtreamApi.getVodCategoriesTyped();
    case ContentMode.series:
      return XtreamApi.getSeriesCategoriesTyped();
  }
});

/// Streams/items for a given content mode and optional category ID
final liveStreamsProvider = FutureProvider.family<List<Channel>, String?>((ref, catId) async {
  return XtreamApi.getLiveStreamsTyped(catId);
});

final vodStreamsProvider = FutureProvider.family<List<VodItem>, String?>((ref, catId) async {
  return XtreamApi.getVodStreamsTyped(catId);
});

final seriesListProvider = FutureProvider.family<List<SeriesItem>, String?>((ref, catId) async {
  return XtreamApi.getSeriesTyped(catId);
});

/// Series episodes by season
final seriesEpisodesProvider = FutureProvider.family<Map<String, List<Episode>>, String>((ref, seriesId) async {
  return XtreamApi.getSeriesEpisodesTyped(seriesId);
});

/// Authentication check
final authProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return XtreamApi.authenticate();
});
