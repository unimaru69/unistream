import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/channel.dart';
import 'package:unistream/models/vod_item.dart';
import 'package:unistream/models/series_item.dart';
import 'package:unistream/utils/stream_helpers.dart';

void main() {
  group('getStreamId', () {
    test('returns streamId for Channel', () {
      final ch = const Channel(streamId: 42, name: 'Test');
      expect(getStreamId(ch), '42');
    });

    test('returns streamId for VodItem', () {
      final vod = const VodItem(streamId: 99, name: 'Movie');
      expect(getStreamId(vod), '99');
    });

    test('returns seriesId for SeriesItem', () {
      final series = const SeriesItem(seriesId: 7, name: 'Show');
      expect(getStreamId(series), '7');
    });

    test('returns series_id from Map', () {
      final map = <String, dynamic>{'series_id': 10, 'stream_id': 20};
      expect(getStreamId(map), '10');
    });

    test('returns stream_id from Map when no series_id', () {
      final map = <String, dynamic>{'stream_id': 20};
      expect(getStreamId(map), '20');
    });

    test('returns empty string for Map without ids', () {
      final map = <String, dynamic>{'name': 'test'};
      expect(getStreamId(map), '');
    });

    test('returns empty string for unknown type', () {
      expect(getStreamId(42), '');
    });

    test('handles string streamId', () {
      final ch = const Channel(streamId: '123', name: 'Test');
      expect(getStreamId(ch), '123');
    });
  });

  group('getStreamName', () {
    test('returns name for Channel', () {
      final ch = const Channel(streamId: 1, name: 'BBC One');
      expect(getStreamName(ch), 'BBC One');
    });

    test('returns name for VodItem', () {
      final vod = const VodItem(streamId: 1, name: 'Inception');
      expect(getStreamName(vod), 'Inception');
    });

    test('returns name for SeriesItem', () {
      final series = const SeriesItem(seriesId: 1, name: 'Breaking Bad');
      expect(getStreamName(series), 'Breaking Bad');
    });

    test('returns name from Map', () {
      expect(getStreamName({'name': 'Test'}), 'Test');
    });

    test('returns empty string for Map without name', () {
      expect(getStreamName(<String, dynamic>{}), '');
    });

    test('returns empty string for unknown type', () {
      expect(getStreamName(42), '');
    });
  });

  group('getStreamIcon', () {
    test('returns displayIcon for Channel (streamIcon)', () {
      final ch = const Channel(
          streamId: 1, streamIcon: 'icon.png', cover: 'cover.png');
      expect(getStreamIcon(ch), 'icon.png');
    });

    test('returns displayIcon for Channel (fallback to cover)', () {
      final ch = const Channel(streamId: 1, cover: 'cover.png');
      expect(getStreamIcon(ch), 'cover.png');
    });

    test('returns displayIcon for VodItem', () {
      final vod = const VodItem(streamId: 1, streamIcon: 'icon.png');
      expect(getStreamIcon(vod), 'icon.png');
    });

    test('returns displayIcon for SeriesItem (cover preferred)', () {
      final series = const SeriesItem(
          seriesId: 1, cover: 'cover.png', streamIcon: 'icon.png');
      expect(getStreamIcon(series), 'cover.png');
    });

    test('returns stream_icon from Map', () {
      expect(
        getStreamIcon({'stream_icon': 'icon.png', 'cover': 'cover.png'}),
        'icon.png',
      );
    });

    test('returns cover from Map as fallback', () {
      expect(getStreamIcon({'cover': 'cover.png'}), 'cover.png');
    });

    test('returns empty string for empty Map', () {
      expect(getStreamIcon(<String, dynamic>{}), '');
    });

    test('returns empty string for unknown type', () {
      expect(getStreamIcon(42), '');
    });
  });

  group('streamToMap', () {
    test('converts Channel to map', () {
      final ch = const Channel(
        streamId: 1,
        name: 'Test',
        streamIcon: 'icon.png',
        cover: 'cover.png',
        categoryId: '5',
      );
      final map = streamToMap(ch);
      expect(map['stream_id'], 1);
      expect(map['name'], 'Test');
      expect(map['stream_icon'], 'icon.png');
      expect(map['cover'], 'cover.png');
      expect(map['category_id'], '5');
    });

    test('converts VodItem to map', () {
      final vod = const VodItem(
        streamId: 2,
        name: 'Movie',
        containerExtension: 'mkv',
        rating: '8.5',
        plot: 'A great movie',
      );
      final map = streamToMap(vod);
      expect(map['stream_id'], 2);
      expect(map['name'], 'Movie');
      expect(map['container_extension'], 'mkv');
      expect(map['rating'], '8.5');
      expect(map['plot'], 'A great movie');
    });

    test('converts SeriesItem to map', () {
      final series = const SeriesItem(
        seriesId: 3,
        name: 'Series',
        numSeasons: '5',
        cover: 'cover.png',
      );
      final map = streamToMap(series);
      expect(map['series_id'], 3);
      expect(map['name'], 'Series');
      expect(map['num_seasons'], '5');
      expect(map['cover'], 'cover.png');
    });

    test('returns same map for Map input', () {
      final input = {'stream_id': 1, 'name': 'Test'};
      final result = streamToMap(input);
      expect(result, input);
    });

    test('returns empty map for unknown type', () {
      expect(streamToMap(42), isEmpty);
    });
  });
}
