import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/series_item.dart';

void main() {
  group('SeriesItem', () {
    test('fromJson with complete valid JSON', () {
      final json = {
        'series_id': 300,
        'name': 'Breaking Bad',
        'cover': 'https://example.com/cover.jpg',
        'stream_icon': 'https://example.com/icon.jpg',
        'category_id': '10',
        'category_name': 'Drama',
        'num_seasons': '5',
        'rating': '9.5',
        'plot': 'A chemistry teacher turns to crime.',
        'description': 'Description text',
        'added': '2024-01-01',
        'last_modified': '2024-06-15',
      };
      final series = SeriesItem.fromJson(json);
      expect(series.seriesId, 300);
      expect(series.name, 'Breaking Bad');
      expect(series.cover, 'https://example.com/cover.jpg');
      expect(series.streamIcon, 'https://example.com/icon.jpg');
      expect(series.categoryId, '10');
      expect(series.categoryName, 'Drama');
      expect(series.numSeasons, '5');
      expect(series.rating, '9.5');
      expect(series.plot, 'A chemistry teacher turns to crime.');
      expect(series.description, 'Description text');
    });

    test('fromJson with missing optional fields uses defaults', () {
      final json = {'series_id': 1};
      final series = SeriesItem.fromJson(json);
      expect(series.name, '');
      expect(series.cover, isNull);
      expect(series.streamIcon, isNull);
      expect(series.categoryId, isNull);
      expect(series.numSeasons, isNull);
      expect(series.rating, isNull);
      expect(series.plot, isNull);
    });

    test('toJson roundtrip produces equal objects', () {
      final original = SeriesItem(
        seriesId: 50,
        name: 'Test Series',
        cover: 'cover.png',
        numSeasons: '3',
      );
      final json = original.toJson();
      final restored = SeriesItem.fromJson(json);
      expect(restored, original);
    });

    test('seriesId accepts string (dynamic field)', () {
      final json = {'series_id': '555'};
      final series = SeriesItem.fromJson(json);
      expect(series.seriesId, '555');
    });
  });

  group('SeriesItemX extension', () {
    test('id returns seriesId as string', () {
      final series = SeriesItem(seriesId: 42);
      expect(series.id, '42');
    });

    test('id works with string seriesId', () {
      final series = SeriesItem(seriesId: '77');
      expect(series.id, '77');
    });

    test('displayIcon prefers cover over streamIcon', () {
      final series = SeriesItem(
        seriesId: 1,
        cover: 'cover.png',
        streamIcon: 'icon.png',
      );
      expect(series.displayIcon, 'cover.png');
    });

    test('displayIcon falls back to streamIcon', () {
      final series = SeriesItem(seriesId: 1, streamIcon: 'icon.png');
      expect(series.displayIcon, 'icon.png');
    });

    test('displayIcon returns empty string when both null', () {
      final series = SeriesItem(seriesId: 1);
      expect(series.displayIcon, '');
    });
  });
}
