import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/logger.dart';
import 'package:unistream/core/storage_keys.dart';
import 'package:unistream/services/sync_service.dart';
import 'package:unistream/utils/content_key.dart';

/// One-time migration that aligns this app's content_key conventions
/// with the tvOS native app's.
///
/// Rationale: pre-build-12 we used three different formats — bare `<id>`
/// for watch progress, `<mode>:<id>` for favorites and history, while
/// tvOS used `<id>` bare for favorites and `<type>_<id>` for watch
/// progress. The mismatch silently split the same logical entity into
/// two Supabase rows (one per platform) and broke cross-device sync.
///
/// Build 12 introduces a single canonical format:
///   * Favourites / watchlist: bare `<id>` (matches tvOS)
///   * Watch progress + history: `<type>_<id>` underscore form
///     (`vod_12345`, `ep_67`, `series_42`, `live_8`).
///
/// This class walks the local SharedPreferences cache and rewrites every
/// stored key, then connects to Supabase and tags any leftover rows in
/// the old format as deleted (favourites/watchlist) or removes them
/// outright (watch progress).
///
/// Idempotent — runs at most once per profile, gated by the
/// `migration_underscore_keys_v1_done_<profileId>` SharedPreferences
/// flag. Safe to call on every launch; subsequent calls return
/// immediately.
class ContentKeyMigration {
  ContentKeyMigration._();

  static const _localFlagPrefix = 'migration_underscore_keys_v1_done_';
  static const _remoteFlagPrefix = 'migration_underscore_keys_v1_remote_done_';

  /// Migrate the local cache for [profileId]. Safe to call repeatedly.
  static Future<void> migrateLocalIfNeeded(String profileId) async {
    final p = await SharedPreferences.getInstance();
    final flag = '$_localFlagPrefix$profileId';
    if (p.getBool(flag) ?? false) return;

    AppLogger.info(
      LogModule.sync,
      'ContentKeyMigration: starting local migration for profile $profileId',
    );

    await _migrateLocalWatchProgress(profileId, p);
    await _migrateLocalFavorites(profileId, p);
    await _migrateLocalWatchlist(profileId, p);
    await _migrateLocalHistory(profileId, p);

    await p.setBool(flag, true);
    AppLogger.info(
      LogModule.sync,
      'ContentKeyMigration: local migration done for profile $profileId',
    );
  }

  /// Migrate the *remote* (Supabase) data for the active profile. Tags
  /// every row that's still in legacy form as deleted (favourites /
  /// watchlist) or DELETEs it outright (watch progress). Idempotent.
  ///
  /// Must run *after* `migrateLocalIfNeeded` and *after* the auth-
  /// gated `SyncService.configure` has resolved (we need a userId +
  /// profileHash to filter rows correctly).
  static Future<void> migrateRemoteIfNeeded(String profileId) async {
    final p = await SharedPreferences.getInstance();
    final flag = '$_remoteFlagPrefix$profileId';
    if (p.getBool(flag) ?? false) return;
    final sync = SyncService.instance;
    if (!sync.ready) return;

    AppLogger.info(
      LogModule.sync,
      'ContentKeyMigration: starting remote migration for profile $profileId',
    );

    try {
      await sync.migrateLegacyKeys();
      await p.setBool(flag, true);
      AppLogger.info(
        LogModule.sync,
        'ContentKeyMigration: remote migration done for profile $profileId',
      );
    } catch (e, st) {
      // Don't mark done on failure — we'll retry on next launch. Local
      // migration already ran so the user keeps a working app; the
      // server-side cleanup catches up later.
      AppLogger.warning(
        LogModule.sync,
        'Remote key migration failed; will retry on next launch',
        error: e, stackTrace: st,
      );
    }
  }

  // ── Local migrations ──────────────────────────────────────────────

