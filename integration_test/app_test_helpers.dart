import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/models/profile.dart';

// ---------------------------------------------------------------------------
// Mock HTTP overrides
// ---------------------------------------------------------------------------

/// A mock HTTP client that intercepts all outgoing requests and returns
/// pre-configured responses based on URL patterns.
class MockHttpOverrides extends HttpOverrides {
  final Map<String, MockHttpResponse> _responses = {};

  void addResponse(String urlPattern, {int status = 200, required String body}) {
    _responses[urlPattern] = MockHttpResponse(status, body);
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient(_responses);
  }
}

class MockHttpResponse {
  final int statusCode;
  final String body;
  MockHttpResponse(this.statusCode, this.body);
}

class _MockHttpClient implements HttpClient {
  final Map<String, MockHttpResponse> responses;
  _MockHttpClient(this.responses);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest(url, responses);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpClientRequest(url, responses);
  }

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}
  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {}
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) {}
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}
  @override
  void close({bool force = false}) {}
  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) {}
  @override
  set findProxy(String Function(Uri url)? f) {}
  @override
  set keyLog(Function(String line)? callback) {}
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => getUrl(Uri(host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => getUrl(url);
  @override
  Future<HttpClientRequest> get(String host, int port, String path) => getUrl(Uri(host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> head(String host, int port, String path) => getUrl(Uri(host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> headUrl(Uri url) => getUrl(url);
  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) => getUrl(Uri(host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => getUrl(Uri(host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => getUrl(url);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) => getUrl(Uri(host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> postUrl(Uri url) => getUrl(url);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) => getUrl(Uri(host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> putUrl(Uri url) => getUrl(url);
}

class _MockHttpClientRequest implements HttpClientRequest {
  final Uri _url;
  final Map<String, MockHttpResponse> _responses;

  _MockHttpClientRequest(this._url, this._responses);

  @override
  Future<HttpClientResponse> close() async {
    final urlStr = _url.toString();
    // Check patterns sorted by length (longest/most-specific first)
    final sorted = _responses.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in sorted) {
      if (urlStr.contains(entry.key)) {
        return _MockHttpClientResponse(entry.value);
      }
    }
    return _MockHttpClientResponse(MockHttpResponse(200, '{}'));
  }

  @override
  Encoding encoding = utf8;
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];
  @override
  Future<HttpClientResponse> get done => close();
  @override
  Future flush() async {}
  @override
  String get method => 'GET';
  @override
  Uri get uri => _url;
  @override
  void write(Object? object) {}
  @override
  void writeAll(Iterable objects, [String separator = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? object = '']) {}
  @override
  bool bufferOutput = true;
  @override
  int contentLength = -1;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
}

class _MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = [value.toString()];
  }

  @override
  String? value(String name) => _headers[name]?.first;
  @override
  List<String>? operator [](String name) => _headers[name];
  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override bool chunkedTransferEncoding = false;
  @override int contentLength = -1;
  @override ContentType? contentType;
  @override DateTime? date;
  @override DateTime? expires;
  @override String? host;
  @override DateTime? ifModifiedSince;
  @override bool persistentConnection = true;
  @override int? port;

  @override void clear() => _headers.clear();
  @override void noFolding(String name) {}
  @override void remove(String name, Object value) {}
  @override void removeAll(String name) {}
}

/// Mock HttpClientResponse. Extends `Stream<List<int>>` to match the
/// `HttpClientResponse` interface, delegating all stream methods to an
/// internal single-value stream.
class _MockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final MockHttpResponse _response;
  late final List<int> _bytes;

  _MockHttpClientResponse(this._response) {
    _bytes = utf8.encode(_response.body);
  }

  Stream<List<int>> get _stream => Stream.value(_bytes);

  @override
  int get statusCode => _response.statusCode;
  @override
  String get reasonPhrase => 'OK';

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  int get contentLength => _response.body.length;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => [];

  @override
  Future<Socket> detachSocket() => throw UnsupportedError('detachSocket');

  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  X509Certificate? get certificate => null;

  @override
  Future<HttpClientResponse> redirect(
          [String? method, Uri? url, bool? followLoops]) =>
      throw UnsupportedError('redirect');

  @override
  StreamSubscription<List<int>> listen(
      void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

// ---------------------------------------------------------------------------
// JSON responses for mock API
// ---------------------------------------------------------------------------

const String mockAuthSuccessJson = '''
{
  "user_info": {
    "auth": 1,
    "username": "testuser",
    "password": "testpass",
    "status": "Active"
  },
  "server_info": {
    "url": "http://test.server.com",
    "port": "8080",
    "https_port": "8443",
    "server_protocol": "http",
    "timezone": "Europe/Paris",
    "time_now": "2026-04-01 12:00:00",
    "timestamp_now": "1743508800"
  }
}
''';

const String mockAuthFailedJson = '''
{
  "user_info": {
    "auth": 0,
    "status": "Disabled"
  }
}
''';

const String mockLiveCategoriesJson = '''
[
  {"category_id": "1", "category_name": "News", "parent_id": 0},
  {"category_id": "2", "category_name": "Sports", "parent_id": 0},
  {"category_id": "3", "category_name": "Movies", "parent_id": 0}
]
''';

const String mockVodCategoriesJson = '''
[
  {"category_id": "10", "category_name": "Action", "parent_id": 0},
  {"category_id": "11", "category_name": "Comedy", "parent_id": 0}
]
''';

const String mockSeriesCategoriesJson = '''
[
  {"category_id": "20", "category_name": "Drama", "parent_id": 0},
  {"category_id": "21", "category_name": "Thriller", "parent_id": 0}
]
''';

const String mockLiveStreamsJson = '''
[
  {"stream_id": 101, "name": "CNN Live", "stream_icon": "", "category_id": "1"},
  {"stream_id": 102, "name": "BBC News", "stream_icon": "", "category_id": "1"},
  {"stream_id": 103, "name": "ESPN", "stream_icon": "", "category_id": "2"}
]
''';

const String mockVodStreamsJson = '''
[
  {"stream_id": 201, "name": "Action Movie 1", "stream_icon": "", "container_extension": "mp4", "category_id": "10"},
  {"stream_id": 202, "name": "Comedy Film", "stream_icon": "", "container_extension": "mkv", "category_id": "11"}
]
''';

const String mockSeriesJson = '''
[
  {"series_id": 301, "name": "Drama Series", "cover": "", "category_id": "20"},
  {"series_id": 302, "name": "Thriller Show", "cover": "", "category_id": "21"}
]
''';

// ---------------------------------------------------------------------------
// Helper to setup mock HTTP overrides with standard responses
// ---------------------------------------------------------------------------

MockHttpOverrides setupMockHttp() {
  final overrides = MockHttpOverrides();
  // Category endpoints (must be registered before shorter patterns)
  overrides.addResponse('action=get_live_categories', body: mockLiveCategoriesJson);
  overrides.addResponse('action=get_vod_categories', body: mockVodCategoriesJson);
  overrides.addResponse('action=get_series_categories', body: mockSeriesCategoriesJson);
  // Stream endpoints
  overrides.addResponse('action=get_live_streams', body: mockLiveStreamsJson);
  overrides.addResponse('action=get_vod_streams', body: mockVodStreamsJson);
  overrides.addResponse('action=get_series', body: mockSeriesJson);
  // Auth endpoint (base URL without action -- matches last due to shortest pattern)
  overrides.addResponse('player_api.php', body: mockAuthSuccessJson);
  return overrides;
}

// ---------------------------------------------------------------------------
// Pre-configure AppConfig for tests
// ---------------------------------------------------------------------------

/// Set up AppConfig as if no profile is saved (first-run).
void setupAppConfigEmpty() {
  AppConfig.serverUrl = '';
  AppConfig.username = '';
  AppConfig.password = '';
  AppConfig.activeProfileId = '';
  AppConfig.profiles = [];
}

/// Set up AppConfig as if a profile is already configured.
void setupAppConfigWithProfile() {
  AppConfig.serverUrl = 'http://test.server.com:8080';
  AppConfig.username = 'testuser';
  AppConfig.password = 'testpass';
  AppConfig.activeProfileId = 'test1';
  AppConfig.profiles = [
    Profile(
      id: 'test1',
      name: 'Test Server',
      serverUrl: 'http://test.server.com:8080',
      username: 'testuser',
      password: 'testpass',
    ),
  ];
}

// ---------------------------------------------------------------------------
// Test app wrapper
// ---------------------------------------------------------------------------

/// Build a full app widget with localization and Riverpod, starting from
/// the given [home] widget.
Widget buildTestApp({
  required Widget home,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

/// Pump frames for [duration], useful for animations.
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = tester.binding.clock.now().add(duration);
  while (tester.binding.clock.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
