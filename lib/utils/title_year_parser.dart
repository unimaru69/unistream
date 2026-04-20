/// Parses "raw" IPTV titles into a clean (title, year) pair usable for
/// external-metadata lookups such as TMDB.
///
/// The IPTV provider names come in many shapes:
///   "FR| Fire Country - 2025"
///   "FR| Fire Country (2025)"
///   "SD| Cold Wallet FHD - 2023"
///   "FHD Fire Country"
///   "=FR= FRANCE =FR="    (noise → no clean title)
///
/// The parser is defensive: unrecognised titles are returned as-is with a
/// null year.
class TitleYearParser {
  TitleYearParser._();

  /// Strips IPTV prefixes, quality suffixes and trailing year, returning a
  /// [TitleYear] record. The original string is always preserved in
  /// [TitleYear.original].
  static TitleYear parse(String raw) {
    if (raw.trim().isEmpty) {
      return const TitleYear(title: '', year: null, original: '');
    }

    String s = raw.trim();
    // Drop common country / quality prefixes: "FR|", "SD|", "FHD|", "VO|",
    // "BE|", "UK|", "US|" …
    s = s.replaceFirst(
      RegExp(r'^[A-Z]{2,4}[-\s]?\|\s*', caseSensitive: false),
      '',
    );
    // Extract 4-digit year anywhere near the end: " (2025)", " - 2025",
    // " 2025", " [2025]".
    int? year;
    final m = RegExp(r'[\s\-\(\[]?(19|20)\d{2}[\)\]]?\s*$').firstMatch(s);
    if (m != null) {
      final fourDigits = RegExp(r'(19|20)\d{2}').firstMatch(m.group(0)!);
      if (fourDigits != null) year = int.tryParse(fourDigits.group(0)!);
      s = s.substring(0, m.start).trim();
    }
    // Drop common quality tokens wherever they sit.
    final qualityTokens = RegExp(
      r'\b(FHD|HD|SD|4K|UHD|HEVC|HDR|H\.?264|H\.?265|X\.?264|X\.?265|'
      r'BluRay|BRRip|WEB[-.]?DL|WEBRip|HDTV|DVDRip|REMUX|MULTI|VOSTFR|VOST|VFF|VF|VO)\b',
      caseSensitive: false,
    );
    s = s.replaceAll(qualityTokens, '');
    // Drop separators + squeeze whitespace.
    s = s.replaceAll(RegExp(r'[\-\(\)\[\]\|]+'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return TitleYear(title: s, year: year, original: raw);
  }
}

/// Result of [TitleYearParser.parse].
class TitleYear {
  final String title;
  final int? year;
  final String original;

  const TitleYear({
    required this.title,
    required this.year,
    required this.original,
  });

  bool get isUsable => title.isNotEmpty;

  @override
  String toString() => 'TitleYear($title, $year)';
}
