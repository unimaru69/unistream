import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/screens/player/widgets/quality_selector.dart';

void main() {
  group('HlsVariant.label', () {
    test('height >= 2160 returns "2160p (4K)"', () {
      const v = HlsVariant(url: '', bandwidth: 20000000, height: 2160, width: 3840);
      expect(v.label, '2160p (4K)');
    });

    test('height >= 1080 returns "1080p (FHD)"', () {
      const v = HlsVariant(url: '', bandwidth: 8000000, height: 1080, width: 1920);
      expect(v.label, '1080p (FHD)');
    });

    test('height >= 720 returns "720p (HD)"', () {
      const v = HlsVariant(url: '', bandwidth: 4000000, height: 720, width: 1280);
      expect(v.label, '720p (HD)');
    });

    test('height < 720 returns "480p (SD)"', () {
      const v = HlsVariant(url: '', bandwidth: 1500000, height: 480, width: 854);
      expect(v.label, '480p (SD)');
    });

    test('height == 0 falls through to name', () {
      const v = HlsVariant(url: '', bandwidth: 5000000, height: 0, name: 'Medium');
      expect(v.label, 'Medium');
    });

    test('no height but has name returns name', () {
      const v = HlsVariant(url: '', bandwidth: 5000000, name: 'Custom Quality');
      expect(v.label, 'Custom Quality');
    });

    test('no height, empty name falls through to Mbps', () {
      const v = HlsVariant(url: '', bandwidth: 5000000, name: '');
      expect(v.label, '5.0 Mbps');
    });

    test('no height, no name returns Mbps', () {
      const v = HlsVariant(url: '', bandwidth: 2500000);
      expect(v.label, '2.5 Mbps');
    });

    test('fractional Mbps rounds to one decimal', () {
      const v = HlsVariant(url: '', bandwidth: 3750000);
      expect(v.label, '3.8 Mbps');
    });
  });

  group('parseHlsMasterPlaylist', () {
    test('empty content returns empty list', () {
      expect(parseHlsMasterPlaylist('', 'http://example.com/master.m3u8'), isEmpty);
    });

    test('non-master playlist returns empty list', () {
      const content = '''
#EXTM3U
#EXT-X-TARGETDURATION:10
#EXTINF:10,
segment001.ts
#EXTINF:10,
segment002.ts
''';
      expect(parseHlsMasterPlaylist(content, 'http://example.com/master.m3u8'), isEmpty);
    });

    test('single variant returns list of 1', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
720p.m3u8
''';
      final variants = parseHlsMasterPlaylist(content, 'http://cdn.example.com/live/master.m3u8');

      expect(variants.length, 1);
      expect(variants[0].bandwidth, 2000000);
      expect(variants[0].width, 1280);
      expect(variants[0].height, 720);
      expect(variants[0].label, '720p (HD)');
    });

    test('multiple variants sorted by bandwidth descending', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x480
480p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
1080p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
720p.m3u8
''';
      final variants = parseHlsMasterPlaylist(content, 'http://cdn.example.com/live/master.m3u8');

      expect(variants.length, 3);
      expect(variants[0].bandwidth, 5000000);
      expect(variants[0].height, 1080);
      expect(variants[1].bandwidth, 2500000);
      expect(variants[1].height, 720);
      expect(variants[2].bandwidth, 1000000);
      expect(variants[2].height, 480);
    });

    test('relative URLs resolved against base URL', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720
quality/720p.m3u8
''';
      final variants = parseHlsMasterPlaylist(
        content,
        'http://cdn.example.com/live/master.m3u8',
      );

      expect(variants.length, 1);
      expect(variants[0].url, 'http://cdn.example.com/live/quality/720p.m3u8');
    });

    test('absolute URLs kept as-is', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=4000000,RESOLUTION=1920x1080
https://other-cdn.example.com/1080p.m3u8
''';
      final variants = parseHlsMasterPlaylist(
        content,
        'http://cdn.example.com/live/master.m3u8',
      );

      expect(variants.length, 1);
      expect(variants[0].url, 'https://other-cdn.example.com/1080p.m3u8');
    });

    test('parses NAME attribute', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720,NAME="HD 720p"
720p.m3u8
''';
      final variants = parseHlsMasterPlaylist(content, 'http://example.com/master.m3u8');

      expect(variants.length, 1);
      expect(variants[0].name, 'HD 720p');
    });

    test('skips variant with missing BANDWIDTH', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:RESOLUTION=1280x720
720p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1920x1080
1080p.m3u8
''';
      final variants = parseHlsMasterPlaylist(content, 'http://example.com/master.m3u8');

      expect(variants.length, 1);
      expect(variants[0].bandwidth, 3000000);
    });

    test('handles comment lines between STREAM-INF and URL', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
#EXT-X-SOME-TAG:value
720p.m3u8
''';
      final variants = parseHlsMasterPlaylist(content, 'http://example.com/path/master.m3u8');

      expect(variants.length, 1);
      expect(variants[0].url, contains('720p.m3u8'));
    });

    test('variant without RESOLUTION has null width/height', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1500000
stream.m3u8
''';
      final variants = parseHlsMasterPlaylist(content, 'http://example.com/master.m3u8');

      expect(variants.length, 1);
      expect(variants[0].width, isNull);
      expect(variants[0].height, isNull);
      expect(variants[0].label, '1.5 Mbps');
    });
  });
}
