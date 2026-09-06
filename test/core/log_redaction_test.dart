import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:unistream/core/log_redaction.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/services/xtream_api.dart';

void main() {
  setUp(() {
    AppConfig.serverUrl = 'http://test.server:8080';
    AppConfig.username = 'testuser';
    AppConfig.password = 'sup3rs3cret';
  });

  group('redactCredentials — query string', () {
    test('masks username and password on the API URL', () {
      final redacted = redactCredentials(
          'GET failed for ${XtreamApi.baseUrl}&action=get_live_streams');

      expect(redacted.contains('sup3rs3cret'), isFalse);
      expect(redacted.contains('testuser'), isFalse);
      expect(
        redacted,
        'GET failed for http://test.server:8080/player_api.php'
        '?username=***&password=***&action=get_live_streams',
      );
    });

    test('is case-insensitive and stops at the parameter boundary', () {
      expect(
        redactCredentials('?USERNAME=bob&PASSWORD=hunter2&action=x'),
        '?USERNAME=***&PASSWORD=***&action=x',
      );
    });
  });

  group('redactCredentials — stream paths', () {
    test('masks the credential segments of every stream shape', () {
      for (final url in [
        XtreamApi.getLiveStreamUrl('42'),
        XtreamApi.getVodStreamUrl('456', 'mkv'),
        XtreamApi.getSeriesEpisodeUrl('789', 'ts'),
      ]) {
        final redacted = redactCredentials('playback error on $url');
        expect(redacted.contains('sup3rs3cret'), isFalse, reason: url);
        expect(redacted.contains('testuser'), isFalse, reason: url);
        expect(redacted.contains('/***/***/'), isTrue, reason: url);
      }
    });

    test('masks a timeshift URL and keeps the rest of the path', () {
      expect(
        redactCredentials(
            'http://test.server:8080/timeshift/testuser/sup3rs3cret/60/2026-01-02:20-30/42.ts'),
        'http://test.server:8080/timeshift/***/***/60/2026-01-02:20-30/42.ts',
      );
    });
  });

  group('redactCredentials — literal fallback', () {
    test('catches a password in a shape the patterns do not know', () {
      expect(
        redactCredentials('auth rejected for testuser / sup3rs3cret'),
        'auth rejected for *** / ***',
      );
    });

    test('leaves a very short credential alone rather than shredding text', () {
      AppConfig.username = 'ab';
      AppConfig.password = 'cd';
      expect(
        redactCredentials('abcd: cannot decode subtitle track'),
        'abcd: cannot decode subtitle track',
      );
    });

    test('leaves ordinary diagnostics untouched', () {
      const msg = 'SocketException: Connection reset by peer, port = 51234';
      expect(redactCredentials(msg), msg);
    });

    test('handles the empty string', () {
      expect(redactCredentials(''), '');
    });
  });

  group('redactBreadcrumb', () {
    test('scrubs the message and nested data values', () {
      final crumb = redactBreadcrumb(Breadcrumb(
        message: 'play ${XtreamApi.getVodStreamUrl('456', 'mkv')}',
        data: {
          'url': XtreamApi.getLiveStreamUrl('42'),
          'nested': {'u': 'testuser'},
          'list': [XtreamApi.getVodStreamUrl('1', 'mp4')],
          'count': 3,
        },
      ))!;

      expect(crumb.message!.contains('sup3rs3cret'), isFalse);
      expect(crumb.data!['url'].toString().contains('sup3rs3cret'), isFalse);
      expect((crumb.data!['nested'] as Map)['u'], '***');
      expect((crumb.data!['list'] as List).first.toString().contains('sup3rs3cret'),
          isFalse);
      // Non-string values survive unchanged.
      expect(crumb.data!['count'], 3);
    });

    test('passes null through', () {
      expect(redactBreadcrumb(null), isNull);
    });
  });

  group('redactSentryEvent', () {
    test('scrubs the message, the exception value and attached breadcrumbs', () {
      final event = redactSentryEvent(SentryEvent(
        message: SentryMessage('loadStreams failed for ${XtreamApi.baseUrl}'),
        exceptions: [
          SentryException(
            type: 'ClientException',
            value: 'Connection closed: ${XtreamApi.getVodStreamUrl('9', 'mkv')}',
          ),
        ],
        breadcrumbs: [Breadcrumb(message: XtreamApi.getLiveStreamUrl('42'))],
      ))!;

      expect(event.message!.formatted.contains('sup3rs3cret'), isFalse);
      expect(event.exceptions!.single.value!.contains('sup3rs3cret'), isFalse);
      expect(event.breadcrumbs!.single.message!.contains('sup3rs3cret'), isFalse);
      // The diagnostic value is preserved.
      expect(event.exceptions!.single.type, 'ClientException');
      expect(event.exceptions!.single.value, contains('Connection closed'));
    });
  });
}
