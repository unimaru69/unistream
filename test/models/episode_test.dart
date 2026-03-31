import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/episode.dart';

void main() {
  group('Episode', () {
    test('fromJson with complete valid JSON', () {
      final json = {
        'id': 500,
        'title': 'Pilot',
        'container_extension': 'mkv',
        'episode_num': 1,
      };
      final ep = Episode.fromJson(json);
      expect(ep.id, 500);
      expect(ep.title, 'Pilot');
      expect(ep.containerExtension, 'mkv');
      expect(ep.episodeNum, 1);
    });

    test('fromJson with missing optional fields uses defaults', () {
      final json = {'id': 1};
      final ep = Episode.fromJson(json);
      expect(ep.title, isNull);
      expect(ep.containerExtension, 'mp4');
      expect(ep.episodeNum, isNull);
    });

    test('toJson roundtrip produces equal objects', () {
      final original = Episode(
        id: 10,
        title: 'Episode One',
        containerExtension: 'ts',
        episodeNum: 1,
      );
      final json = original.toJson();
      final restored = Episode.fromJson(json);
      expect(restored, original);
    });

    test('id accepts string (dynamic field)', () {
      final json = {'id': '999'};
      final ep = Episode.fromJson(json);
      expect(ep.id, '999');
    });

    test('episodeNum accepts string (dynamic field)', () {
      final json = {'id': 1, 'episode_num': '5'};
      final ep = Episode.fromJson(json);
      expect(ep.episodeNum, '5');
    });
  });

  group('EpisodeX extension', () {
    test('idStr returns id as string', () {
      final ep = Episode(id: 42);
      expect(ep.idStr, '42');
    });

    test('idStr works with string id', () {
      final ep = Episode(id: '77');
      expect(ep.idStr, '77');
    });

    test('displayTitle returns title when present', () {
      final ep = Episode(id: 1, title: 'Pilot');
      expect(ep.displayTitle, 'Pilot');
    });

    test('displayTitle falls back to Episode + number', () {
      final ep = Episode(id: 1, episodeNum: 3);
      expect(ep.displayTitle, 'Episode 3');
    });

    test('displayTitle falls back to Episode with empty suffix when no episodeNum', () {
      final ep = Episode(id: 1);
      expect(ep.displayTitle, 'Episode ');
    });

    test('number parses episodeNum as int', () {
      final ep = Episode(id: 1, episodeNum: 7);
      expect(ep.number, 7);
    });

    test('number parses string episodeNum', () {
      final ep = Episode(id: 1, episodeNum: '12');
      expect(ep.number, 12);
    });

    test('number returns 0 for null episodeNum', () {
      final ep = Episode(id: 1);
      expect(ep.number, 0);
    });

    test('number returns 0 for non-numeric episodeNum', () {
      final ep = Episode(id: 1, episodeNum: 'abc');
      expect(ep.number, 0);
    });
  });
}
