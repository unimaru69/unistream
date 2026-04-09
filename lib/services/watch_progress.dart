import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/storage_keys.dart';
import '../models/app_config.dart';
import '../models/continue_watching_item.dart';
import '../models/history_entry.dart';
import 'sync_service.dart';

class WatchProgress {
  static String get _pid => AppConfig.activeProfileId;

  /// Sauvegarde la position. Supprime l'entree si le contenu est termine (>95%).
  static Future<void> save(String key, Duration pos, Duration dur) async {
    if (dur.inSeconds < 10) return;
    final ratio = pos.inSeconds / dur.inSeconds;
    if (ratio > 0.95) { await clear(key); return; }
    final p = await SharedPreferences.getInstance();
    await p.setInt(StorageKeys.wpPosition(_pid, key), pos.inSeconds);
    await p.setInt(StorageKeys.wpDuration(_pid, key), dur.inSeconds);
    // Sync to Supabase (fire-and-forget)
    SyncService.instance.pushWatchProgress(
      key, pos.inMilliseconds, dur.inMilliseconds, {},
    );
  }

  static Future<Duration?> getPosition(String key) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getInt(StorageKeys.wpPosition(_pid, key));
    return s != null ? Duration(seconds: s) : null;
  }

  static Future<Duration?> getDuration(String key) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getInt(StorageKeys.wpDuration(_pid, key));
    return s != null ? Duration(seconds: s) : null;
  }

  /// Returns both position and duration in a single call.
  static Future<({Duration? position, Duration? duration})> getProgress(String key) async {
    final p = await SharedPreferences.getInstance();
    final posSec = p.getInt(StorageKeys.wpPosition(_pid, key));
    final durSec = p.getInt(StorageKeys.wpDuration(_pid, key));
    return (
      position: posSec != null ? Duration(seconds: posSec) : null,
      duration: durSec != null ? Duration(seconds: durSec) : null,
    );
  }

  static Future<void> clear(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(StorageKeys.wpPosition(_pid, key));
    await p.remove(StorageKeys.wpDuration(_pid, key));
    await p.remove(StorageKeys.wpMeta(_pid, key));
  }

  /// Sauvegarde les metadonnees d'un item (nom, cover, url, mode) pour le bandeau "Continuer a regarder".
  static Future<void> saveMeta(String key, String name, String cover, String url, String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(StorageKeys.wpMeta(_pid, key), jsonEncode({
      'name': name, 'cover': cover, 'url': url, 'mode': mode,
      'ts': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  /// Retourne une map id -> ratio [0,1] pour tous les items avec une progression.
  static Future<Map<String, double>> loadAll() async {
    final p = await SharedPreferences.getInstance();
    final prefix = StorageKeys.wpPositionPrefix(_pid);
    final result = <String, double>{};
    for (final k in p.getKeys()) {
      if (!k.startsWith(prefix)) continue;
      final id  = k.substring(prefix.length);
      final pos = p.getInt(k) ?? 0;
      final dur = p.getInt(StorageKeys.wpDuration(_pid, id)) ?? 0;
      if (dur > 0) result[id] = (pos / dur).clamp(0.0, 1.0);
    }
    return result;
  }

  /// Retourne la liste des items en cours de visionnage, tries par date de derniere lecture.
  static Future<List<ContinueWatchingItem>> loadContinueWatching() async {
    final p = await SharedPreferences.getInstance();
    final prefix = StorageKeys.wpPositionPrefix(_pid);
    final result = <ContinueWatchingItem>[];
    for (final k in p.getKeys()) {
      if (!k.startsWith(prefix)) continue;
      final id  = k.substring(prefix.length);
      final pos = p.getInt(k) ?? 0;
      final dur = p.getInt(StorageKeys.wpDuration(_pid, id)) ?? 0;
      if (dur == 0 || pos < 30) continue;
      final metaStr = p.getString(StorageKeys.wpMeta(_pid, id));
      if (metaStr == null) continue;
      final meta = Map<String, dynamic>.from(jsonDecode(metaStr) as Map);
      result.add(ContinueWatchingItem.fromMap({...meta, '_id': id, '_ratio': (pos / dur).clamp(0.0, 1.0)}));
    }
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }
  // ── Historique de lecture ──
  static Future<void> saveHistory(String key, String name, String cover, String url, String mode) async {
    final p = await SharedPreferences.getInstance();
    final histKey = StorageKeys.history(_pid);
    final raw = p.getString(histKey);
    List<Map<String, dynamic>> list = [];
    if (raw != null) {
      list = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    }
    list.removeWhere((e) => e['key'] == key);
    list.insert(0, {
      'key': key, 'name': name, 'cover': cover, 'url': url, 'mode': mode,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (list.length > 200) list = list.sublist(0, 200);
    await p.setString(histKey, jsonEncode(list));
  }

  static Future<List<HistoryEntry>> loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(StorageKeys.history(_pid));
    if (raw == null) return [];
    final list = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    list.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
    return list.map((e) => HistoryEntry.fromMap(e)).toList();
  }

  static Future<void> clearHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(StorageKeys.history(_pid));
  }

  /// Supprime une seule entree de l'historique par cle.
  static Future<void> deleteHistoryEntry(String key) async {
    final p = await SharedPreferences.getInstance();
    final histKey = StorageKeys.history(_pid);
    final raw = p.getString(histKey);
    if (raw == null) return;
    final list = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    list.removeWhere((e) => e['key'] == key);
    await p.setString(histKey, jsonEncode(list));
  }

  /// Re-insere une entree dans l'historique (pour undo).
  static Future<void> reInsertHistoryEntry(HistoryEntry entry) async {
    final p = await SharedPreferences.getInstance();
    final histKey = StorageKeys.history(_pid);
    final raw = p.getString(histKey);
    List<Map<String, dynamic>> list = [];
    if (raw != null) {
      list = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    }
    list.insert(0, Map<String, dynamic>.from(entry.toMap()));
    list.sort((a, b) => (b['timestamp'] as String? ?? '').compareTo(a['timestamp'] as String? ?? ''));
    await p.setString(histKey, jsonEncode(list));
  }

  /// Merge remote watch progress into local storage.
  /// Remote entries fill gaps (local takes precedence when both exist).
  static Future<bool> mergeFromRemote(Map<String, dynamic> remote) async {
    if (remote.isEmpty) return false;
    final p = await SharedPreferences.getInstance();
    final prefix = StorageKeys.wpPositionPrefix(_pid);
    bool changed = false;

    for (final entry in remote.entries) {
      final key = entry.key;
      final localPos = p.getInt(StorageKeys.wpPosition(_pid, key));
      if (localPos != null) continue; // Local already has this entry

      final data = entry.value as Map<String, dynamic>;
      final posMs = data['position_ms'] as int? ?? 0;
      final durMs = data['duration_ms'] as int? ?? 0;
      if (durMs < 10000) continue; // Skip very short items

      await p.setInt(StorageKeys.wpPosition(_pid, key), posMs ~/ 1000);
      await p.setInt(StorageKeys.wpDuration(_pid, key), durMs ~/ 1000);
      changed = true;
    }
    return changed;
  }
}
