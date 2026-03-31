import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/storage_keys.dart';
import '../models/profile.dart';
import '../models/app_config.dart';
import 'xtream_api.dart';

class ImportExport {
  /// Parse un fichier M3U et retourne les entrees sous forme de liste.
  static List<Map<String, String>> parseM3U(String content) {
    final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final result = <Map<String, String>>[];
    String? name;
    for (final line in lines) {
      if (line.startsWith('#EXTINF:')) {
        // Extract name after last comma
        final commaIdx = line.lastIndexOf(',');
        name = commaIdx >= 0 ? line.substring(commaIdx + 1).trim() : 'Sans titre';
      } else if (!line.startsWith('#')) {
        result.add({'name': name ?? 'Sans titre', 'url': line});
        name = null;
      }
    }
    return result;
  }

  /// Export les favoris du profil actif en M3U.
  static Future<String> exportFavoritesM3U() async {
    final p = await SharedPreferences.getInstance();
    final key = StorageKeys.favorites(AppConfig.activeProfileId);
    final raw = p.getString(key);
    if (raw == null) return '#EXTM3U\n';
    final items = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    final buf = StringBuffer('#EXTM3U\n');
    for (final item in items) {
      final name = item['name'] ?? 'Sans titre';
      final mode = item['_mode'] ?? 'live';
      final id = mode == 'series'
          ? item['series_id']?.toString() ?? ''
          : item['stream_id']?.toString() ?? '';
      String url;
      if (mode == 'live') {
        url = XtreamApi.getLiveStreamUrl(id);
      } else if (mode == 'vod') {
        url = XtreamApi.getVodStreamUrl(id, item['container_extension'] ?? 'mp4');
      } else {
        url = '# series:$id';
      }
      buf.writeln('#EXTINF:-1,$name');
      buf.writeln(url);
    }
    return buf.toString();
  }

  /// Export toute la config (profils + favoris + progression) en JSON.
  static Future<String> exportConfigJSON() async {
    final p = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'profiles': AppConfig.profiles.map((pr) => pr.toJson()).toList(),
      'activeProfile': AppConfig.activeProfileId,
    };
    // Include favorites and watch progress for each profile
    for (final pr in AppConfig.profiles) {
      final favKey = StorageKeys.favorites(pr.id);
      final favRaw = p.getString(favKey);
      if (favRaw != null) data['fav_${pr.id}'] = favRaw;
      // Collect watch progress keys
      final wpData = <String, dynamic>{};
      final wpPfx = StorageKeys.wpPrefix(pr.id);
      for (final k in p.getKeys()) {
        if (k.startsWith(wpPfx)) {
          final v = p.get(k);
          wpData[k] = v;
        }
      }
      if (wpData.isNotEmpty) data['wp_${pr.id}'] = wpData;
    }
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Import une config JSON.
  static Future<void> importConfigJSON(String content) async {
    final data = jsonDecode(content) as Map<String, dynamic>;
    final p = await SharedPreferences.getInstance();
    // Restore profiles
    if (data['profiles'] != null) {
      AppConfig.profiles = (data['profiles'] as List)
          .map((e) => Profile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      await p.setString(StorageKeys.profilesList, jsonEncode(AppConfig.profiles.map((e) => e.toJson()).toList()));
    }
    // Restore active profile
    if (data['activeProfile'] != null) {
      await p.setString(StorageKeys.activeProfile, data['activeProfile'] as String);
    }
    // Restore favorites
    for (final pr in AppConfig.profiles) {
      final favKey = 'fav_${pr.id}';
      if (data[favKey] != null) {
        await p.setString(StorageKeys.favorites(pr.id), data[favKey] as String);
      }
      // Restore watch progress
      final wpKey = 'wp_${pr.id}';
      if (data[wpKey] != null) {
        final wpData = data[wpKey] as Map<String, dynamic>;
        for (final entry in wpData.entries) {
          if (entry.value is int) await p.setInt(entry.key, entry.value);
          if (entry.value is String) await p.setString(entry.key, entry.value);
        }
      }
    }
    await AppConfig.load();
  }
}
