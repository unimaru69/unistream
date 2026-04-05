import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/core/logger.dart';

void main() {
  group('AppLogger', () {
    test('debug does not throw', () {
      expect(() => AppLogger.debug('Test', 'debug message'), returnsNormally);
    });

    test('info does not throw', () {
      expect(() => AppLogger.info('Test', 'info message'), returnsNormally);
    });

    test('warning does not throw', () {
      expect(
        () => AppLogger.warning('Test', 'warning message'),
        returnsNormally,
      );
    });

    test('breadcrumb does not throw without data', () {
      expect(
        () => AppLogger.breadcrumb('test', 'some action'),
        returnsNormally,
      );
    });

    test('breadcrumb does not throw with data', () {
      expect(
        () => AppLogger.breadcrumb('test', 'some action', data: {'key': 'value'}),
        returnsNormally,
      );
    });
  });

  group('LogModule', () {
    test('contains expected module constants', () {
      expect(LogModule.api, 'API');
      expect(LogModule.player, 'Player');
      expect(LogModule.storage, 'Storage');
      expect(LogModule.config, 'Config');
      expect(LogModule.epg, 'EPG');
      expect(LogModule.ui, 'UI');
      expect(LogModule.sync, 'Sync');
    });
  });
}
