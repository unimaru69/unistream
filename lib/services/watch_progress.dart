import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';

class WatchProgress {
  static String get _pfx => 'wp_${AppConfig.activeProfileId}_';

  /// Sauvegarde la position. Supprime l'entree si le contenu est termine (>95%).
  static Future<void> save(String key, Duration pos, Duration dur) async {
    if (dur.inSeconds < 10) return;
    final ratio = pos.inSeconds / dur.inSeconds;
    if (ratio > 0.95) { await clear(key); return; }
    final p = await SharedPreferences.getInstance();
    await p.setInt('${_pfx}s_$key', pos.inSeconds);
    await p.setInt('${_pfx}d_$key', dur.inSeconds);
  }

  static Future<Duration?> getPosition(String key) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getInt('${_pfx}s_$key');
    return s != null ? Duration(seconds: s) : null;
  }

  static Future<void> clear(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('${_pfx}s_$key');
    await p.remove('${_pfx}d_$key');
    await p.remove('${_pfx}meta_$key');
  }

  /// Sauvegarde les metadonnees d'un item (nom, cover, url, mode) pour le bandeau "Continuer a regarder".
  static Future<void> saveMeta(String key, String name, String cover, String url, String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('${_pfx}meta_$key', jsonEncode({
      'name': name, 'cover': cover, 'url': url, 'mode': mode,
      'ts': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  /// Retourne une map id -> ratio [0,1] pour tous les items avec une progression.
  static Future<Map<String, double>> loadAll() async {
    final p = await SharedPreferences.getInstance();
    final result = <String, double>{};
    for (final k in p.getKeys()) {
      if (!k.startsWith('${_pfx}s_')) continue;
      final id  = k.substring('${_pfx}s_'.length);
      final pos = p.getInt(k) ?? 0;
      final dur = p.getInt('${_pfx}d_$id') ?? 0;
      if (dur > 0) result[id] = (pos / dur).clamp(0.0, 1.0);
    }
    return result;
  }

  /// Retourne la liste des items en cours de visionnage, tries par date de derniere lecture.
  static Future<List<Map<String, dynamic>>> loadContinueWatching() async {
    final p = await SharedPreferences.getInstance();
    final result = <Map<String, dynamic>>[];
    for (final k in p.getKeys()) {
      if (!k.startsWith('${_pfx}s_')) continue;
      final id  = k.substring('${_pfx}s_'.length);
      final pos = p.getInt(k) ?? 0;
      final dur = p.getInt('${_pfx}d_$id') ?? 0;
      if (dur == 0 || pos < 30) continue;
      final metaStr = p.getString('${_pfx}meta_$id');
      if (metaStr == null) continue;
      final meta = Map<String, dynamic>.from(jsonDecode(metaStr) as Map);
      result.add({...meta, '_id': id, '_ratio': (pos / dur).clamp(0.0, 1.0)});
    }
    result.sort((a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0));
    return result;
  }
  // ── Historique de lecture ──
  static Future<void> saveHistory(String key, String name, String cover, String url, String mode) async {
    final p = await SharedPreferences.getInstance();
    final histKey = '${_pfx}history';
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

  static Future<List<Map<String, String>>> loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('${_pfx}history');
    if (raw == null) return [];
    final list = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    list.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
    return list.map((e) => e.map((k, v) => MapEntry(k, v.toString()))).toList();
  }

  static Future<void> clearHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('${_pfx}history');
  }

  /// Supprime une seule entree de l'historique par cle.
  static Future<void> deleteHistoryEntry(String key) async {
    final p = await SharedPreferences.getInstance();
    final histKey = '${_pfx}history';
    final raw = p.getString(histKey);
    if (raw == null) return;
    final list = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    list.removeWhere((e) => e['key'] == key);
    await p.setString(histKey, jsonEncode(list));
  }

  /// Re-insere une entree dans l'historique (pour undo).
  static Future<void> reInsertHistoryEntry(Map<String, String> entry) async {
    final p = await SharedPreferences.getInstance();
    final histKey = '${_pfx}history';
    final raw = p.getString(histKey);
    List<Map<String, dynamic>> list = [];
    if (raw != null) {
      list = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    }
    list.insert(0, Map<String, dynamic>.from(entry));
    list.sort((a, b) => (b['timestamp'] as String? ?? '').compareTo(a['timestamp'] as String? ?? ''));
    await p.setString(histKey, jsonEncode(list));
  }
}
