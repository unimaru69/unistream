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
    // Push to Supabase WITH the title/cover/url/mode that
    // `saveMeta()` stashed locally — without this, every Flutter
    // push went out as `meta_json: "{}"` and tvOS displayed the raw
    // content_key in its Reprendre row when it pulled. tvOS reads
    // `title` (or `name`) and `cover` keys from meta_json.
    SyncService.instance.pushWatchProgress(
      key, pos.inMilliseconds, dur.inMilliseconds, _readMeta(p, key),
    );
  }

  /// Read the locally-stored meta blob and shape it for cross-platform
  /// consumption. Adds an explicit `title` field (mirrors `name`) so
  /// the tvOS native app finds it under either key.
  static Map<String, dynamic> _readMeta(SharedPreferences p, String key) {
    final raw = p.getString(StorageKeys.wpMeta(_pid, key));
    if (raw == null) return const {};
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      // tvOS expects `title`; Flutter stores under `name`. Mirror.
      if (m['name'] != null && m['title'] == null) {
        m['title'] = m['name'];
      }
      return m;
    } catch (_) {
      return const {};
    }
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
    // Propagate the removal to Supabase so other devices stop
    // showing this entry on their next pull. Without this, marking
    // an item as not-watched / clearing local progress only mutates
    // SharedPreferences — the cloud row stayed put and the next
    // mergeFromRemote re-hydrated it.
    SyncService.instance.deleteWatchProgress(key);
  }

  /// Sauvegarde les metadonnees d'un item (nom, cover, url, mode) pour le bandeau "Continuer a regarder".
  ///
  /// When the matching progress row already exists locally
  /// (`save()` ran first), also push the updated meta_json to Supabase
  /// so other devices see the title in their Continue Watching row.
  /// Without this push, a meta change after the initial save would
  /// stay local-only and remote consumers kept the old (or empty)
  /// title forever.
  static Future<void> saveMeta(String key, String name, String cover, String url, String mode) async {
    final p = await SharedPreferences.getInstance();
    final meta = {
      'name': name,
      'title': name, // mirror for tvOS readers
      'cover': cover,
      'url': url,
      'mode': mode,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    await p.setString(StorageKeys.wpMeta(_pid, key), jsonEncode(meta));
    // Push only if there's an existing progress row to attach the
    // meta to — Supabase's user_watch_progress requires position +
    // duration to make sense, and a fresh saveMeta with no save() yet
    // would create a zombie row that fails the `dur > 10s` filter.
    final posSec = p.getInt(StorageKeys.wpPosition(_pid, key));
    final durSec = p.getInt(StorageKeys.wpDuration(_pid, key));
    if (posSec != null && durSec != null && durSec >= 10) {
      SyncService.instance.pushWatchProgress(
        key, posSec * 1000, durSec * 1000, meta,
      );
    }
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

  /// Reconcile local watch progress with the latest server pull.
  ///
  /// When [authoritative] is true (default), local entries that the
  /// server no longer has are removed — this is what makes
  /// "Marquer non vu" / "Tout effacer" propagate from another device.
  /// Without it, an unwatch gesture on tvOS never reached the iOS
  /// SharedPreferences cache and the episode kept its progress here.
  ///
  /// Set [authoritative] to false when [remote] might be incomplete
  /// (e.g. a partial pull / known offline state).
  static Future<bool> mergeFromRemote(
    Map<String, dynamic> remote, {
    bool authoritative = true,
  }) async {
    if (!authoritative && remote.isEmpty) return false;
    final p = await SharedPreferences.getInstance();
    bool changed = false;

    // Add / update remote entries.
    for (final entry in remote.entries) {
      final key = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final posMs = data['position_ms'] as int? ?? 0;
      final durMs = data['duration_ms'] as int? ?? 0;
      final meta = data['meta'];
      if (durMs < 10000) continue; // Skip very short items

      // Always pull the meta blob across so the Continue Watching
      // shelf can show the proper title/cover. tvOS pushes `title`
      // + `name` in meta_json; Flutter prefers `name`. Mirror both.
      if (meta is Map) {
        final remoteMeta = Map<String, dynamic>.from(meta);
        if (remoteMeta['title'] != null && remoteMeta['name'] == null) {
          remoteMeta['name'] = remoteMeta['title'];
        }
        // Local always wins on URL since the resume URL is platform-
        // specific; pull the rest verbatim.
        final existingMetaStr = p.getString(StorageKeys.wpMeta(_pid, key));
        Map<String, dynamic> merged = remoteMeta;
        if (existingMetaStr != null) {
          try {
            final existing = Map<String, dynamic>.from(
                jsonDecode(existingMetaStr) as Map);
            if ((existing['url'] as String?)?.isNotEmpty ?? false) {
              merged = {...remoteMeta, 'url': existing['url']};
            }
          } catch (_) {/* keep remote */}
        }
        await p.setString(StorageKeys.wpMeta(_pid, key), jsonEncode(merged));
        changed = true;
      }

      final localPos = p.getInt(StorageKeys.wpPosition(_pid, key));
      if (localPos != null) continue; // pos/dur already up to date
      await p.setInt(StorageKeys.wpPosition(_pid, key), posMs ~/ 1000);
      await p.setInt(StorageKeys.wpDuration(_pid, key), durMs ~/ 1000);
      changed = true;
    }

    // Authoritative reconciliation: drop local progress entries the
    // server doesn't know about. Walk every key in SharedPreferences
    // that matches the wpPosition prefix and remove the trio
    // (position / duration / meta) for any content_key absent from
    // [remote].
    if (authoritative) {
      final prefix = StorageKeys.wpPositionPrefix(_pid);
      final keysToWipe = <String>[];
      for (final k in p.getKeys()) {
        if (!k.startsWith(prefix)) continue;
        final id = k.substring(prefix.length);
        if (!remote.containsKey(id)) keysToWipe.add(id);
      }
      for (final id in keysToWipe) {
        await p.remove(StorageKeys.wpPosition(_pid, id));
        await p.remove(StorageKeys.wpDuration(_pid, id));
        await p.remove(StorageKeys.wpMeta(_pid, id));
        changed = true;
      }
    }

    return changed;
  }
}
