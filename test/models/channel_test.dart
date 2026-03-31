import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/channel.dart';

void main() {
  group('Channel', () {
    test('fromJson with complete valid JSON', () {
      final json = {
        'stream_id': 123,
        'name': 'BBC One',
        'stream_icon': 'https://example.com/icon.png',
        'cover': 'https://example.com/cover.png',
        'category_id': '5',
        'category_name': 'UK',
        'tv_archive': 1,
        'tv_archive_duration': '7',
        'added': '2024-01-01',
        'last_modified': '2024-06-01',
      };
      final ch = Channel.fromJson(json);
      expect(ch.streamId, 123);
      expect(ch.name, 'BBC One');
      expect(ch.streamIcon, 'https://example.com/icon.png');
      expect(ch.cover, 'https://example.com/cover.png');
      expect(ch.categoryId, '5');
      expect(ch.categoryName, 'UK');
      expect(ch.tvArchive, 1);
      expect(ch.tvArchiveDuration, '7');
      expect(ch.added, '2024-01-01');
      expect(ch.lastModified, '2024-06-01');
    });

    test('fromJson with missing optional fields uses defaults', () {
      final json = {'stream_id': 1};
      final ch = Channel.fromJson(json);
      expect(ch.name, '');
      expect(ch.streamIcon, isNull);
      expect(ch.cover, isNull);
      expect(ch.categoryId, isNull);
      expect(ch.tvArchive, 0);
      expect(ch.tvArchiveDuration, '0');
    });

    test('toJson roundtrip produces equal objects', () {
      final original = Channel(
        streamId: 55,
        name: 'Test Channel',
        streamIcon: 'icon.png',
        tvArchive: 1,
        tvArchiveDuration: '3',
      );
      final json = original.toJson();
      final restored = Channel.fromJson(json);
      expect(restored, original);
    });

    test('streamId accepts string (dynamic field)', () {
      final json = {'stream_id': '456'};
      final ch = Channel.fromJson(json);
      expect(ch.streamId, '456');
    });

    test('tvArchive accepts string (dynamic field)', () {
      final json = {'stream_id': 1, 'tv_archive': '1'};
      final ch = Channel.fromJson(json);
      expect(ch.tvArchive, '1');
    });
  });

  group('ChannelX extension', () {
    test('id returns streamId as string', () {
      final ch = Channel(streamId: 42);
      expect(ch.id, '42');
    });

    test('id works with string streamId', () {
      final ch = Channel(streamId: '99');
      expect(ch.id, '99');
    });

    test('displayIcon prefers streamIcon over cover', () {
      final ch = Channel(
        streamId: 1,
        streamIcon: 'icon.png',
        cover: 'cover.png',
      );
      expect(ch.displayIcon, 'icon.png');
    });

    test('displayIcon falls back to cover', () {
      final ch = Channel(streamId: 1, cover: 'cover.png');
      expect(ch.displayIcon, 'cover.png');
    });

    test('displayIcon returns empty string when both null', () {
      final ch = Channel(streamId: 1);
      expect(ch.displayIcon, '');
    });

    test('hasCatchup true when tvArchive is 1', () {
      final ch = Channel(streamId: 1, tvArchive: 1);
      expect(ch.hasCatchup, true);
    });

    test('hasCatchup true when tvArchive is string "1"', () {
      final ch = Channel(streamId: 1, tvArchive: '1');
      expect(ch.hasCatchup, true);
    });

    test('hasCatchup false when tvArchive is 0', () {
      final ch = Channel(streamId: 1, tvArchive: 0);
      expect(ch.hasCatchup, false);
    });

    test('archiveDays parses string duration', () {
      final ch = Channel(streamId: 1, tvArchiveDuration: '14');
      expect(ch.archiveDays, 14);
    });

    test('archiveDays returns 0 for non-numeric', () {
      final ch = Channel(streamId: 1, tvArchiveDuration: 'abc');
      expect(ch.archiveDays, 0);
    });

    test('archiveDays returns 0 for default "0"', () {
      final ch = Channel(streamId: 1);
      expect(ch.archiveDays, 0);
    });
  });
}
