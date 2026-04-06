/// Parses Xtream Codes credentials from M3U file content.
///
/// Supports two URL formats commonly found in M3U playlists:
/// - `http://server:port/get.php?username=X&password=Y&type=m3u_plus`
/// - `http://server:port/username/password/12345`
({String serverUrl, String username, String password})? parseM3uCredentials(
    String content) {
  if (content.trim().isEmpty) return null;

  // Format 1: get.php?username=X&password=Y
  final getPhpRe = RegExp(
    r'(https?://[^/\s]+)/get\.php\?username=([^&\s]+)&password=([^&\s]+)',
  );
  final m1 = getPhpRe.firstMatch(content);
  if (m1 != null) {
    return (
      serverUrl: m1.group(1)!,
      username: Uri.decodeComponent(m1.group(2)!),
      password: Uri.decodeComponent(m1.group(3)!),
    );
  }

  // Format 2: /username/password/streamId  (path-based)
  final pathRe = RegExp(
    r'(https?://[^/\s]+)/([^/\s]+)/([^/\s]+)/\d+',
  );
  final m2 = pathRe.firstMatch(content);
  if (m2 != null) {
    final user = m2.group(2)!;
    final pass = m2.group(3)!;
    // Skip if it looks like a known API path segment
    if (user == 'live' || user == 'movie' || user == 'series' ||
        user == 'player_api.php' || user == 'get.php') {
      return null;
    }
    return (
      serverUrl: m2.group(1)!,
      username: user,
      password: pass,
    );
  }

  return null;
}
