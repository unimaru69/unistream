import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/providers/connectivity_provider.dart';
import 'package:unistream/services/connectivity_service.dart';

/// A fake [ConnectivityService] that exposes a controller for testing.
class FakeConnectivityService extends ConnectivityService {
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _currentStatus;

  FakeConnectivityService({ConnectivityStatus initial = ConnectivityStatus.online})
      : _currentStatus = initial;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  @override
  Future<ConnectivityStatus> checkNow() async => _currentStatus;

  void emit(ConnectivityStatus status) {
    _currentStatus = status;
    _controller.add(status);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('connectivityProvider', () {
    test('emits initial status from checkNow', () async {
      final fake = FakeConnectivityService(initial: ConnectivityStatus.online);
      final container = ProviderContainer(overrides: [
        connectivityServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(() {
        container.dispose();
        fake.dispose();
      });

      // Listen to start the stream
      final sub = container.listen(connectivityProvider, (_, __) {});

      // Wait for the initial async emission
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final value = container.read(connectivityProvider);
      expect(value.valueOrNull, ConnectivityStatus.online);

      sub.close();
    });

    test('emits offline when service emits offline', () async {
      final fake = FakeConnectivityService(initial: ConnectivityStatus.online);
      final container = ProviderContainer(overrides: [
        connectivityServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(() {
        container.dispose();
        fake.dispose();
      });

      final statuses = <ConnectivityStatus>[];
      final sub = container.listen(connectivityProvider, (_, next) {
        if (next.hasValue) statuses.add(next.value!);
      });

      // Wait for initial emission
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Emit offline
      fake.emit(ConnectivityStatus.offline);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(statuses, contains(ConnectivityStatus.offline));

      sub.close();
    });

    test('transitions offline -> online', () async {
      final fake = FakeConnectivityService(initial: ConnectivityStatus.offline);
      final container = ProviderContainer(overrides: [
        connectivityServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(() {
        container.dispose();
        fake.dispose();
      });

      final statuses = <ConnectivityStatus>[];
      final sub = container.listen(connectivityProvider, (_, next) {
        if (next.hasValue) statuses.add(next.value!);
      });

      // Wait for initial
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Transition to online
      fake.emit(ConnectivityStatus.online);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(statuses, contains(ConnectivityStatus.online));
      // Initial was offline
      expect(container.read(connectivityProvider).valueOrNull, ConnectivityStatus.online);

      sub.close();
    });

    test('transitions online -> offline -> reconnecting -> online', () async {
      final fake = FakeConnectivityService(initial: ConnectivityStatus.online);
      final container = ProviderContainer(overrides: [
        connectivityServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(() {
        container.dispose();
        fake.dispose();
      });

      final statuses = <ConnectivityStatus>[];
      final sub = container.listen(connectivityProvider, (_, next) {
        if (next.hasValue) statuses.add(next.value!);
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));

      fake.emit(ConnectivityStatus.offline);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      fake.emit(ConnectivityStatus.reconnecting);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      fake.emit(ConnectivityStatus.online);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(statuses, containsAllInOrder([
        ConnectivityStatus.offline,
        ConnectivityStatus.reconnecting,
        ConnectivityStatus.online,
      ]));

      sub.close();
    });

    test('connectivityServiceProvider returns a ConnectivityService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(connectivityServiceProvider);
      expect(service, isA<ConnectivityService>());
    });
  });
}
