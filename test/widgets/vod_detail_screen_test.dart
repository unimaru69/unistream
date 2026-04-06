import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/vod_item.dart';

void main() {
  group('VodItem for VodDetailScreen', () {
    test('VodItem.fromJson parses all fields', () {
      final json = {
        'stream_id': 42,
        'name': 'Test Movie',
        'stream_icon': 'https://example.com/poster.jpg',
        'cover': 'https://example.com/cover.jpg',
        'container_extension': 'mkv',
        'category_id': '5',
        'category_name': 'Action',
        'rating': '8.5',
        'plot': 'A thrilling adventure.',
        'description': 'Extended plot description.',
        'added': '1700000000',
        'last_modified': '1700000100',
      };
      final vod = VodItem.fromJson(json);
      expect(vod.name, 'Test Movie');
      expect(vod.id, '42');
      expect(vod.containerExtension, 'mkv');
      expect(vod.categoryName, 'Action');
      expect(vod.rating, '8.5');
      expect(vod.plot, 'A thrilling adventure.');
      expect(vod.displayIcon, 'https://example.com/poster.jpg');
    });

    test('VodItem.displayIcon falls back to cover', () {
      final vod = VodItem(
        streamId: 1,
        name: 'No Icon',
        containerExtension: 'mp4',
      );
      expect(vod.displayIcon, '');

      final vodWithCover = VodItem(
        streamId: 2,
        name: 'With Cover',
        cover: 'https://example.com/cover.jpg',
        containerExtension: 'mp4',
      );
      expect(vodWithCover.displayIcon, 'https://example.com/cover.jpg');
    });

    test('VodItem defaults to mp4 container extension', () {
      final vod = VodItem.fromJson({'stream_id': 1});
      expect(vod.containerExtension, 'mp4');
    });
  });
}
