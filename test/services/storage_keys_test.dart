import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/core/storage_keys.dart';

void main() {
  group('StorageKeys constants', () {
    test('window geometry keys', () {
      expect(StorageKeys.windowX, 'window_x');
      expect(StorageKeys.windowY, 'window_y');
      expect(StorageKeys.windowW, 'window_w');
      expect(StorageKeys.windowH, 'window_h');
    });

    test('sidebar key', () {
      expect(StorageKeys.sidebarWidth, 'sidebar_width');
    });

    test('theme key', () {
      expect(StorageKeys.themeMode, 'theme_mode');
    });

    test('language preference keys', () {
      expect(StorageKeys.prefAudioLang, 'pref_audio_lang');
      expect(StorageKeys.prefSubLang, 'pref_sub_lang');
    });

    test('profile keys without userId', () {
      expect(StorageKeys.profilesList(), 'profiles_list');
      expect(StorageKeys.activeProfile(), 'active_profile');
    });

    test('profile keys with userId', () {
      expect(StorageKeys.profilesList('abc-123'), 'u_abc-123_profiles_list');
      expect(StorageKeys.activeProfile('abc-123'), 'u_abc-123_active_profile');
    });

    test('legacy config keys', () {
      expect(StorageKeys.cfgServer, 'cfg_server');
      expect(StorageKeys.cfgUser, 'cfg_user');
      expect(StorageKeys.cfgPass, 'cfg_pass');
    });
  });

  group('StorageKeys profile-scoped methods', () {
    const profileId = 'test-profile-123';

    test('favorites returns expected format', () {
      expect(StorageKeys.favorites(profileId), 'favorites_test-profile-123');
    });

    test('watchlist returns expected format', () {
      expect(StorageKeys.watchlist(profileId), 'watchlist_test-profile-123');
    });

    test('collections returns expected format', () {
      expect(StorageKeys.collections(profileId), 'collections_test-profile-123');
    });

    test('gridView returns expected format', () {
      expect(
        StorageKeys.gridView(profileId, 'live'),
        'gridView_test-profile-123_live',
      );
    });

    test('sortMode returns expected format', () {
      expect(
        StorageKeys.sortMode(profileId, 'vod'),
        'sortMode_test-profile-123_vod',
      );
    });

    test('wpPosition returns expected format', () {
      expect(
        StorageKeys.wpPosition(profileId, 'ch42'),
        'wp_test-profile-123_s_ch42',
      );
    });

    test('wpDuration returns expected format', () {
      expect(
        StorageKeys.wpDuration(profileId, 'ch42'),
        'wp_test-profile-123_d_ch42',
      );
    });

    test('wpMeta returns expected format', () {
      expect(
        StorageKeys.wpMeta(profileId, 'ch42'),
        'wp_test-profile-123_meta_ch42',
      );
    });

    test('wpPositionPrefix returns expected format', () {
      expect(
        StorageKeys.wpPositionPrefix(profileId),
        'wp_test-profile-123_s_',
      );
    });

    test('wpDurationPrefix returns expected format', () {
      expect(
        StorageKeys.wpDurationPrefix(profileId),
        'wp_test-profile-123_d_',
      );
    });

    test('wpPrefix returns expected format', () {
      expect(StorageKeys.wpPrefix(profileId), 'wp_test-profile-123_');
    });

    test('history returns expected format', () {
      expect(
        StorageKeys.history(profileId),
        'wp_test-profile-123_history',
      );
    });

    test('subtitleFontSize returns expected format', () {
      expect(
        StorageKeys.subtitleFontSize(profileId),
        'sub_test-profile-123_fontSize',
      );
    });

    test('subtitleColor returns expected format', () {
      expect(
        StorageKeys.subtitleColor(profileId),
        'sub_test-profile-123_color',
      );
    });

    test('subtitleBgOpacity returns expected format', () {
      expect(
        StorageKeys.subtitleBgOpacity(profileId),
        'sub_test-profile-123_bgOpacity',
      );
    });
  });

  group('StorageKeys with different profile IDs', () {
    test('different profiles produce different keys', () {
      expect(StorageKeys.favorites('a'), isNot(StorageKeys.favorites('b')));
      expect(StorageKeys.wpPrefix('a'), isNot(StorageKeys.wpPrefix('b')));
    });

    test('empty profile ID still produces valid key', () {
      expect(StorageKeys.favorites(''), 'favorites_');
      expect(StorageKeys.wpPrefix(''), 'wp__');
    });
  });
}
