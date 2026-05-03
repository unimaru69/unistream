import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import 'supabase_config.dart';

/// Fire-and-forget Supabase sync engine.
///
/// All public methods swallow errors so the app works perfectly offline.
/// Rapid mutations are debounced (500 ms) before being pushed.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  // ── Debounce queue ──
  Timer? _debounceTimer;
  final List<Future<void> Function()> _pendingOps = [];

  // ── Realtime subscriptions ──
  final List<RealtimeChannel> _channels = [];

  // ── Helpers ──

  String get profileHash => SupabaseConfig.profileHash;

  SupabaseClient? get _client => SupabaseConfig.client;

  bool get _ready {
    if (_client == null || profileHash.isEmpty || _client!.auth.currentSession == null) {
      return false;
    }
    // Cloud sync is intentionally ungated until the monetisation refactor
    // lands (single paid tier + 7-day trial — see auto-memory
    // `project_business_model.md`). Previously this checked
    // `FeatureAccess.canUse(Feature.cloudSync, account)`, which silently
    // disabled push/pull on accounts whose 14-day trial had elapsed —
    // including the team's own test account, leading to the "favorites
    // don't sync between iPhone, iPad, Apple TV" bug we hunted in TF.
    // tvOS never had this gate, so tvOS-pushed entries surfaced; iOS
    // pushes silently no-op'd, and the resulting one-way data flow
    // looked like total breakage.
    return true;
  }

  String? get _userId => SupabaseConfig.currentUserId;

  /// Schedule an operation with debounce batching (500 ms).
  void _enqueue(Future<void> Function() op) {
    _pendingOps.add(op);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), _flush);
  }

  Future<void> _flush() async {
    final ops = List<Future<void> Function()>.from(_pendingOps);
    _pendingOps.clear();
    for (final op in ops) {
      try {
        await op();
      } catch (e, st) {
        AppLogger.warning(LogModule.sync, 'Queued sync op failed', error: e, stackTrace: st);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Favorites
  // ══════════════════════════════════════════════════════════════════════════

  /// Push favorites to user_favorites. Each entry in [items] is keyed by
  /// item_key and contains the item JSON. [listType] is e.g. "favorites" or
  /// "watchlist".
  void pushFavorites(Map<String, dynamic> items, String listType) {
    if (!_ready) return;
    _enqueue(() async {
      final rows = items.entries.map((e) => {
            'user_id': _userId,
            'profile_hash': profileHash,
            'item_key': e.key,
            'item_json': jsonEncode(e.value),
            'list_type': listType,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'deleted': false,
          }).toList();
      await _client!
          .from('user_favorites')
          .upsert(rows, onConflict: 'user_id,profile_hash,item_key,list_type');
      AppLogger.debug(LogModule.sync, 'Pushed ${rows.length} favorites ($listType)');
    });
  }

  /// Pull favorites for the given [listType].
  /// Returns a map of item_key -> decoded item JSON.
  Future<Map<String, dynamic>> pullFavorites(String listType) async {
    if (!_ready) return {};
    try {
      final data = await _client!
          .from('user_favorites')
          .select()
          .eq('profile_hash', profileHash)
          .eq('list_type', listType)
          .eq('deleted', false);
      final result = <String, dynamic>{};
      for (final row in data) {
        final key = row['item_key'] as String;
        result[key] = jsonDecode(row['item_json'] as String);
      }
      AppLogger.debug(LogModule.sync, 'Pulled ${result.length} favorites ($listType)');
      return result;
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'pullFavorites failed', error: e, stackTrace: st);
      return {};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Collections
  // ══════════════════════════════════════════════════════════════════════════

  void pushCollections(List<Map<String, dynamic>> collections) {
    if (!_ready) return;
    _enqueue(() async {
      final rows = collections.map((c) => {
            'user_id': _userId,
            'profile_hash': profileHash,
            'collection_id': c['id'] ?? c['collection_id'],
            'name': c['name'] ?? '',
            'mode': c['mode'] ?? '',
            'items_json': jsonEncode(c['items'] ?? c['items_json'] ?? []),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'deleted': false,
          }).toList();
      await _client!
          .from('user_collections')
          .upsert(rows, onConflict: 'user_id,profile_hash,collection_id');
      AppLogger.debug(LogModule.sync, 'Pushed ${rows.length} collections');
    });
  }

  Future<List<Map<String, dynamic>>> pullCollections() async {
    if (!_ready) return [];
    try {
      final data = await _client!
          .from('user_collections')
          .select()
          .eq('profile_hash', profileHash)
          .eq('deleted', false);
      final result = data.map<Map<String, dynamic>>((row) => {
            'collection_id': row['collection_id'],
            'name': row['name'],
            'mode': row['mode'],
            'items': jsonDecode(row['items_json'] as String? ?? '[]'),
            'updated_at': row['updated_at'],
          }).toList();
      AppLogger.debug(LogModule.sync, 'Pulled ${result.length} collections');
      return result;
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'pullCollections failed', error: e, stackTrace: st);
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Watch Progress
  // ══════════════════════════════════════════════════════════════════════════

  void pushWatchProgress(String key, int posMs, int durMs, Map<String, dynamic> meta) {
    if (!_ready) return;
    _enqueue(() async {
      await _client!.from('user_watch_progress').upsert({
        'user_id': _userId,
        'profile_hash': profileHash,
        'content_key': key,
        'position_ms': posMs,
        'duration_ms': durMs,
        'meta_json': jsonEncode(meta),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,profile_hash,content_key');
      AppLogger.debug(LogModule.sync, 'Pushed watch progress for $key');
    });
  }

  Future<Map<String, dynamic>> pullWatchProgress() async {
    if (!_ready) return {};
    try {
      final data = await _client!
          .from('user_watch_progress')
          .select()
          .eq('profile_hash', profileHash);
      final result = <String, dynamic>{};
      for (final row in data) {
        result[row['content_key'] as String] = {
          'position_ms': row['position_ms'],
          'duration_ms': row['duration_ms'],
          'meta': jsonDecode(row['meta_json'] as String? ?? '{}'),
          'updated_at': row['updated_at'],
        };
      }
      AppLogger.debug(LogModule.sync, 'Pulled ${result.length} watch progress entries');
      return result;
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'pullWatchProgress failed', error: e, stackTrace: st);
      return {};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Settings
  // ══════════════════════════════════════════════════════════════════════════

  void pushSetting(String key, dynamic value) {
    if (!_ready) return;
    _enqueue(() async {
      await _client!.from('user_settings').upsert({
        'user_id': _userId,
        'profile_hash': profileHash,
        'setting_key': key,
        'value_json': jsonEncode(value),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,profile_hash,setting_key');
      AppLogger.debug(LogModule.sync, 'Pushed setting $key');
    });
  }

  Future<Map<String, dynamic>> pullSettings() async {
    if (!_ready) return {};
    try {
      final data = await _client!
          .from('user_settings')
          .select()
          .eq('profile_hash', profileHash);
      final result = <String, dynamic>{};
      for (final row in data) {
        result[row['setting_key'] as String] =
            jsonDecode(row['value_json'] as String);
      }
      AppLogger.debug(LogModule.sync, 'Pulled ${result.length} settings');
      return result;
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'pullSettings failed', error: e, stackTrace: st);
      return {};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Pull All (startup sync)
  // ══════════════════════════════════════════════════════════════════════════

  /// Pull all data from Supabase in parallel.
  /// Returns a record with favorites, watchlist, collections, and watch progress.
  Future<({
    Map<String, dynamic> favorites,
    Map<String, dynamic> watchlist,
    List<Map<String, dynamic>> collections,
    Map<String, dynamic> watchProgress,
  })> pullAll() async {
    if (!_ready) {
      return (
        favorites: <String, dynamic>{},
        watchlist: <String, dynamic>{},
        collections: <Map<String, dynamic>>[],
        watchProgress: <String, dynamic>{},
      );
    }
    final results = await Future.wait([
      pullFavorites('favorite'),
      pullFavorites('watchlist'),
      pullCollections(),
      pullWatchProgress(),
    ]);
    return (
      favorites: results[0] as Map<String, dynamic>,
      watchlist: results[1] as Map<String, dynamic>,
      collections: results[2] as List<Map<String, dynamic>>,
      watchProgress: results[3] as Map<String, dynamic>,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Realtime
  // ══════════════════════════════════════════════════════════════════════════

  /// Subscribe to realtime changes on all 4 tables for the current profile.
  /// [onRemoteChange] is called with the table name whenever a remote change
  /// is detected.
  void startRealtime(void Function(String table) onRemoteChange) {
    if (!_ready) return;
    stopRealtime();

    const tables = [
      'user_favorites',
      'user_collections',
      'user_watch_progress',
      'user_settings',
    ];

    for (final table in tables) {
      try {
        final channel = _client!
            .channel('sync_$table')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'profile_hash',
                value: profileHash,
              ),
              callback: (payload) {
                AppLogger.debug(LogModule.sync, 'Realtime change on $table');
                onRemoteChange(table);
              },
            )
            .subscribe();
        _channels.add(channel);
      } catch (e, st) {
        AppLogger.warning(
          LogModule.sync,
          'Failed to subscribe to $table realtime',
          error: e,
          stackTrace: st,
        );
      }
    }
    AppLogger.info(LogModule.sync, 'Realtime subscriptions started');
  }

  /// Unsubscribe from all realtime channels.
  void stopRealtime() {
    for (final channel in _channels) {
      try {
        _client?.removeChannel(channel);
      } catch (e, st) {
        AppLogger.warning(LogModule.sync, 'Error removing channel', error: e, stackTrace: st);
      }
    }
    _channels.clear();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Data Migration
  // ══════════════════════════════════════════════════════════════════════════

  /// Claim orphaned rows (pre-auth data with user_id IS NULL) for the given
  /// profile hash by setting user_id to the current authenticated user.
  Future<void> claimOrphanedData(String hash) async {
    if (_client == null || _client!.auth.currentSession == null) return;
    try {
      await _client!.rpc('claim_profile_data', params: {
        'p_profile_hash': hash,
      });
      AppLogger.info(LogModule.sync, 'Claimed orphaned data for hash: ${hash.substring(0, 8)}…');
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'claimOrphanedData failed (non-critical)',
          error: e, stackTrace: st);
    }
  }

  /// Cancel pending operations and stop realtime.
  void dispose() {
    _debounceTimer?.cancel();
    _pendingOps.clear();
    stopRealtime();
  }
}
