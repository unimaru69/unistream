import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/logger.dart';
import 'package:unistream/core/storage_keys.dart';
import '../models/app_config.dart';
import '../models/category.dart' as cat;
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series_item.dart';
import '../models/episode.dart';
import '../models/server_info.dart';

// ── Network helpers ──
const _defaultBaseDelay = Duration(seconds: 1);
const _defaultMaxDelay = Duration(seconds: 10);
const _defaultMaxJitterMs = 500;

// ── Configurable retry defaults (loaded from SharedPreferences) ──
int _configMaxRetries = 3;
int _configTimeoutSec = 15;

Future<void> _loadRetryConfig() async {
  final p = await SharedPreferences.getInstance();
  _configMaxRetries = p.getInt(StorageKeys.retryMaxAttempts) ?? 3;
  _configTimeoutSec = p.getInt(StorageKeys.retryTimeoutSec) ?? 15;
}

/// Visible for testing — override to control jitter in tests.
@visibleForTesting
Random httpGetRandom = Random();

/// Visible for testing — override to inject a mock HTTP client globally.
@visibleForTesting
http.Client? httpGetTestClient;

Future<http.Response> httpGet(
  String url, {
  http.Client? client,
  int? maxRetries,
  Duration? timeout,
  void Function(int attempt, dynamic error)? onRetry,
}) async {
  final effectiveMaxRetries = maxRetries ?? _configMaxRetries;
  final effectiveTimeout = timeout ?? Duration(seconds: _configTimeoutSec);
  final effectiveClient = client ?? httpGetTestClient ?? http.Client();
  final shouldCloseClient = client == null && httpGetTestClient == null;
  try {
    for (int i = 0; i < effectiveMaxRetries; i++) {
      try {
        return await effectiveClient
            .get(Uri.parse(url))
            .timeout(effectiveTimeout);
      } on TimeoutException catch (e) {
        if (i == effectiveMaxRetries - 1) rethrow;
        onRetry?.call(i, e);
      } on SocketException catch (e) {
        if (i == effectiveMaxRetries - 1) rethrow;
        onRetry?.call(i, e);
      } on HandshakeException catch (e) {
        if (i == effectiveMaxRetries - 1) rethrow;
        onRetry?.call(i, e);
      } on http.ClientException catch (e) {
        if (i == effectiveMaxRetries - 1) rethrow;
        onRetry?.call(i, e);
      }
      // Exponential backoff with jitter:
      // min(baseDelay * 2^attempt + random_jitter, maxDelay)
      final exponentialMs =
          _defaultBaseDelay.inMilliseconds * (1 << i); // 2^i
      final jitterMs = httpGetRandom.nextInt(_defaultMaxJitterMs + 1);
      final delayMs =
          min(exponentialMs + jitterMs, _defaultMaxDelay.inMilliseconds);
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    throw Exception('Retry limit reached after $effectiveMaxRetries attempts');
  } finally {
    if (shouldCloseClient) effectiveClient.close();
  }
}

// ── API Error Keys ──
enum ApiErrorKey { network, timeout, client, format, auth, generic }

// ── EPG Cache ──
class EpgCacheEntry {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  EpgCacheEntry(this.data, this.timestamp);
}

// ── Stream List Cache ──
class _StreamCacheEntry {
  final List<dynamic> data;
  final DateTime timestamp;
  _StreamCacheEntry(this.data, this.timestamp);
}

// ── API Xtream Codes ──
class XtreamApi {
  /// Load retry configuration from SharedPreferences.
  static Future<void> loadRetryConfig() => _loadRetryConfig();

  /// Map a technical error to an [ApiErrorKey] for localization at the UI layer.
  static ApiErrorKey errorKey(dynamic error) {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
      return ApiErrorKey.network;
    }
    if (msg.contains('TimeoutException')) {
      return ApiErrorKey.timeout;
    }
    if (msg.contains('ClientException')) {
      return ApiErrorKey.client;
    }
    if (msg.contains('FormatException')) {
      return ApiErrorKey.format;
    }
    if (msg.contains('401') || msg.contains('auth')) {
      return ApiErrorKey.auth;
    }
    return ApiErrorKey.generic;
  }

  /// Legacy helper — kept for backward compat, delegates to [errorKey].
  @Deprecated('Use errorKey() + localizeApiError() instead')
  static String friendlyError(dynamic error) {
    // Fallback French — only used if localization context unavailable
    switch (errorKey(error)) {
      case ApiErrorKey.network: return 'Connexion impossible.';
      case ApiErrorKey.timeout: return 'Le serveur ne répond pas.';
      case ApiErrorKey.client: return 'Erreur de communication.';
      case ApiErrorKey.format: return 'Réponse invalide du serveur.';
      case ApiErrorKey.auth: return 'Identifiants incorrects.';
      case ApiErrorKey.generic: return 'Une erreur est survenue.';
    }
  }

  static final Map<String, EpgCacheEntry> _epgCache = {};
  static const Duration _epgCacheTtl = Duration(minutes: 30);
  static const int _epgCacheMaxSize = 500;

  static int get epgCacheSize => _epgCache.length;
  static void clearEpgCache() => _epgCache.clear();

  /// Clear both in-memory and persisted EPG cache.
  static Future<void> clearAllEpgCache() async {
    _epgCache.clear();
    _epgSaveTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.epgCache(AppConfig.activeProfileId));
    } catch (e) {
      AppLogger.debug(LogModule.epg, 'EPG cache clear from disk failed: $e');
    }
  }

  static Timer? _epgSaveTimer;

  /// Load persisted EPG cache from disk (SharedPreferences).
  /// Call once at startup, after AppConfig is initialized.
  static Future<void> loadEpgCacheFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageKeys.epgCache(AppConfig.activeProfileId));
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now();
      for (final entry in decoded.entries) {
        final ts = DateTime.tryParse(entry.value['ts'] as String? ?? '');
        if (ts == null || now.difference(ts) >= _epgCacheTtl) continue;
        final data = Map<String, dynamic>.from(entry.value['data'] as Map);
        _epgCache[entry.key] = EpgCacheEntry(data, ts);
      }
      AppLogger.info(LogModule.epg, 'Loaded ${_epgCache.length} EPG entries from disk');
    } catch (e, st) {
      AppLogger.warning(LogModule.epg, 'Failed to load EPG cache from disk', error: e, stackTrace: st);
    }
  }

  /// Persist EPG cache to disk (debounced, called after each cache update).
  static void _scheduleEpgSave() {
    _epgSaveTimer?.cancel();
    _epgSaveTimer = Timer(const Duration(seconds: 2), _saveEpgCacheToDisk);
  }

  static Future<void> _saveEpgCacheToDisk() async {
    try {
      final serialized = <String, dynamic>{};
      for (final entry in _epgCache.entries) {
        serialized[entry.key] = {
          'data': entry.value.data,
          'ts': entry.value.timestamp.toIso8601String(),
        };
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.epgCache(AppConfig.activeProfileId), jsonEncode(serialized));
    } catch (e, st) {
      AppLogger.warning(LogModule.epg, 'Failed to save EPG cache to disk', error: e, stackTrace: st);
    }
  }

  /// Evict expired entries and trim to max size (oldest first).
  static void _evictEpgCache() {
    final now = DateTime.now();
    _epgCache.removeWhere((_, e) => now.difference(e.timestamp) >= _epgCacheTtl);
    if (_epgCache.length > _epgCacheMaxSize) {
      final sorted = _epgCache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
      final toRemove = sorted.take(_epgCache.length - _epgCacheMaxSize);
      for (final e in toRemove) {
        _epgCache.remove(e.key);
      }
    }
  }

  // ── Stream list cache (action+categoryId -> list, TTL 5 min) ──
  static final Map<String, _StreamCacheEntry> _streamCache = {};
  static const Duration _streamCacheTtl = Duration(minutes: 5);
  static const int _streamCacheMaxSize = 100;

  /// Visible for testing — allows overriding the clock.
  @visibleForTesting
  static DateTime Function() streamCacheNow = () => DateTime.now();

  static int get streamCacheSize => _streamCache.length;
  static void clearStreamCache() => _streamCache.clear();

  static List<dynamic>? _getStreamCached(String key) {
    final entry = _streamCache[key];
    if (entry == null) return null;
    if (streamCacheNow().difference(entry.timestamp) >= _streamCacheTtl) {
      _streamCache.remove(key);
      return null;
    }
    return entry.data;
  }

  static void _putStreamCache(String key, List<dynamic> data) {
    _streamCache[key] = _StreamCacheEntry(data, streamCacheNow());
    if (_streamCache.length > _streamCacheMaxSize) {
      final now = streamCacheNow();
      _streamCache.removeWhere((_, e) => now.difference(e.timestamp) >= _streamCacheTtl);
      if (_streamCache.length > _streamCacheMaxSize) {
        final sorted = _streamCache.entries.toList()
          ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
        for (final e in sorted.take(_streamCache.length - _streamCacheMaxSize)) {
          _streamCache.remove(e.key);
        }
      }
    }
  }

  static String get baseUrl =>
      '${AppConfig.serverUrl}/player_api.php?username=${AppConfig.username}&password=${AppConfig.password}';

  static Future<Map<String, dynamic>> authenticate() async {
    AppLogger.breadcrumb('api', 'authenticate');
    final r = await httpGet(baseUrl);
    return jsonDecode(r.body);
  }

  static Future<ServerInfo> authenticateTyped() async {
    final data = await authenticate();
    return ServerInfo.fromJson(data);
  }

  static Future<List<dynamic>> getLiveCategories() async =>
      jsonDecode((await httpGet('$baseUrl&action=get_live_categories')).body);

  static Future<List<cat.Category>> getLiveCategoriesTyped() async {
    final list = await getLiveCategories();
    return list.map((e) => cat.Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<dynamic>> getLiveStreams([String? catId]) async {
    AppLogger.breadcrumb('api', 'getLiveStreams', data: {'categoryId': catId});
    final cacheKey = 'get_live_streams:${catId ?? ''}';
    final cached = _getStreamCached(cacheKey);
    if (cached != null) return cached;
    var url = '$baseUrl&action=get_live_streams';
    if (catId != null) url += '&category_id=$catId';
    final result = jsonDecode((await httpGet(url)).body) as List<dynamic>;
    _putStreamCache(cacheKey, result);
    return result;
  }

  static Future<List<Channel>> getLiveStreamsTyped([String? catId]) async {
    final list = await getLiveStreams(catId);
    return list.map((e) => Channel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<dynamic>> getVodCategories() async =>
      jsonDecode((await httpGet('$baseUrl&action=get_vod_categories')).body);

  static Future<List<cat.Category>> getVodCategoriesTyped() async {
    final list = await getVodCategories();
    return list.map((e) => cat.Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<dynamic>> getVodStreams([String? catId]) async {
    final cacheKey = 'get_vod_streams:${catId ?? ''}';
    final cached = _getStreamCached(cacheKey);
    if (cached != null) return cached;
    var url = '$baseUrl&action=get_vod_streams';
    if (catId != null) url += '&category_id=$catId';
    final result = jsonDecode((await httpGet(url)).body) as List<dynamic>;
    _putStreamCache(cacheKey, result);
    return result;
  }

  static Future<List<VodItem>> getVodStreamsTyped([String? catId]) async {
    final list = await getVodStreams(catId);
    return list.map((e) => VodItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<dynamic>> getSeriesCategories() async =>
      jsonDecode((await httpGet('$baseUrl&action=get_series_categories')).body);

  static Future<List<cat.Category>> getSeriesCategoriesTyped() async {
    final list = await getSeriesCategories();
    return list.map((e) => cat.Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<dynamic>> getSeries([String? catId]) async {
    final cacheKey = 'get_series:${catId ?? ''}';
    final cached = _getStreamCached(cacheKey);
    if (cached != null) return cached;
    var url = '$baseUrl&action=get_series';
    if (catId != null) url += '&category_id=$catId';
    final result = jsonDecode((await httpGet(url)).body) as List<dynamic>;
    _putStreamCache(cacheKey, result);
    return result;
  }

  static Future<List<SeriesItem>> getSeriesTyped([String? catId]) async {
    final list = await getSeries(catId);
    return list.map((e) => SeriesItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async =>
      jsonDecode((await httpGet('$baseUrl&action=get_series_info&series_id=$seriesId')).body);

  static Future<Map<String, List<Episode>>> getSeriesEpisodesTyped(String seriesId) async {
    final data = await getSeriesInfo(seriesId);
    final episodes = data['episodes'] as Map<String, dynamic>? ?? {};
    return episodes.map((season, epList) {
      final list = (epList as List<dynamic>)
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList();
      return MapEntry(season, list);
    });
  }

  static Future<Map<String, dynamic>> getShortEpg(String streamId, {int limit = 8}) async {
    final key = 'short_epg_${streamId}_$limit';
    final cached = _epgCache[key];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _epgCacheTtl) {
      return cached.data;
    }
    final data = jsonDecode((await httpGet('$baseUrl&action=get_short_epg&stream_id=$streamId&limit=$limit')).body) as Map<String, dynamic>;
    _epgCache[key] = EpgCacheEntry(data, DateTime.now());
    if (_epgCache.length > _epgCacheMaxSize) _evictEpgCache();
    _scheduleEpgSave();
    return data;
  }

  /// Full-day EPG (past + current + future) via get_simple_data_table
  static Future<Map<String, dynamic>> getFullDayEpg(String streamId) async {
    final key = 'full_epg_$streamId';
    final cached = _epgCache[key];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _epgCacheTtl) {
      return cached.data;
    }
    final data = jsonDecode((await httpGet('$baseUrl&action=get_simple_data_table&stream_id=$streamId')).body) as Map<String, dynamic>;
    _epgCache[key] = EpgCacheEntry(data, DateTime.now());
    if (_epgCache.length > _epgCacheMaxSize) _evictEpgCache();
    _scheduleEpgSave();
    return data;
  }

  /// Returns the current EPG program title from cache, or null if not cached.
  static String? getCachedEpgNow(String streamId) {
    // Check short EPG caches first
    for (final limit in [2, 8, 30]) {
      final key = 'short_epg_${streamId}_$limit';
      final cached = _epgCache[key];
      if (cached != null && DateTime.now().difference(cached.timestamp) < _epgCacheTtl) {
        final result = _findCurrentProgram(cached.data);
        if (result != null) return result;
      }
    }
    // Check full day EPG cache
    final fullKey = 'full_epg_$streamId';
    final fullCached = _epgCache[fullKey];
    if (fullCached != null && DateTime.now().difference(fullCached.timestamp) < _epgCacheTtl) {
      final result = _findCurrentProgram(fullCached.data);
      if (result != null) return result;
    }
    return null;
  }

  static String? _findCurrentProgram(Map<String, dynamic> epgData) {
    final listings = epgData['epg_listings'] as List<dynamic>?;
    if (listings == null || listings.isEmpty) return null;
    final now = DateTime.now();
    for (final item in listings) {
      final startStr = item['start'] as String?;
      final endStr = item['end'] as String?;
      if (startStr == null || endStr == null) continue;
      try {
        final start = DateTime.parse(startStr);
        final end = DateTime.parse(endStr);
        if (now.isAfter(start) && now.isBefore(end)) {
          final title = item['title'] as String?;
          if (title != null && title.isNotEmpty) {
            // Title may be base64 encoded
            try {
              return utf8.decode(base64Decode(title));
            } catch (e, st) {
              AppLogger.warning(LogModule.epg, 'Failed to decode base64 EPG title', error: e, stackTrace: st);
              return title;
            }
          }
        }
      } catch (e, st) { AppLogger.warning(LogModule.epg, 'Failed to parse EPG listing timestamps', error: e, stackTrace: st); continue; }
    }
    return null;
  }

  static String getLiveStreamUrl(String id) =>
      '${AppConfig.serverUrl}/live/${AppConfig.username}/${AppConfig.password}/$id.m3u8';

  static String getVodStreamUrl(String id, String ext) =>
      '${AppConfig.serverUrl}/movie/${AppConfig.username}/${AppConfig.password}/$id.$ext';

  static String getSeriesEpisodeUrl(String id, String ext) =>
      '${AppConfig.serverUrl}/series/${AppConfig.username}/${AppConfig.password}/$id.$ext';

  // ── Catch-up / Timeshift ──

  /// Server UTC offset in hours, loaded from server_info.timezone at auth
  static Duration _serverUtcOffset = Duration.zero;
  static bool _serverTimezoneLoaded = false;

  /// Load server timezone offset from auth response.
  static Future<void> loadServerTimezone() async {
    if (_serverTimezoneLoaded) return;
    try {
      final info = await authenticate();
      final serverInfo = info['server_info'] as Map<String, dynamic>?;
      if (serverInfo != null) {
        final timeNowStr = serverInfo['time_now']?.toString();
        final serverTs = int.tryParse(serverInfo['timestamp_now']?.toString() ?? '');
        if (timeNowStr != null && serverTs != null) {
          final serverLocalAsUtc = DateTime.tryParse('${timeNowStr.trim()}Z');
          final utcFromEpoch = DateTime.fromMillisecondsSinceEpoch(serverTs * 1000, isUtc: true);
          if (serverLocalAsUtc != null) {
            _serverUtcOffset = serverLocalAsUtc.difference(utcFromEpoch);
            final totalMin = _serverUtcOffset.inMinutes;
            final rounded = (totalMin / 30).round() * 30;
            _serverUtcOffset = Duration(minutes: rounded);
            AppLogger.debug(LogModule.api, 'Catch-up: Server time_now=$timeNowStr, epoch=$serverTs, offset=${_serverUtcOffset.inMinutes}min');
          }
        }
      }
      _serverTimezoneLoaded = true;
    } catch (e, st) {
      AppLogger.warning(LogModule.api, 'Failed to load server timezone', error: e, stackTrace: st);
      _serverTimezoneLoaded = true;
    }
  }

  /// Convert a UTC DateTime to server local time
  static DateTime _toServerLocal(DateTime utcTime) {
    return utcTime.toUtc().add(_serverUtcOffset);
  }

  /// Build timeshift URL from a UTC start time (fallback with offset conversion)
  static String getTimeshiftUrl(String streamId, DateTime startUtc, int durationMin) {
    final s = _toServerLocal(startUtc);
    final startFmt = '${s.year}-${s.month.toString().padLeft(2,'0')}-${s.day.toString().padLeft(2,'0')}:${s.hour.toString().padLeft(2,'0')}-${s.minute.toString().padLeft(2,'0')}';
    final url = '${AppConfig.serverUrl}/timeshift/${AppConfig.username}/${AppConfig.password}/$durationMin/$startFmt/$streamId.ts';
    AppLogger.debug(LogModule.api, 'Catch-up URL (from UTC): $url');
    return url;
  }

  /// Build timeshift URL from server-local time string (preferred)
  static String getTimeshiftUrlFromLocal(String streamId, String serverLocalStart, int durationMin) {
    final dt = DateTime.tryParse(serverLocalStart.trim());
    if (dt == null) return getTimeshiftUrl(streamId, DateTime.now().toUtc(), durationMin);
    final startFmt = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}:${dt.hour.toString().padLeft(2,'0')}-${dt.minute.toString().padLeft(2,'0')}';
    final url = '${AppConfig.serverUrl}/timeshift/${AppConfig.username}/${AppConfig.password}/$durationMin/$startFmt/$streamId.ts';
    AppLogger.debug(LogModule.api, 'Catch-up URL (from server-local): $url');
    return url;
  }

  /// Check if a specific channel supports catch-up (tv_archive == 1)
  static bool channelHasCatchup(Map<String, dynamic> channel) {
    return channel['tv_archive']?.toString() == '1';
  }

  /// Get catch-up archive duration in days for a channel
  static int channelArchiveDays(Map<String, dynamic> channel) {
    return int.tryParse(channel['tv_archive_duration']?.toString() ?? '0') ?? 0;
  }
}
