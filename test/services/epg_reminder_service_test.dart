import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/services/epg_reminder_service.dart';

void main() {
  group('EpgReminder', () {
    test('id is streamId_millisSinceEpoch', () {
      final start = DateTime.utc(2026, 4, 6, 20, 0);
      final r = EpgReminder(
        streamId: '42',
        channelName: 'TF1',
        programTitle: 'Journal',
        startUtc: start,
        durationMin: 30,
      );
      expect(r.id, '42_${start.millisecondsSinceEpoch}');
    });

    test('alertTime is startUtc minus alertMinutesBefore', () {
      final start = DateTime.utc(2026, 4, 6, 20, 0);
      final r = EpgReminder(
        streamId: '1',
        channelName: 'C',
        programTitle: 'P',
        startUtc: start,
        durationMin: 60,
        alertMinutesBefore: 10,
      );
      expect(r.alertTime, start.subtract(const Duration(minutes: 10)));
    });

    test('isExpired returns true for past programs', () {
      final pastStart = DateTime.utc(2020, 1, 1, 12, 0);
      final r = EpgReminder(
        streamId: '1',
        channelName: 'C',
        programTitle: 'P',
        startUtc: pastStart,
        durationMin: 30,
      );
      expect(r.isExpired, isTrue);
    });

    test('isExpired returns false for future programs', () {
      final futureStart = DateTime.utc(2099, 12, 31, 23, 0);
      final r = EpgReminder(
        streamId: '1',
        channelName: 'C',
        programTitle: 'P',
        startUtc: futureStart,
        durationMin: 30,
      );
      expect(r.isExpired, isFalse);
    });

    test('toJson / fromJson round-trip', () {
      final start = DateTime.utc(2026, 4, 6, 20, 0);
      final r = EpgReminder(
        streamId: '42',
        channelName: 'TF1',
        programTitle: 'Journal',
        startUtc: start,
        durationMin: 30,
        alertMinutesBefore: 10,
      );
      final json = r.toJson();
      final r2 = EpgReminder.fromJson(json);
      expect(r2.id, r.id);
      expect(r2.streamId, '42');
      expect(r2.channelName, 'TF1');
      expect(r2.programTitle, 'Journal');
      expect(r2.startUtc, start);
      expect(r2.durationMin, 30);
      expect(r2.alertMinutesBefore, 10);
    });

    test('fromJson defaults alertMinutesBefore to 5', () {
      final json = {
        'streamId': '1',
        'channelName': 'C',
        'programTitle': 'P',
        'startUtc': '2026-04-06T20:00:00.000Z',
        'durationMin': 30,
      };
      final r = EpgReminder.fromJson(json);
      expect(r.alertMinutesBefore, 5);
    });
  });
}
