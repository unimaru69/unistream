import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage_keys.dart';
import '../services/tmdb_service.dart';
import '../utils/title_year_parser.dart';

/// Compile-time TMDB key. Ship-time secret, injected via:
///
///     flutter run --dart-define=TMDB_KEY=xxxx
///
/// Defaults to empty — feature stays dormant until the user provides a key
/// in Settings.
const String _kBakedTmdbKey = String.fromEnvironment('TMDB_KEY');

/// How long we trust a cached TMDB lookup before re-fetching. Metadata
/// rarely changes, so 30 days is plenty and saves bandwidth.
const Duration _kTmdbTtl = Duration(days: 30);

/// Reactively pushes the effective TMDB configuration (user override wins
/// over the baked-in key, and the feature can be force-disabled).
class TmdbConfig {
  final String apiKey;
  final bool enabled;
  const TmdbConfig({required this.apiKey, required this.enabled});

  bool get isActive => enabled && apiKey.isNotEmpty;
}

class TmdbConfigNotifier extends StateNotifier<TmdbConfig> {
  TmdbConfigNotifier()
      : super(const TmdbConfig(apiKey: _kBakedTmdbKey, enabled: true)) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final userKey = p.getString(StorageKeys.tmdbUserKey) ?? '';
    final enabled = p.getBool(StorageKeys.tmdbEnabled) ?? true;
    state = TmdbConfig(
      apiKey: userKey.isNotEmpty ? userKey : _kBakedTmdbKey,
      enabled: enabled,
    );
  }

  Future<void> setUserKey(String key) async {
    final p = await SharedPreferences.getInstance();
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await p.remove(StorageKeys.tmdbUserKey);
    } else {
      await p.setString(StorageKeys.tmdbUserKey, trimmed);
    }
    state = TmdbConfig(
      apiKey: trimmed.isNotEmpty ? trimmed : _kBakedTmdbKey,
      enabled: state.enabled,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(StorageKeys.tmdbEnabled, enabled);
    state = TmdbConfig(apiKey: state.apiKey, enabled: enabled);
  }
}

final tmdbConfigProvider =
    StateNotifierProvider<TmdbConfigNotifier, TmdbConfig>(
  (_) => TmdbConfigNotifier(),
);

/// Singleton-ish TMDB client derived from the current config. Recreated
/// automatically when the user changes the key.
final tmdbServiceProvider = Provider<TmdbService>((ref) {
  final cfg = ref.watch(tmdbConfigProvider);
  return TmdbService(apiKey: cfg.isActive ? cfg.apiKey : '');
});

/// Key used to uniquely address a lookup request. We reuse the parsed
/// title + year + kind so duplicates (same film under different raw names)
/// dedupe naturally.
class TmdbLookup {
  final String rawTitle;
  final TmdbKind kind;
  const TmdbLookup({required this.rawTitle, required this.kind});

  @override
  bool operator ==(Object other) =>
      other is TmdbLookup && other.rawTitle == rawTitle && other.kind == kind;

  @override
  int get hashCode => Object.hash(rawTitle, kind);
}

/// Returns TMDB enrichment for a given raw title, or null if unavailable /
/// unreachable / feature disabled. Result is cached on-device for 30 days.
final tmdbLookupProvider =
    FutureProvider.family<TmdbResult?, TmdbLookup>((ref, lookup) async {
  final cfg = ref.watch(tmdbConfigProvider);
  if (!cfg.isActive) return null;

  final parsed = TitleYearParser.parse(lookup.rawTitle);
  if (!parsed.isUsable) return null;

  final cacheKey = StorageKeys.tmdbCache(
    lookup.kind.name,
    _normalize(parsed.title),
    parsed.year?.toString(),
  );
  final p = await SharedPreferences.getInstance();

  // Hit the cache first.
  final cached = p.getString(cacheKey);
  if (cached != null) {
    try {
      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(
        (decoded['_savedAt'] as int?) ?? 0,
      );
      if (DateTime.now().difference(savedAt) < _kTmdbTtl) {
        if (decoded['_negative'] == true) return null;
        return TmdbResult.fromCache(decoded);
      }
    } catch (_) {
      // Malformed cache entry — fall through to refetch.
    }
  }

  // Live fetch.
  final svc = ref.read(tmdbServiceProvider);
  final result = await svc.enrich(rawTitle: lookup.rawTitle, kind: lookup.kind);

  if (result == null) {
    // Negative cache so we don't hammer TMDB for the same miss. Shorter TTL
    // (7d) because content gets added over time.
    await p.setString(
      cacheKey,
      jsonEncode({
        '_negative': true,
        '_savedAt': DateTime.now()
            .subtract(_kTmdbTtl - const Duration(days: 7))
            .millisecondsSinceEpoch,
      }),
    );
    return null;
  }

  await p.setString(
    cacheKey,
    jsonEncode({
      ...result.toJson(),
      '_savedAt': DateTime.now().millisecondsSinceEpoch,
    }),
  );
  return result;
});

String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
