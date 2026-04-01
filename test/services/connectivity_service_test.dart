import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:mocktail/mocktail.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/services/connectivity_service.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  group('ConnectivityService', () {
    late MockConnectivity mockConnectivity;
    late StreamController<List<ConnectivityResult>> connectivityController;

    setUp(() async {
      // Set AppConfig directly for testing reachability
      AppConfig.serverUrl = 'http://test.local';

      mockConnectivity = MockConnectivity();
      connectivityController = StreamController<List<ConnectivityResult>>.broadcast();
      when(() => mockConnectivity.onConnectivityChanged)
          .thenAnswer((_) => connectivityController.stream);
    });

    tearDown(() {
      connectivityController.close();
    });

    test('checkNow returns offline when no connectivity', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      final service = ConnectivityService(connectivity: mockConnectivity);
      final status = await service.checkNow();
      expect(status, ConnectivityStatus.offline);
    });

    test('checkNow returns online when wifi and server reachable', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      final mockClient = http_testing.MockClient((_) async {
        return http.Response('', 200);
      });

      final service = ConnectivityService(
        connectivity: mockConnectivity,
        httpClient: mockClient,
      );
      final status = await service.checkNow();
      expect(status, ConnectivityStatus.online);
    });

    test('checkNow returns offline when wifi but server unreachable (timeout)', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      final mockClient = http_testing.MockClient((_) async {
        throw TimeoutException('Server unreachable');
      });

      final service = ConnectivityService(
        connectivity: mockConnectivity,
        httpClient: mockClient,
      );
      final status = await service.checkNow();
      expect(status, ConnectivityStatus.offline);
    });

    test('statusStream emits offline when connectivity lost', () async {
      final mockClient = http_testing.MockClient((_) async {
        return http.Response('', 200);
      });

      final service = ConnectivityService(
        connectivity: mockConnectivity,
        httpClient: mockClient,
      );

      final statuses = <ConnectivityStatus>[];
      final sub = service.statusStream.listen(statuses.add);

      // Emit no connectivity
      connectivityController.add([ConnectivityResult.none]);

      // Wait for debounce (300ms) + processing
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(statuses, contains(ConnectivityStatus.offline));

      await sub.cancel();
    });

    test('statusStream emits reconnecting then online when connectivity restored', () async {
      final mockClient = http_testing.MockClient((_) async {
        return http.Response('', 200);
      });

      final service = ConnectivityService(
        connectivity: mockConnectivity,
        httpClient: mockClient,
      );

      final statuses = <ConnectivityStatus>[];
      final sub = service.statusStream.listen(statuses.add);

      // Emit wifi available
      connectivityController.add([ConnectivityResult.wifi]);

      // Wait for debounce + reachability check
      await Future<void>.delayed(const Duration(milliseconds: 800));

      expect(statuses, contains(ConnectivityStatus.reconnecting));
      expect(statuses, contains(ConnectivityStatus.online));

      await sub.cancel();
    });

    test('statusStream deduplicates consecutive identical statuses', () async {
      final mockClient = http_testing.MockClient((_) async {
        return http.Response('', 200);
      });

      final service = ConnectivityService(
        connectivity: mockConnectivity,
        httpClient: mockClient,
      );

      final statuses = <ConnectivityStatus>[];
      final sub = service.statusStream.listen(statuses.add);

      // Emit no connectivity twice
      connectivityController.add([ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      connectivityController.add([ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Should only have one offline emission
      final offlineCount = statuses.where((s) => s == ConnectivityStatus.offline).length;
      expect(offlineCount, 1);

      await sub.cancel();
    });

    test('ConnectivityStatus enum has correct values', () {
      expect(ConnectivityStatus.values, hasLength(3));
      expect(ConnectivityStatus.values, contains(ConnectivityStatus.online));
      expect(ConnectivityStatus.values, contains(ConnectivityStatus.offline));
      expect(ConnectivityStatus.values, contains(ConnectivityStatus.reconnecting));
    });
  });
}
