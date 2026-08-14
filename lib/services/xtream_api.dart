import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/form_factor.dart';
import 'package:unistream/core/tv_diag_overlay.dart';
import 'package:unistream/core/logger.dart';
import 'package:unistream/core/storage_keys.dart';
import '../models/app_config.dart';
import '../models/category.dart' as cat;
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series_item.dart';
import '../models/episode.dart';
import '../models/json_coerce.dart';
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
/// Slim EPG program entry returned by [XtreamApi.getCachedEpgPair].
/// Carries just what the Live focused-preview panel needs: title +
/// start + end (the panel computes progress + "EN DIRECT" itself).
class EpgPreviewEntry {
  const EpgPreviewEntry({
    required this.title,
    required this.start,
    required this.end,
  });

  final String title;
  final DateTime start;
  final DateTime end;

  /// 0..1 ratio of the program elapsed, clamped.
  double get progress {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

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


// ── Isolate-side catalog reducers (Android TV memory survival) ──
//
// The Home screen used to pull the FULL vod + series + live lists in
// parallel just to build the hero, "recently added" and catch-up rows.
// On a real provider that's tens of thousands of objects materialised at
// once on the main isolate — the invisible memory spike that got the app
// SIGKILLed on a 1 GB armv7 TV (the diag strip froze mid-load, so the
// last rss it showed was never the peak).
//
// These run inside `compute`: they decode, reduce, and hand back only a
// small list, so the big graph is born and dies in the worker isolate.

int _recencyOf(dynamic e) {
  if (e is! Map) return 0;
  final added = int.tryParse('${e['added'] ?? 0}') ?? 0;
  final mod = int.tryParse('${e['last_modified'] ?? 0}') ?? 0;
  return added > mod ? added : mod;
}

/// Decode + keep only the [_TrimArgs.max] most recently added entries.
List<dynamic> _decodeTrimRecent(_TrimArgs args) {
  final list = jsonDecode(args.body) as List<dynamic>;
  list.sort((a, b) => _recencyOf(b).compareTo(_recencyOf(a)));
  return list.take(args.max).toList();
}

/// Decode + keep only catch-up-capable channels (tv_archive == 1).
List<dynamic> _decodeCatchupChannels(_TrimArgs args) {
  final list = jsonDecode(args.body) as List<dynamic>;
  return list
      .where((e) => e is Map && '${e['tv_archive']}' == '1')
      .take(args.max)
      .toList();
}

class _TrimArgs {
  const _TrimArgs(this.body, this.max);
  final String body;
  final int max;
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

  /// TV boxes are memory-starved (32-bit, ~1 GB shared): keep the EPG
  /// cache an order of magnitude smaller there. Measured on a real-scale
  /// catalog (42k items), memory pressure is what silently kills the app
  /// on armv7 Android TV — same lesson as the tvOS UserDefaults SIGABRT.
  static int get _epgCacheMaxSize => FormFactorInfo.isAndroidTv ? 150 : 500;

  /// In-flight EPG fetches, keyed by the same cache key as
  /// `_epgCache`. When `N` widgets call `getShortEpg(stream_42)` at
  /// the same time (catchup row + focused preview + stream-list
  /// subtitle), the first fetch is stored here and the others await
  /// the same future instead of firing `N` HTTP requests against the
  /// Xtream server. Pattern: single-flight / request coalescing.
  static final Map<String, Future<Map<String, dynamic>>> _epgInflight = {};

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
      final decoded = await _decodeOffMain(raw) as Map<String, dynamic>;
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
      // Encode off-main too — same UI-thread-freeze rationale as
      // _decodeOffMain, this fires repeatedly while EPG previews load.
      final encoded = await compute(jsonEncode, serialized);
      await prefs.setString(
          StorageKeys.epgCache(AppConfig.activeProfileId), encoded);
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
  /// Each entry is a FULL category list; the "all items" lists reach
  /// 10-30k maps on real providers. 100 cached lists is fine on desktop,
  /// lethal on a 32-bit TV — cap hard there.
  static int get _streamCacheMaxSize => FormFactorInfo.isAndroidTv ? 10 : 100;

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


  /// Decode a large JSON payload OFF the main isolate.
  ///
  /// Full catalog lists reach tens of MB on real providers; parsing them
  /// with a plain [jsonDecode] froze the UI thread — invisible on fast
  /// hardware, but 15-30 s on an armv7 TV CPU, where the user's D-pad
  /// presses then trip Android's input-dispatch ANR and the system kills
  /// the app (silently: no Sentry event on Android 8). Observed as
  /// "Choreographer: Skipped 90+ frames" even on the emulator.
  static Future<dynamic> _decodeOffMain(String body) =>
      compute(jsonDecode, body);

  /// [force] bypasses the 5-minute cache and goes back to the panel.
  /// Used by pull-to-refresh and the explicit "Actualiser le catalogue"
  /// action — without it those affordances silently returned the very
  /// list the user was trying to refresh.
  static Future<List<dynamic>> getLiveStreams([String? catId, bool force = false]) async {
    AppLogger.breadcrumb('api', 'getLiveStreams', data: {'categoryId': catId, 'force': force});
    final cacheKey = 'get_live_streams:${catId ?? ''}';
    final cached = force ? null : _getStreamCached(cacheKey);
    if (cached != null) return cached;
    var url = '$baseUrl&action=get_live_streams';
    if (catId != null) url += '&category_id=$catId';
    TvDiag.mark('liveFetch');
    final body = (await httpGet(url)).body;
    TvDiag.mark('liveDecode');
    final result = await _decodeOffMain(body) as List<dynamic>;
    TvDiag.mark('liveDone');
    _putStreamCache(cacheKey, result);
    return result;
  }

  static Future<List<Channel>> getLiveStreamsTyped([String? catId, bool force = false]) async {
    final list = await getLiveStreams(catId, force);
    return list.map((e) => Channel.fromJson(e as Map<String, dynamic>)).toList();
  }


  /// Most recently added VOD + series, reduced inside a worker isolate.
  /// Feeds the Accueil hero + "Recently added" row without ever holding
  /// the whole catalog on the main isolate.
  static Future<List<dynamic>> getRecentCatalog({int max = 60}) async {
    final out = <dynamic>[];
    // Sequential, not Future.wait: on a memory-starved TV two multi-MB
    // payloads in flight at once is exactly the spike we're avoiding.
    for (final action in <String>['get_vod_streams', 'get_series']) {
      try {
        final body = (await httpGet('$baseUrl&action=$action')).body;
        final trimmed = await compute(_decodeTrimRecent, _TrimArgs(body, max));
        out.addAll(trimmed);
      } catch (e, st) {
        AppLogger.warning(LogModule.api, 'getRecentCatalog($action) failed',
            error: e, stackTrace: st);
      }
    }
    out.sort((a, b) => _recencyOf(b).compareTo(_recencyOf(a)));
    // Type only the survivors (≤ max), so the freezed objects never exist
    // at catalog scale. Series carry `series_id`, films `stream_id`.
    return out.take(max).map<dynamic>((e) {
      final m = e as Map<String, dynamic>;
      return m.containsKey('series_id')
          ? SeriesItem.fromJson(m)
          : VodItem.fromJson(m);
    }).toList();
  }

  /// Catch-up-capable live channels only, reduced inside a worker isolate.
  static Future<List<Channel>> getCatchupChannels({int max = 15}) async {
    try {
      final body =
          (await httpGet('$baseUrl&action=get_live_streams')).body;
      final trimmed =
          await compute(_decodeCatchupChannels, _TrimArgs(body, max));
      return trimmed
          .map((e) => Channel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.warning(LogModule.api, 'getCatchupChannels failed',
          error: e, stackTrace: st);
      return <Channel>[];
    }
  }

  static Future<List<dynamic>> getVodCategories() async =>
      jsonDecode((await httpGet('$baseUrl&action=get_vod_categories')).body);

  static Future<List<cat.Category>> getVodCategoriesTyped() async {
    final list = await getVodCategories();
    return list.map((e) => cat.Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [force]: see [getLiveStreams].
  static Future<List<dynamic>> getVodStreams([String? catId, bool force = false]) async {
    final cacheKey = 'get_vod_streams:${catId ?? ''}';
    final cached = force ? null : _getStreamCached(cacheKey);
    if (cached != null) return cached;
    var url = '$baseUrl&action=get_vod_streams';
    if (catId != null) url += '&category_id=$catId';
    TvDiag.mark('vodFetch');
    final body = (await httpGet(url)).body;
    TvDiag.mark('vodDecode');
    final result = await _decodeOffMain(body) as List<dynamic>;
    TvDiag.mark('vodDone');
    _putStreamCache(cacheKey, result);
    return result;
  }

  static Future<List<VodItem>> getVodStreamsTyped([String? catId, bool force = false]) async {
    final list = await getVodStreams(catId, force);
    return list.map((e) => VodItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<dynamic>> getSeriesCategories() async =>
      jsonDecode((await httpGet('$baseUrl&action=get_series_categories')).body);

  static Future<List<cat.Category>> getSeriesCategoriesTyped() async {
    final list = await getSeriesCategories();
    return list.map((e) => cat.Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [force]: see [getLiveStreams].
  static Future<List<dynamic>> getSeries([String? catId, bool force = false]) async {
    final cacheKey = 'get_series:${catId ?? ''}';
    final cached = force ? null : _getStreamCached(cacheKey);
    if (cached != null) return cached;
    var url = '$baseUrl&action=get_series';
    if (catId != null) url += '&category_id=$catId';
    TvDiag.mark('seriesFetch');
    final body = (await httpGet(url)).body;
    TvDiag.mark('seriesDecode');
    final result = await _decodeOffMain(body) as List<dynamic>;
    TvDiag.mark('seriesDone');
    _putStreamCache(cacheKey, result);
    return result;
  }

  static Future<List<SeriesItem>> getSeriesTyped([String? catId, bool force = false]) async {
    final list = await getSeries(catId, force);
    return list.map((e) => SeriesItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async =>
      jsonDecode((await httpGet('$baseUrl&action=get_series_info&series_id=$seriesId')).body);

  static Future<Map<String, List<Episode>>> getSeriesEpisodesTyped(String seriesId) async {
    final data = await getSeriesInfo(seriesId);
    // Xtream panels disagree on the `episodes` shape: usually a map keyed by
    // season ("1": [...]), but some return a flat list, an empty list, or omit
    // it entirely. Normalise to a season→episodes map; anything unexpected
    // yields an empty result rather than a TypeError.
    final raw = data['episodes'];
    final Map<String, dynamic> episodes = switch (raw) {
      Map<String, dynamic> m => m,
      List<dynamic> l => {'1': l},
      _ => <String, dynamic>{},
    };
    final result = <String, List<Episode>>{};
    episodes.forEach((season, epList) {
      if (epList is! List) return;
      result[season] = epList
          .whereType<Map<String, dynamic>>()
          .map(Episode.fromJson)
          .toList();
    });
    return result;
  }

  static Future<Map<String, dynamic>> getShortEpg(String streamId, {int limit = 8}) async {
    final key = 'short_epg_${streamId}_$limit';
    final cached = _epgCache[key];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _epgCacheTtl) {
      return cached.data;
    }
    // Single-flight: if a fetch for this key is already in flight,
    // return its future so concurrent callers (catchup row + focused
    // preview + stream-list subtitle all asking the same streamId)
    // share one HTTP round-trip instead of stampeding the server.
    final inflight = _epgInflight[key];
    if (inflight != null) return inflight;
    final future = (() async {
      try {
        final body = (await httpGet('$baseUrl&action=get_short_epg&stream_id=$streamId&limit=$limit')).body;
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) return <String, dynamic>{};
        _epgCache[key] = EpgCacheEntry(decoded, DateTime.now());
        if (_epgCache.length > _epgCacheMaxSize) _evictEpgCache();
        _scheduleEpgSave();
        return decoded;
      } catch (e) {
        // Best-effort EPG: some panels return an empty body or an HTML error
        // page (non-JSON) → degrade to "no EPG" instead of throwing into every
        // caller. Not cached, so it retries on the next request.
        AppLogger.debug(LogModule.epg, 'short EPG unavailable for $streamId: $e');
        return <String, dynamic>{};
      } finally {
        _epgInflight.remove(key);
      }
    })();
    _epgInflight[key] = future;
    return future;
  }

  /// Full-day EPG (past + current + future) via get_simple_data_table
  static Future<Map<String, dynamic>> getFullDayEpg(String streamId) async {
    final key = 'full_epg_$streamId';
    final cached = _epgCache[key];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _epgCacheTtl) {
      return cached.data;
    }
    // Single-flight: see comment in `getShortEpg`.
    final inflight = _epgInflight[key];
    if (inflight != null) return inflight;
    final future = (() async {
      try {
        final body = (await httpGet('$baseUrl&action=get_simple_data_table&stream_id=$streamId')).body;
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) return <String, dynamic>{};
        _epgCache[key] = EpgCacheEntry(decoded, DateTime.now());
        if (_epgCache.length > _epgCacheMaxSize) _evictEpgCache();
        _scheduleEpgSave();
        return decoded;
      } catch (e) {
        // Best-effort EPG (see getShortEpg): degrade to "no EPG" on a non-JSON
        // or error body instead of throwing into every caller.
        AppLogger.debug(LogModule.epg, 'full-day EPG unavailable for $streamId: $e');
        return <String, dynamic>{};
      } finally {
        _epgInflight.remove(key);
      }
    })();
    _epgInflight[key] = future;
    return future;
  }

  /// Live preview EPG snapshot — current + next programme parsed
  /// from whichever short / full EPG variant is cached for [streamId].
  /// Returns `(null, null)` when nothing is cached (caller should
  /// kick a `getShortEpg` then re-query).
  static ({EpgPreviewEntry? now, EpgPreviewEntry? next})
      getCachedEpgPair(String streamId) {
    for (final limit in [2, 8, 30]) {
      final key = 'short_epg_${streamId}_$limit';
      final cached = _epgCache[key];
      if (cached != null &&
          DateTime.now().difference(cached.timestamp) < _epgCacheTtl) {
        final pair = _findCurrentAndNext(cached.data);
        if (pair.now != null) return pair;
      }
    }
    final fullKey = 'full_epg_$streamId';
    final fullCached = _epgCache[fullKey];
    if (fullCached != null &&
        DateTime.now().difference(fullCached.timestamp) < _epgCacheTtl) {
      return _findCurrentAndNext(fullCached.data);
    }
    return (now: null, next: null);
  }

  static ({EpgPreviewEntry? now, EpgPreviewEntry? next})
      _findCurrentAndNext(Map<String, dynamic> epgData) {
    final listings = epgData['epg_listings'] as List<dynamic>?;
    if (listings == null || listings.isEmpty) {
      return (now: null, next: null);
    }
    final now = DateTime.now();
    EpgPreviewEntry? current;
    EpgPreviewEntry? upcoming;
    for (final raw in listings) {
      final item = raw as Map<String, dynamic>;
      final startStr = coerceStringOrNull(item['start']);
      final endStr = coerceStringOrNull(item['end']);
      if (startStr == null || endStr == null) continue;
      DateTime start;
      DateTime end;
      try {
        start = DateTime.parse(startStr);
        end = DateTime.parse(endStr);
      } catch (_) {
        continue;
      }
      final rawTitle = coerceString(item['title']);
      String title = rawTitle;
      try {
        title = utf8.decode(base64Decode(rawTitle));
      } catch (_) {/* not base64 */}
      if (title.isEmpty) continue;
      if (current == null && now.isAfter(start) && now.isBefore(end)) {
        current = EpgPreviewEntry(title: title, start: start, end: end);
      } else if (current != null && upcoming == null && start.isAfter(now)) {
        upcoming = EpgPreviewEntry(title: title, start: start, end: end);
        break;
      }
    }
    return (now: current, next: upcoming);
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
      final startStr = coerceStringOrNull(item['start']);
      final endStr = coerceStringOrNull(item['end']);
      if (startStr == null || endStr == null) continue;
      try {
        final start = DateTime.parse(startStr);
        final end = DateTime.parse(endStr);
        if (now.isAfter(start) && now.isBefore(end)) {
          final title = coerceStringOrNull(item['title']);
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
