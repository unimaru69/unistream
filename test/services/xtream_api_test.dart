import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:unistream/services/xtream_api.dart';
import 'package:unistream/models/app_config.dart';

class MockClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

/// A [Random] that always returns 0 for deterministic delay tests.
class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0.0;
  @override
  bool nextBool() => false;
}

void main() {
  late MockClient mockClient;

  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  setUp(() {
    mockClient = MockClient();
    // Use zero-jitter random for deterministic timing in tests.
    httpGetRandom = _ZeroRandom();
  });

  tearDown(() {
    httpGetRandom = Random();
  });

  group('httpGet() exponential backoff', () {
    test('returns response on first successful call', () async {
      when(() => mockClient.get(any()))
          .thenAnswer((_) async => http.Response('ok', 200));

      final resp = await httpGet(
        'http://example.com',
        client: mockClient,
      );
      expect(resp.statusCode, 200);
      expect(resp.body, 'ok');
      verify(() => mockClient.get(any())).called(1);
    });

    test('retries on SocketException then succeeds', () async {
      var callCount = 0;
      when(() => mockClient.get(any())).thenAnswer((_) async {
        callCount++;
        if (callCount < 3) throw const SocketException('Connection refused');
        return http.Response('recovered', 200);
      });

      final resp = await httpGet(
        'http://example.com',
        client: mockClient,
        maxRetries: 3,
      );
      expect(resp.body, 'recovered');
      expect(callCount, 3);
    });

    test('retries on TimeoutException then succeeds', () async {
      var callCount = 0;
      when(() => mockClient.get(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw TimeoutException('timed out');
        return http.Response('ok', 200);
      });

      final resp = await httpGet(
        'http://example.com',
        client: mockClient,
      );
      expect(resp.body, 'ok');
      expect(callCount, 2);
    });

    test('retries on HandshakeException then succeeds', () async {
      var callCount = 0;
      when(() => mockClient.get(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw const HandshakeException('TLS handshake failed');
        }
        return http.Response('ok', 200);
      });

      final resp = await httpGet(
        'http://example.com',
        client: mockClient,
      );
      expect(resp.body, 'ok');
      expect(callCount, 2);
    });

    test('retries on ClientException then succeeds', () async {
      var callCount = 0;
      when(() => mockClient.get(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw http.ClientException('Connection closed');
        }
        return http.Response('ok', 200);
      });

      final resp = await httpGet(
        'http://example.com',
        client: mockClient,
      );
      expect(resp.body, 'ok');
      expect(callCount, 2);
    });

    test('throws after maxRetries exhausted (SocketException)', () async {
      when(() => mockClient.get(any()))
          .thenThrow(const SocketException('fail'));

      expect(
        () => httpGet(
          'http://example.com',
          client: mockClient,
          maxRetries: 3,
        ),
        throwsA(isA<SocketException>()),
      );
    });

    test('throws after maxRetries exhausted (TimeoutException)', () async {
      when(() => mockClient.get(any()))
          .thenThrow(TimeoutException('fail'));

      expect(
        () => httpGet(
          'http://example.com',
          client: mockClient,
          maxRetries: 2,
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('throws after maxRetries exhausted (HandshakeException)', () async {
      when(() => mockClient.get(any()))
          .thenThrow(const HandshakeException('TLS error'));

      expect(
        () => httpGet(
          'http://example.com',
          client: mockClient,
          maxRetries: 2,
        ),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('onRetry callback is invoked on each retry', () async {
      final retryLog = <int>[];
      var callCount = 0;
      when(() => mockClient.get(any())).thenAnswer((_) async {
        callCount++;
        if (callCount <= 2) throw const SocketException('fail');
        return http.Response('ok', 200);
      });

      await httpGet(
        'http://example.com',
        client: mockClient,
        maxRetries: 3,
        onRetry: (attempt, error) => retryLog.add(attempt),
      );

      expect(retryLog, [0, 1]);
    });

    test('onRetry receives correct error types', () async {
      final errors = <Type>[];
      var callCount = 0;
      when(() => mockClient.get(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw const SocketException('fail');
        if (callCount == 2) throw TimeoutException('fail');
        return http.Response('ok', 200);
      });

      await httpGet(
        'http://example.com',
        client: mockClient,
        maxRetries: 3,
        onRetry: (attempt, error) => errors.add(error.runtimeType),
      );

      expect(errors, [SocketException, TimeoutException]);
    });

    test('exponential delay pattern is correct with zero jitter', () async {
      // With _ZeroRandom, delays should be: 1000ms, 2000ms (capped at 10000)
      // We verify indirectly by measuring elapsed time across 3 failures.
      final stopwatch = Stopwatch()..start();
      when(() => mockClient.get(any()))
          .thenThrow(const SocketException('fail'));

      try {
        await httpGet(
          'http://example.com',
          client: mockClient,
          maxRetries: 3,
        );
      } on SocketException {
        // expected
      }
      stopwatch.stop();

      // 2 delays: 1000ms + 2000ms = 3000ms total (with zero jitter).
      // Allow some tolerance for test execution overhead.
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(2800));
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('maxRetries parameter is respected', () async {
      var callCount = 0;
      when(() => mockClient.get(any())).thenAnswer((_) async {
        callCount++;
        throw const SocketException('fail');
      });

      try {
        await httpGet(
          'http://example.com',
          client: mockClient,
          maxRetries: 5,
        );
      } on SocketException {
        // expected
      }
      expect(callCount, 5);
    });
  });
  group('ApiErrorKey enum', () {
    test('has all expected values', () {
      expect(ApiErrorKey.values, containsAll([
        ApiErrorKey.network,
        ApiErrorKey.timeout,
        ApiErrorKey.client,
        ApiErrorKey.format,
        ApiErrorKey.auth,
        ApiErrorKey.generic,
      ]));
      expect(ApiErrorKey.values.length, 6);
    });
  });

  group('XtreamApi.errorKey()', () {
    test('SocketException maps to network', () {
      expect(
        XtreamApi.errorKey(Exception('SocketException: Connection refused')),
        ApiErrorKey.network,
      );
    });

    test('Failed host lookup maps to network', () {
      expect(
        XtreamApi.errorKey(Exception('Failed host lookup: example.com')),
        ApiErrorKey.network,
      );
    });

    test('TimeoutException maps to timeout', () {
      expect(
        XtreamApi.errorKey(Exception('TimeoutException after 0:00:15')),
        ApiErrorKey.timeout,
      );
    });

    test('ClientException maps to client', () {
      expect(
        XtreamApi.errorKey(Exception('ClientException: Connection closed')),
        ApiErrorKey.client,
      );
    });

    test('FormatException maps to format', () {
      expect(
        XtreamApi.errorKey(Exception('FormatException: Unexpected character')),
        ApiErrorKey.format,
      );
    });

    test('401 maps to auth', () {
      expect(
        XtreamApi.errorKey(Exception('HTTP 401 Unauthorized')),
        ApiErrorKey.auth,
      );
    });

    test('auth keyword maps to auth', () {
      expect(
        XtreamApi.errorKey(Exception('auth failed')),
        ApiErrorKey.auth,
      );
    });

    test('unknown error maps to generic', () {
      expect(
        XtreamApi.errorKey(Exception('Something unexpected happened')),
        ApiErrorKey.generic,
      );
    });

    test('empty string maps to generic', () {
      expect(XtreamApi.errorKey(''), ApiErrorKey.generic);
    });
  });

  group('XtreamApi URL construction', () {
    setUp(() {
      AppConfig.serverUrl = 'http://test.server:8080';
      AppConfig.username = 'testuser';
      AppConfig.password = 'testpass';
      AppConfig.activeProfileId = 'test_profile';
    });

    test('baseUrl contains credentials', () {
      expect(
        XtreamApi.baseUrl,
        'http://test.server:8080/player_api.php?username=testuser&password=testpass',
      );
    });

    test('getLiveStreamUrl builds correct URL', () {
      expect(
        XtreamApi.getLiveStreamUrl('123'),
        'http://test.server:8080/live/testuser/testpass/123.m3u8',
      );
    });

    test('getVodStreamUrl builds correct URL with extension', () {
      expect(
        XtreamApi.getVodStreamUrl('456', 'mp4'),
        'http://test.server:8080/movie/testuser/testpass/456.mp4',
      );
    });

    test('getSeriesEpisodeUrl builds correct URL with extension', () {
      expect(
        XtreamApi.getSeriesEpisodeUrl('789', 'mkv'),
        'http://test.server:8080/series/testuser/testpass/789.mkv',
      );
    });
  });

  group('XtreamApi.channelHasCatchup()', () {
    test('returns true when tv_archive is 1', () {
      expect(XtreamApi.channelHasCatchup({'tv_archive': 1}), true);
    });

    test('returns true when tv_archive is string "1"', () {
      expect(XtreamApi.channelHasCatchup({'tv_archive': '1'}), true);
    });

    test('returns false when tv_archive is 0', () {
      expect(XtreamApi.channelHasCatchup({'tv_archive': 0}), false);
    });

    test('returns false when tv_archive is missing', () {
      expect(XtreamApi.channelHasCatchup({}), false);
    });
  });

  group('XtreamApi.channelArchiveDays()', () {
    test('returns integer days from string', () {
      expect(XtreamApi.channelArchiveDays({'tv_archive_duration': '7'}), 7);
    });

    test('returns integer days from int', () {
      expect(XtreamApi.channelArchiveDays({'tv_archive_duration': 14}), 14);
    });

    test('returns 0 when missing', () {
      expect(XtreamApi.channelArchiveDays({}), 0);
    });

    test('returns 0 for non-numeric', () {
      expect(XtreamApi.channelArchiveDays({'tv_archive_duration': 'abc'}), 0);
    });
  });

  group('XtreamApi EPG cache', () {
    setUp(() {
      XtreamApi.clearEpgCache();
    });

    test('cache starts empty', () {
      expect(XtreamApi.epgCacheSize, 0);
    });

    test('clearEpgCache resets cache', () {
      // We can only test via the public API
      XtreamApi.clearEpgCache();
      expect(XtreamApi.epgCacheSize, 0);
    });

    test('getCachedEpgNow returns null for uncached stream', () {
      expect(XtreamApi.getCachedEpgNow('999'), isNull);
    });
  });

  group('XtreamApi.friendlyError() (deprecated)', () {
    test('returns French string for network error', () {
      // ignore: deprecated_member_use_from_same_package
      expect(
        XtreamApi.friendlyError(Exception('SocketException')),
        'Connexion impossible.',
      );
    });

    test('returns French string for timeout error', () {
      // ignore: deprecated_member_use_from_same_package
      expect(
        XtreamApi.friendlyError(Exception('TimeoutException')),
        'Le serveur ne répond pas.',
      );
    });

    test('returns French string for generic error', () {
      // ignore: deprecated_member_use_from_same_package
      expect(
        XtreamApi.friendlyError(Exception('unknown')),
        'Une erreur est survenue.',
      );
    });
  });
}
