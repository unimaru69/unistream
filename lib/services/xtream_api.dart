import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/app_config.dart';

// ── Network helpers ──
const _defaultTimeout = Duration(seconds: 15);
const _maxRetries = 3;

Future<http.Response> httpGet(String url) async {
  for (int i = 0; i < _maxRetries; i++) {
    try {
      return await http.get(Uri.parse(url)).timeout(_defaultTimeout);
    } on TimeoutException {
      if (i == _maxRetries - 1) rethrow;
    } on SocketException {
      if (i == _maxRetries - 1) rethrow;
    } on http.ClientException {
      if (i == _maxRetries - 1) rethrow;
    }
    await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
  }
  throw Exception('Echec apres $_maxRetries tentatives');
}

// ── EPG Cache ──
class EpgCacheEntry {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  EpgCacheEntry(this.data, this.timestamp);
}

// ── API Xtream Codes ──
class XtreamApi {
  /// Translate technical error messages into user-friendly French.
  static String friendlyError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Failed host lookup'))
      return 'Connexion impossible. Vérifiez votre connexion internet.';
    if (msg.contains('TimeoutException'))
      return 'Le serveur ne répond pas. Réessayez dans quelques instants.';
    if (msg.contains('ClientException'))
      return 'Erreur de communication avec le serveur.';
    if (msg.contains('FormatException'))
      return 'Réponse invalide du serveur.';
    if (msg.contains('401') || msg.contains('auth'))
      return 'Identifiants incorrects. Vérifiez votre nom d\'utilisateur et mot de passe.';
    return 'Une erreur est survenue. Réessayez.';
  }

  static final Map<String, EpgCacheEntry> _epgCache = {};
  static const Duration _epgCacheTtl = Duration(minutes: 30);

  static int get epgCacheSize => _epgCache.length;
  static void clearEpgCache() => _epgCache.clear();

  static String get baseUrl =>
      '${AppConfig.serverUrl}/player_api.php?username=${AppConfig.username}&password=${AppConfig.password}';

  static Future<Map<String, dynamic>> authenticate() async {
    final r = await httpGet(baseUrl);
    return jsonDecode(r.body);
  }

  static Future<List<dynamic>> getLiveCategories() async =>
      jsonDecode((await httpGet('$baseUrl&action=get_live_categories')).body);

  static Future<List<dynamic>> getLiveStreams([String? catId]) async {
    var url = '$baseUrl&action=get_live_streams';
    if (catId != null) url += '&category_id=$catId';
    return jsonDecode((await httpGet(url)).body);
  }

  static Future<List<dynamic>> getVodCategories() async =>
      jsonDecode((await httpGet('$baseUrl&action=get_vod_categories')).body);

  static Future<List<dynamic>> getVodStreams([String? catId]) async {
    var url = '$baseUrl&action=get_vod_streams';
    if (catId != null) url += '&category_id=$catId';
    return jsonDecode((await httpGet(url)).body);
  }

  static Future<List<dynamic>> getSeriesCategories() async =>
      jsonDecode((await httpGet('$baseUrl&action=get_series_categories')).body);

  static Future<List<dynamic>> getSeries([String? catId]) async {
    var url = '$baseUrl&action=get_series';
    if (catId != null) url += '&category_id=$catId';
    return jsonDecode((await httpGet(url)).body);
  }

  static Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async =>
      jsonDecode((await httpGet('$baseUrl&action=get_series_info&series_id=$seriesId')).body);

  static Future<Map<String, dynamic>> getShortEpg(String streamId, {int limit = 8}) async {
    final key = 'short_epg_${streamId}_$limit';
    final cached = _epgCache[key];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _epgCacheTtl) {
      return cached.data;
    }
    final data = jsonDecode((await httpGet('$baseUrl&action=get_short_epg&stream_id=$streamId&limit=$limit')).body) as Map<String, dynamic>;
    _epgCache[key] = EpgCacheEntry(data, DateTime.now());
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
            } catch (_) {
              return title;
            }
          }
        }
      } catch (_) { continue; }
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
            debugPrint('[Catch-up] Server time_now=$timeNowStr, epoch=$serverTs, offset=${_serverUtcOffset.inMinutes}min');
          }
        }
      }
      _serverTimezoneLoaded = true;
    } catch (_) {
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
    debugPrint('[Catch-up] URL (from UTC): $url');
    return url;
  }

  /// Build timeshift URL from server-local time string (preferred)
  static String getTimeshiftUrlFromLocal(String streamId, String serverLocalStart, int durationMin) {
    final dt = DateTime.tryParse(serverLocalStart.trim());
    if (dt == null) return getTimeshiftUrl(streamId, DateTime.now().toUtc(), durationMin);
    final startFmt = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}:${dt.hour.toString().padLeft(2,'0')}-${dt.minute.toString().padLeft(2,'0')}';
    final url = '${AppConfig.serverUrl}/timeshift/${AppConfig.username}/${AppConfig.password}/$durationMin/$startFmt/$streamId.ts';
    debugPrint('[Catch-up] URL (from server-local): $url');
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
