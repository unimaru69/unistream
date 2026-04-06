import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/services/m3u_parser.dart';

void main() {
  group('parseM3uCredentials', () {
    test('parses standard get.php Xtream URL format', () {
      const content =
          'http://myserver.com:8080/get.php?username=john&password=secret123&type=m3u_plus';
      final result = parseM3uCredentials(content);
      expect(result, isNotNull);
      expect(result!.serverUrl, 'http://myserver.com:8080');
      expect(result.username, 'john');
      expect(result.password, 'secret123');
    });

    test('parses path-based URL format', () {
      const content = 'http://iptv.example.com:25461/myuser/mypass/12345';
      final result = parseM3uCredentials(content);
      expect(result, isNotNull);
      expect(result!.serverUrl, 'http://iptv.example.com:25461');
      expect(result.username, 'myuser');
      expect(result.password, 'mypass');
    });

    test('parses credentials from full M3U file content', () {
      const content = '''#EXTM3U
#EXTINF:-1 tvg-id="France2.fr" tvg-name="FR | FRANCE 2 HD" group-title="FR | TNT",FR | FRANCE 2 HD
http://pro.server.tv:8080/john_doe/p4ssw0rd/12345
#EXTINF:-1 tvg-id="TF1.fr" tvg-name="FR | TF1 HD" group-title="FR | TNT",FR | TF1 HD
http://pro.server.tv:8080/john_doe/p4ssw0rd/12346
''';
      final result = parseM3uCredentials(content);
      expect(result, isNotNull);
      expect(result!.serverUrl, 'http://pro.server.tv:8080');
      expect(result.username, 'john_doe');
      expect(result.password, 'p4ssw0rd');
    });

    test('parses get.php format from full M3U file', () {
      const content = '''#EXTM3U
#EXTINF:-1,Channel One
http://cdn.iptv.com:80/get.php?username=testuser&password=testpass&type=m3u_plus&output=ts
''';
      final result = parseM3uCredentials(content);
      expect(result, isNotNull);
      expect(result!.serverUrl, 'http://cdn.iptv.com:80');
      expect(result.username, 'testuser');
      expect(result.password, 'testpass');
    });

    test('returns null for invalid content', () {
      const content = 'This is just some random text without any URLs';
      expect(parseM3uCredentials(content), isNull);
    });

    test('returns null for empty string', () {
      expect(parseM3uCredentials(''), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(parseM3uCredentials('   \n\t  '), isNull);
    });

    test('handles URL-encoded username and password in get.php format', () {
      const content =
          'http://server.com:8080/get.php?username=user%40name&password=p%26ss&type=m3u_plus';
      final result = parseM3uCredentials(content);
      expect(result, isNotNull);
      expect(result!.username, 'user@name');
      expect(result.password, 'p&ss');
    });

    test('ignores known API path segments like live/movie/series', () {
      const content = 'http://server.com:8080/live/user/pass/12345';
      expect(parseM3uCredentials(content), isNull);
    });
  });
}
