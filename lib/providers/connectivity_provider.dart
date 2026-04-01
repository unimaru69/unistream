import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

/// The [ConnectivityService] singleton, overridable in tests.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Streams the current [ConnectivityStatus] to all consumers.
/// Starts with a one-shot check, then listens for changes.
final connectivityProvider = StreamProvider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);

  return () async* {
    // Emit current status immediately.
    yield await service.checkNow();
    // Then listen for changes.
    yield* service.statusStream;
  }();
});
