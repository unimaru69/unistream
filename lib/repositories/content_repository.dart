import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../demo/demo_content_repository.dart';
import '../models/category.dart' as cat;
import '../models/channel.dart';
import '../models/episode.dart';
import '../models/server_info.dart';
import '../models/series_item.dart';
import '../models/vod_item.dart';
import '../services/xtream_api.dart';

/// Global flag: when true the app uses [DemoContentRepository] with fake data
/// for screenshots and App Store review. Activate with --dart-define=DEMO=true
const bool kDemoMode = bool.fromEnvironment('DEMO', defaultValue: false);

/// When in demo mode, which screen to land on. Values: home, vod, series, epg, settings, player.
/// Activate with --dart-define=SCREEN=vod
const String kDemoScreen = String.fromEnvironment('SCREEN', defaultValue: 'home');

/// Force landscape orientation in demo mode. Activate with --dart-define=LANDSCAPE=true
const bool kDemoLandscape = bool.fromEnvironment('LANDSCAPE', defaultValue: false);

/// Force UI locale in demo mode. Activate with --dart-define=LOCALE=en
const String kDemoLocale = String.fromEnvironment('LOCALE', defaultValue: '');

/// Centralizes all Xtream API data access.
///
/// Screens and providers should go through this repository instead of calling
/// [XtreamApi] directly. This decouples the UI from the data source and makes
/// it easy to add caching, offline support, or swap backends later.
class ContentRepository {
  // ── Authentication ──

  Future<Map<String, dynamic>> authenticate() => XtreamApi.authenticate();

  Future<ServerInfo> authenticateTyped() => XtreamApi.authenticateTyped();

  void loadServerTimezone() => XtreamApi.loadServerTimezone();

  // ── Categories ──

  Future<List<cat.Category>> getLiveCategories() =>
      XtreamApi.getLiveCategoriesTyped();

  Future<List<cat.Category>> getVodCategories() =>
      XtreamApi.getVodCategoriesTyped();

  Future<List<cat.Category>> getSeriesCategories() =>
      XtreamApi.getSeriesCategoriesTyped();

  // ── Streams ──

  /// [force] bypasses the 5-minute stream cache — see
  /// [XtreamApi.getLiveStreams].
  Future<List<Channel>> getLiveStreams([String? categoryId, bool force = false]) =>
      XtreamApi.getLiveStreamsTyped(categoryId, force);

  Future<List<VodItem>> getVodStreams([String? categoryId, bool force = false]) =>
      XtreamApi.getVodStreamsTyped(categoryId, force);

  /// Recently-added VOD + series, reduced inside a worker isolate — the
  /// Home screen must never materialise the full catalog (memory spike
  /// killed the app on 1 GB Android TV boxes).
  Future<List<dynamic>> getRecentCatalog({int max = 60}) =>
      XtreamApi.getRecentCatalog(max: max);

  /// Catch-up-capable channels only, filtered inside a worker isolate.
  Future<List<Channel>> getCatchupChannels({int max = 15}) =>
      XtreamApi.getCatchupChannels(max: max);

  Future<List<SeriesItem>> getSeries([String? categoryId, bool force = false]) =>
      XtreamApi.getSeriesTyped(categoryId, force);

  Future<Map<String, List<Episode>>> getSeriesEpisodes(String seriesId) =>
      XtreamApi.getSeriesEpisodesTyped(seriesId);

  // ── EPG ──

  Future<Map<String, dynamic>> getShortEpg(String streamId, {int limit = 8}) =>
      XtreamApi.getShortEpg(streamId, limit: limit);

  Future<Map<String, dynamic>> getFullDayEpg(String streamId) =>
      XtreamApi.getFullDayEpg(streamId);

  String? getCachedEpgNow(String streamId) =>
      XtreamApi.getCachedEpgNow(streamId);

  // ── Stream URLs ──

  String getLiveStreamUrl(String id) => XtreamApi.getLiveStreamUrl(id);

  String getVodStreamUrl(String id, String ext) =>
      XtreamApi.getVodStreamUrl(id, ext);

  String getSeriesEpisodeUrl(String id, String ext) =>
      XtreamApi.getSeriesEpisodeUrl(id, ext);

  String getTimeshiftUrl(String streamId, DateTime startUtc, int durationMin) =>
      XtreamApi.getTimeshiftUrl(streamId, startUtc, durationMin);

  String getTimeshiftUrlFromLocal(
          String streamId, String serverLocalStart, int durationMin) =>
      XtreamApi.getTimeshiftUrlFromLocal(
          streamId, serverLocalStart, durationMin);

  // ── Cache management ──

  int get epgCacheSize => XtreamApi.epgCacheSize;

  /// Drop the in-memory catalogue cache so the next fetch goes back to
  /// the panel. Used by the catalogue refresh.
  void clearStreamCache() => XtreamApi.clearStreamCache();

  Future<void> clearAllEpgCache() => XtreamApi.clearAllEpgCache();

  void loadEpgCacheFromDisk() => XtreamApi.loadEpgCacheFromDisk();

  Future<void> loadRetryConfig() => XtreamApi.loadRetryConfig();

  // ── Utilities ──

  bool channelHasCatchup(Map<String, dynamic> channel) =>
      XtreamApi.channelHasCatchup(channel);

  int channelArchiveDays(Map<String, dynamic> channel) =>
      XtreamApi.channelArchiveDays(channel);

  ApiErrorKey errorKey(Object error) => XtreamApi.errorKey(error);

  String friendlyError(Object error) => XtreamApi.friendlyError(error);
}

/// Riverpod provider for [ContentRepository].
final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return kDemoMode ? DemoContentRepository() : ContentRepository();
});
