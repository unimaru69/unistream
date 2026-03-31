/// Centralized SharedPreferences key definitions for UniStream.
///
/// Simple keys are static constants.
/// Profile-scoped keys are static methods that take a [profileId].
/// Compound keys (watch progress, subtitle settings) take additional parameters.
class StorageKeys {
  StorageKeys._();

  // ── Window geometry (desktop) ──
  static const windowX = 'window_x';
  static const windowY = 'window_y';
  static const windowW = 'window_w';
  static const windowH = 'window_h';

  // ── Locale ──
  static const locale = 'app_locale';

  // ── Sidebar ──
  static const sidebarWidth = 'sidebar_width';

  // ── Theme ──
  static const themeMode = 'theme_mode';

  // ── Language preferences ──
  static const prefAudioLang = 'pref_audio_lang';
  static const prefSubLang = 'pref_sub_lang';

  // ── Profiles ──
  static const profilesList = 'profiles_list';
  static const activeProfile = 'active_profile';

  // ── Legacy config keys (migration only) ──
  static const cfgServer = 'cfg_server';
  static const cfgUser = 'cfg_user';
  static const cfgPass = 'cfg_pass';

  // ── Profile-scoped: favorites ──
  static String favorites(String profileId) => 'favorites_$profileId';

  // ── Profile-scoped: watchlist ──
  static String watchlist(String profileId) => 'watchlist_$profileId';

  // ── Profile-scoped: collections ──
  static String collections(String profileId) => 'collections_$profileId';

  // ── Profile-scoped: grid view preference (per mode) ──
  static String gridView(String profileId, String modeKey) =>
      'gridView_${profileId}_$modeKey';

  // ── Profile-scoped: sort mode preference (per mode) ──
  static String sortMode(String profileId, String modeKey) =>
      'sortMode_${profileId}_$modeKey';

  // ── Profile-scoped: watch progress prefix ──
  static String _wpPrefix(String profileId) => 'wp_${profileId}_';

  /// Watch progress: saved position in seconds.
  static String wpPosition(String profileId, String key) =>
      '${_wpPrefix(profileId)}s_$key';

  /// Watch progress: total duration in seconds.
  static String wpDuration(String profileId, String key) =>
      '${_wpPrefix(profileId)}d_$key';

  /// Watch progress: item metadata (name, cover, url, mode).
  static String wpMeta(String profileId, String key) =>
      '${_wpPrefix(profileId)}meta_$key';

  /// Watch progress: prefix for iterating keys.
  static String wpPositionPrefix(String profileId) =>
      '${_wpPrefix(profileId)}s_';

  static String wpDurationPrefix(String profileId) =>
      '${_wpPrefix(profileId)}d_';

  /// Watch progress: full prefix for a profile (used during export/import).
  static String wpPrefix(String profileId) => _wpPrefix(profileId);

  // ── Profile-scoped: history ──
  static String history(String profileId) => '${_wpPrefix(profileId)}history';

  // ── Profile-scoped: subtitle settings ──
  static String _subPrefix(String profileId) => 'sub_$profileId';

  static String subtitleFontSize(String profileId) =>
      '${_subPrefix(profileId)}_fontSize';

  static String subtitleColor(String profileId) =>
      '${_subPrefix(profileId)}_color';

  static String subtitleBgOpacity(String profileId) =>
      '${_subPrefix(profileId)}_bgOpacity';
}