  static Future<void> _migrateLocalWatchProgress(
      String profileId, SharedPreferences p) async {
    // Storage layout (legacy): wp_<pid>_s_<bareId>, wp_<pid>_d_<bareId>,
    // wp_<pid>_meta_<bareId>. Walk all `s_` keys, derive the type from
    // the meta blob's `mode` field, then rewrite the trio under the new
    // `<type>_<bareId>` key.
    final posPrefix = StorageKeys.wpPositionPrefix(profileId);
    final wpPrefix = StorageKeys.wpPrefix(profileId);
    final metaPrefix = '${wpPrefix}meta_';
    final durPrefix = '${wpPrefix}d_';

    final oldKeys = <String>{};
    for (final k in p.getKeys()) {
      if (!k.startsWith(posPrefix)) continue;
      oldKeys.add(k.substring(posPrefix.length));
    }

    var migrated = 0;
    for (final oldKey in oldKeys) {
      // Skip keys already in canonical form (idempotency).
      if (ContentKey.parse(oldKey) != null) continue;

      // Read mode from the meta blob to pick the right type prefix.
      final metaStr = p.getString('$metaPrefix$oldKey');
      final mode = _readModeFromMeta(metaStr);
      final type = _typeFromMode(mode);
      final newKey = ContentKey.make(type, oldKey);

      // If the new key happens to already exist (resumed playback after
      // a previous, half-completed migration), skip — we don't want to
      // clobber a fresher entry.
      if (p.getInt('$posPrefix$newKey') != null) {
        await p.remove('$posPrefix$oldKey');
        await p.remove('$durPrefix$oldKey');
        await p.remove('$metaPrefix$oldKey');
        continue;
      }

      // Rename the trio.
      final pos = p.getInt('$posPrefix$oldKey');
      if (pos != null) {
        await p.setInt('$posPrefix$newKey', pos);
        await p.remove('$posPrefix$oldKey');
      }
      final dur = p.getInt('$durPrefix$oldKey');
      if (dur != null) {
        await p.setInt('$durPrefix$newKey', dur);
        await p.remove('$durPrefix$oldKey');
      }
      final meta = p.getString('$metaPrefix$oldKey');
      if (meta != null) {
        await p.setString('$metaPrefix$newKey', meta);
        await p.remove('$metaPrefix$oldKey');
      }
      migrated++;
    }
    AppLogger.info(LogModule.sync,
        'Renamed $migrated watch-progress entries to canonical form');
  }

  static Future<void> _migrateLocalFavorites(
      String profileId, SharedPreferences p) async {
    final raw = p.getString(StorageKeys.favorites(profileId));
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      var changed = false;
      final migrated = list.map<Map<String, dynamic>>((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final oldKey = (map['_key'] ?? map['key'])?.toString() ?? '';
        if (oldKey.isEmpty) return map;
        final bare = ContentKey.stripToBareId(oldKey);
        if (bare != oldKey) changed = true;
        return {...map, 'key': bare, '_key': bare};
      }).toList();
      if (changed) {
        await p.setString(
            StorageKeys.favorites(profileId), jsonEncode(migrated));
        AppLogger.info(LogModule.sync,
            'Renamed ${migrated.length} favourites to bare-id form');
      }
    } catch (e, st) {
      AppLogger.warning(LogModule.sync,
          'Favourites migration failed; leaving local intact',
          error: e, stackTrace: st);
    }
  }

  static Future<void> _migrateLocalWatchlist(
      String profileId, SharedPreferences p) async {
    final raw = p.getString(StorageKeys.watchlist(profileId));
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      var changed = false;
      final migrated = list.map<Map<String, dynamic>>((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final oldKey = (map['_key'] ?? map['key'])?.toString() ?? '';
        if (oldKey.isEmpty) return map;
        final bare = ContentKey.stripToBareId(oldKey);
        if (bare != oldKey) changed = true;
        return {...map, 'key': bare, '_key': bare};
      }).toList();
      if (changed) {
        await p.setString(
            StorageKeys.watchlist(profileId), jsonEncode(migrated));
        AppLogger.info(LogModule.sync,
            'Renamed ${migrated.length} watchlist entries to bare-id form');
      }
    } catch (e, st) {
      AppLogger.warning(LogModule.sync,
          'Watchlist migration failed; leaving local intact',
          error: e, stackTrace: st);
    }
  }

  static Future<void> _migrateLocalHistory(
      String profileId, SharedPreferences p) async {
    final histKey = StorageKeys.history(profileId);
    final raw = p.getString(histKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      var changed = false;
      final migrated = list.map<Map<String, dynamic>>((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final oldKey = map['key']?.toString() ?? '';
        if (oldKey.isEmpty) return map;
        final newKey = ContentKey.migrateLegacy(oldKey);
        if (newKey != oldKey) changed = true;
        return {...map, 'key': newKey};
      }).toList();
      if (changed) {
        await p.setString(histKey, jsonEncode(migrated));
        AppLogger.info(LogModule.sync,
            'Renamed ${migrated.length} history entries to underscore form');
      }
    } catch (e, st) {
      AppLogger.warning(LogModule.sync,
          'History migration failed; leaving local intact',
          error: e, stackTrace: st);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  static String? _readModeFromMeta(String? metaStr) {
    if (metaStr == null) return null;
    try {
      final m = jsonDecode(metaStr) as Map<String, dynamic>;
      return m['mode'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String _typeFromMode(String? mode) {
    switch (mode) {
      case 'series':
        // Watch progress entries with mode=series are *episodes* in
        // practice — series-level rows don't carry position/duration.
        return ContentKey.episode;
      case 'live':
        return ContentKey.live;
      case 'vod':
      default:
        return ContentKey.movie;
    }
  }
}
