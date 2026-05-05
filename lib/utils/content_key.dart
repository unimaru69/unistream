/// Canonical content-key format shared between Flutter (this app) and the
/// tvOS native app. Both platforms must use the same string for any given
/// item or cross-device sync silently splits the same record into two
/// different rows on Supabase (one per platform).
///
/// Format: `<type>_<id>`. Examples:
///   * `vod_12345`     — a movie / VOD item (`stream_id == 12345`)
///   * `ep_67890`      — a single TV episode (`episode_id == 67890`)
///   * `series_1234`   — a series-level entity (`series_id == 1234`)
///   * `live_42`       — a live channel (`stream_id == 42`)
///
/// Prefixes:
///   * `vod` — chosen over "movie" to match tvOS's existing convention
///     (`vod_<id>` was already what the native app pushed to the
///     `user_watch_progress.content_key` column).
///   * `ep`  — episode of a series (per-episode resume key).
///   * `series` — used for the series-level history entry shown when the
///     user opened a series page without playing yet.
///   * `live` — live TV channel.
///
/// Pre-build-13 Flutter used a colon-separated form (`vod:12345`,
/// `series:67`) for favourites + history, and stored watch-progress under
/// the bare `<id>` (no prefix). Build 13 migrates everything to the
/// underscore form via `ContentKeyMigration`.
class ContentKey {
  ContentKey._();

  static const movie = 'vod';
  static const episode = 'ep';
  static const series = 'series';
  static const live = 'live';

  static const _allTypes = {movie, episode, series, live};

  /// Build a canonical key. `id` is the bare id from the IPTV provider.
  static String make(String type, String id) {
    assert(_allTypes.contains(type), 'Unknown content type: $type');
    return '${type}_$id';
  }

  /// Parse a canonical key back into `(type, id)`. Returns null when the
  /// key is in the legacy colon form (`vod:12345`) or bare (`12345`) —
  /// helps the migration distinguish what still needs converting.
  static (String type, String id)? parse(String key) {
    final i = key.indexOf('_');
    if (i <= 0) return null;
    final t = key.substring(0, i);
    if (!_allTypes.contains(t)) return null;
    return (t, key.substring(i + 1));
  }

  /// Convert a Flutter-mode string ("vod"/"series"/"live") to the type
  /// code used inside content keys. The series-mode is special: when
  /// the user *played* something in series mode, the played item is an
  /// episode (`ep`), not the series-level entity.
  static String typeForPlayMode(String mode) {
    switch (mode) {
      case 'series':
        return episode;
      case 'live':
        return live;
      case 'vod':
      default:
        return movie;
    }
  }

  /// Convert a legacy colon key (`vod:12345` / `series:67`) to the new
  /// underscore form (`vod_12345` / `series_67`). Pass-through for keys
  /// already in the new format.
  static String migrateLegacy(String key) {
    final m = RegExp(r'^(vod|series|live|ep):(.+)$').firstMatch(key);
    if (m == null) return key;
    return '${m.group(1)}_${m.group(2)}';
  }

  /// Strip a known prefix and return the bare id. Used for favourites,
  /// where tvOS stores the bare id and Flutter used to store
  /// `<mode>:<id>`. Migration walks the local list and rewrites each
  /// key through this function.
  static String stripToBareId(String key) {
    // Underscore-form first (post-migration safety net).
    final under = parse(key);
    if (under != null) return under.$2;
    // Legacy colon form.
    final m = RegExp(r'^(vod|series|live|ep):(.+)$').firstMatch(key);
    return m != null ? m.group(2)! : key;
  }
}
