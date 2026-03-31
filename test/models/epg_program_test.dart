import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/epg_program.dart';

void main() {
  group('EpgProgram', () {
    test('fromJson with complete valid JSON', () {
      final json = {
        'title': 'Evening News',
        'description': 'Daily news broadcast',
        'start': '2024-01-15 18:00:00',
        'end': '2024-01-15 18:30:00',
        'start_timestamp': '1705334400',
        'stop_timestamp': '1705336200',
        'start_utc': '2024-01-15 17:00:00',
        'start_server_local': '2024-01-15 18:00:00',
        'start_epoch': 1705334400,
      };
      final epg = EpgProgram.fromJson(json);
      expect(epg.title, 'Evening News');
      expect(epg.description, 'Daily news broadcast');
      expect(epg.start, '2024-01-15 18:00:00');
      expect(epg.end, '2024-01-15 18:30:00');
      expect(epg.startTimestamp, '1705334400');
      expect(epg.stopTimestamp, '1705336200');
      expect(epg.startUtc, '2024-01-15 17:00:00');
      expect(epg.startServerLocal, '2024-01-15 18:00:00');
      expect(epg.startEpoch, 1705334400);
    });

    test('fromJson with missing optional fields uses defaults', () {
      final json = <String, dynamic>{};
      final epg = EpgProgram.fromJson(json);
      expect(epg.title, '');
      expect(epg.description, isNull);
      expect(epg.start, isNull);
      expect(epg.end, isNull);
      expect(epg.startTimestamp, isNull);
      expect(epg.stopTimestamp, isNull);
      expect(epg.startUtc, isNull);
      expect(epg.startServerLocal, isNull);
      expect(epg.startEpoch, isNull);
    });

    test('toJson roundtrip produces equal objects', () {
      final original = EpgProgram(
        title: 'Show',
        description: 'A show',
        start: '2024-01-01 20:00:00',
        end: '2024-01-01 21:00:00',
      );
      final json = original.toJson();
      final restored = EpgProgram.fromJson(json);
      expect(restored, original);
    });

    test('startEpoch accepts string (dynamic field)', () {
      final json = {'start_epoch': '1705334400'};
      final epg = EpgProgram.fromJson(json);
      expect(epg.startEpoch, '1705334400');
    });

    test('fromJson with empty title string', () {
      final json = {'title': ''};
      final epg = EpgProgram.fromJson(json);
      expect(epg.title, '');
    });
  });
}
