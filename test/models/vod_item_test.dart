import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/vod_item.dart';

void main() {
  group('VodItem', () {
    test('fromJson with complete valid JSON', () {
      final json = {
        'stream_id': 100,
        'name': 'Inception',
        'stream_icon': 'https://example.com/poster.jpg',
        'cover': 'https://example.com/cover.jpg',
        'container_extension': 'mkv',
        'category_id': '3',
        'category_name': 'Action',
        'rating': '8.8',
        'stream_type': 'movie',
        'plot': 'A mind-bending thriller.',
        'description': 'Description here',
        'added': '2024-02-15',
        'last_modified': '2024-03-01',
      };
      final vod = VodItem.fromJson(json);
      expect(vod.streamId, 100);
      expect(vod.name, 'Inception');
      expect(vod.streamIcon, 'https://example.com/poster.jpg');
      expect(vod.cover, 'https://example.com/cover.jpg');
      expect(vod.containerExtension, 'mkv');
      expect(vod.categoryId, '3');
      expect(vod.categoryName, 'Action');
      expect(vod.rating, '8.8');
      expect(vod.streamType, 'movie');
      expect(vod.plot, 'A mind-bending thriller.');
      expect(vod.description, 'Description here');
      expect(vod.added, '2024-02-15');
      expect(vod.lastModified, '2024-03-01');
    });

    test('fromJson with missing optional fields uses defaults', () {
      final json = {'stream_id': 1};
      final vod = VodItem.fromJson(json);
      expect(vod.name, '');
      expect(vod.streamIcon, isNull);
      expect(vod.cover, isNull);
      expect(vod.containerExtension, 'mp4');
      expect(vod.categoryId, isNull);
      expect(vod.rating, isNull);
      expect(vod.plot, isNull);
    });

    test('toJson roundtrip produces equal objects', () {
      final original = VodItem(
        streamId: 200,
        name: 'Test Movie',
        containerExtension: 'avi',
        rating: '7.5',
      );
      final json = original.toJson();
      final restored = VodItem.fromJson(json);
      expect(restored, original);
    });

    test('streamId accepts string (dynamic field)', () {
      final json = {'stream_id': '789'};
      final vod = VodItem.fromJson(json);
      expect(vod.streamId, '789');
    });
  });

  group('VodItemX extension', () {
    test('id returns streamId as string', () {
      final vod = VodItem(streamId: 42);
      expect(vod.id, '42');
    });

    test('id works with string streamId', () {
      final vod = VodItem(streamId: '99');
      expect(vod.id, '99');
    });

    test('displayIcon prefers streamIcon over cover', () {
      final vod = VodItem(
        streamId: 1,
        streamIcon: 'icon.png',
        cover: 'cover.png',
      );
      expect(vod.displayIcon, 'icon.png');
    });

    test('displayIcon falls back to cover', () {
      final vod = VodItem(streamId: 1, cover: 'cover.png');
      expect(vod.displayIcon, 'cover.png');
    });

    test('displayIcon returns empty string when both null', () {
      final vod = VodItem(streamId: 1);
      expect(vod.displayIcon, '');
    });

    // Regression: some Xtream panels return numeric values for text fields
    // (rating as 8.5, category_id as 21). Strict String? casts threw
    // "type 'double'/'int' is not a subtype of type 'String?'" → black error
    // screen on Films/Séries after switching servers.
    test('fromJson coerces numeric rating / category_id to String', () {
      final json = {
        'stream_id': 100,
        'name': 'Movie',
        'rating': 8.5,
        'category_id': 21,
        'category_name': 1469,
      };
      final vod = VodItem.fromJson(json);
      expect(vod.rating, '8.5');
      expect(vod.categoryId, '21');
      expect(vod.categoryName, '1469');
    });
  });
}
