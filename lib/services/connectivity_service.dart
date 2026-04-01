import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:unistream/core/logger.dart';
import '../models/app_config.dart';

/// Connectivity status exposed to the UI.
enum ConnectivityStatus { online, offline, reconnecting }

/// Monitors network connectivity and verifies actual API reachability.
class ConnectivityService {
  final Connectivity _connectivity;
  final http.Client? _httpClient;

  /// For testing: injectable connectivity instance and HTTP client.
  ConnectivityService({
    Connectivity? connectivity,
    http.Client? httpClient,
  })  : _connectivity = connectivity ?? Connectivity(),
        _httpClient = httpClient;

  /// Returns a debounced stream of [ConnectivityStatus].
  Stream<ConnectivityStatus> get statusStream {
    ConnectivityStatus? lastEmitted;

    return _connectivity.onConnectivityChanged
        .transform(_Debounce(const Duration(milliseconds: 300)))
        .asyncMap((results) async {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) {
        return ConnectivityStatus.offline;
      }
      // We have network; verify actual API reachability.
      return ConnectivityStatus.reconnecting;
    }).asyncExpand((status) async* {
      if (status == ConnectivityStatus.offline) {
        yield ConnectivityStatus.offline;
      } else {
        // Emit reconnecting immediately, then check reachability.
        yield ConnectivityStatus.reconnecting;
        final reachable = await _checkReachability();
        yield reachable ? ConnectivityStatus.online : ConnectivityStatus.offline;
      }
    }).where((status) {
      // Deduplicate consecutive identical statuses.
      if (status == lastEmitted) return false;
      lastEmitted = status;
      return true;
    });
  }

  /// One-shot check of current connectivity status.
  Future<ConnectivityStatus> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (!hasNetwork) return ConnectivityStatus.offline;
    final reachable = await _checkReachability();
    return reachable ? ConnectivityStatus.online : ConnectivityStatus.offline;
  }

  /// Lightweight reachability check against the configured server.
  Future<bool> _checkReachability() async {
    try {
      final serverUrl = AppConfig.serverUrl;
      if (serverUrl.isEmpty) return true; // No server configured yet
      final client = _httpClient ?? http.Client();
      final shouldClose = _httpClient == null;
      try {
        final response = await client
            .head(Uri.parse(serverUrl))
            .timeout(const Duration(seconds: 5));
        return response.statusCode < 500;
      } finally {
        if (shouldClose) client.close();
      }
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } catch (e) {
      AppLogger.warning(LogModule.api, 'Reachability check failed', error: e);
      return false;
    }
  }
}

/// Stream transformer that debounces events by [duration].
class _Debounce<T> extends StreamTransformerBase<T, T> {
  final Duration duration;
  const _Debounce(this.duration);

  @override
  Stream<T> bind(Stream<T> stream) {
    Timer? timer;
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;

    controller = StreamController<T>(
      onListen: () {
        subscription = stream.listen(
          (data) {
            timer?.cancel();
            timer = Timer(duration, () => controller.add(data));
          },
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            controller.close();
          },
        );
      },
      onCancel: () {
        timer?.cancel();
        subscription?.cancel();
      },
    );

    return controller.stream;
  }
}
