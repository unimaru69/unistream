import '../models/category.dart' as cat;
import '../models/channel.dart';
import '../models/episode.dart';
import '../models/server_info.dart';
import '../models/series_item.dart';
import '../models/vod_item.dart';
import '../repositories/content_repository.dart';
import 'demo_data.dart';

/// Fake content repository used in demo mode. Returns hardcoded sample data
/// so the app can run for screenshots and App Store review without a real
/// IPTV subscription.
class DemoContentRepository extends ContentRepository {
  @override
  Future<Map<String, dynamic>> authenticate() async => {
        'user_info': {
          'username': 'demo',
          'password': 'demo',
          'auth': 1,
          'status': 'Active',
          'exp_date': '9999999999',
          'is_trial': '0',
          'active_cons': '1',
          'created_at': '1700000000',
          'max_connections': '1',
          'allowed_output_formats': ['m3u8', 'ts', 'rtmp'],
        },
        'server_info': {
          'url': 'demo.unimaru.fr',
          'port': '443',
          'https_port': '443',
          'server_protocol': 'https',
          'rtmp_port': '',
          'timezone': 'Europe/Paris',
          'time_now': DateTime.now().toIso8601String(),
        },
      };

  @override
  Future<ServerInfo> authenticateTyped() async {
    final json = await authenticate();
    return ServerInfo.fromJson(json['server_info'] as Map<String, dynamic>);
  }

  @override
  void loadServerTimezone() {}

  // ── Categories ──

  @override
  Future<List<cat.Category>> getLiveCategories() async => DemoData.liveCategories;

  @override
  Future<List<cat.Category>> getVodCategories() async => DemoData.vodCategories;

  @override
  Future<List<cat.Category>> getSeriesCategories() async => DemoData.seriesCategories;

  // ── Streams ──

  @override
  Future<List<Channel>> getLiveStreams([String? categoryId]) async {
    if (categoryId == null) return DemoData.liveChannels;
    return DemoData.liveChannels.where((c) => c.categoryId == categoryId).toList();
  }

  @override
  Future<List<VodItem>> getVodStreams([String? categoryId]) async {
    if (categoryId == null) return DemoData.vodItems;
    return DemoData.vodItems.where((v) => v.categoryId == categoryId).toList();
  }

  @override
  Future<List<SeriesItem>> getSeries([String? categoryId]) async {
    if (categoryId == null) return DemoData.seriesList;
    return DemoData.seriesList.where((s) => s.categoryId == categoryId).toList();
  }

  @override
  Future<Map<String, List<Episode>>> getSeriesEpisodes(String seriesId) async =>
      DemoData.episodesFor(seriesId);

  // ── EPG ──

  @override
  Future<Map<String, dynamic>> getShortEpg(String streamId, {int limit = 8}) async =>
      DemoData.shortEpgFor(streamId, limit: limit);

  @override
  Future<Map<String, dynamic>> getFullDayEpg(String streamId) async =>
      DemoData.fullDayEpgFor(streamId);

  @override
  String? getCachedEpgNow(String streamId) {
    final listings = DemoData.shortEpgFor(streamId, limit: 2)['epg_listings'] as List;
    if (listings.isEmpty) return null;
    // Return the first program title (raw base64 would need decoding upstream)
    return null; // Don't populate cache in demo
  }

  // ── Stream URLs ──
  // Use a short public demo video for all streams.

  static const _demoUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  String getLiveStreamUrl(String id) => _demoUrl;

  @override
  String getVodStreamUrl(String id, String ext) => _demoUrl;

  @override
  String getSeriesEpisodeUrl(String id, String ext) => _demoUrl;

  @override
  String getTimeshiftUrl(String streamId, DateTime startUtc, int durationMin) => _demoUrl;

  @override
  String getTimeshiftUrlFromLocal(
          String streamId, String serverLocalStart, int durationMin) =>
      _demoUrl;
}
