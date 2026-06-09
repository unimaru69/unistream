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
    // Drop leading pipe-wrapped tag blocks: "|FR|", "|FR-4K DV|", "|IT-4K|",
    // and stacked ones like "|VO|STFR|". Some panels wrap the country/quality
    // tag in pipes (leading pipe first), e.g. "|FR| Extravagances (1995)".
    // Without this the "FR" leaks into the title and breaks TMDB matching.
    // Looped so multiple stacked blocks are all removed.
    final leadingPipeTag = RegExp(r'^\s*\|[^|]*\|\s*');
    while (leadingPipeTag.hasMatch(s)) {
      s = s.replaceFirst(leadingPipeTag, '');
    }
    // Drop a remaining country / quality prefix without a leading pipe:
    // "FR|", "SD|", "STFR|", "VO|", "BE|", "UK|", "US|" …
    s = s.replaceFirst(
      RegExp(r'^[A-Z]{2,4}[-\s]?\|\s*', caseSensitive: false),
      '',
    );
    // Cut trailing junk after a "||" separator, e.g.
    // "La casa de papel (2017) || MULTI".
    final dbl = s.indexOf('||');
    if (dbl >= 0) s = s.substring(0, dbl).trim();

    // Extract the year. Prefer a parenthesised/bracketed 4-digit year anywhere
    // ("(2017)", "[2020]") — robust against trailing tags like "(VFQ)" that
    // follow the year. Fall back to a bare trailing year (" - 2025", " 2025").
    int? year;
    final paren = RegExp(r'[\(\[](19|20)\d{2}[\)\]]').firstMatch(s);
    if (paren != null) {
      year = int.tryParse(RegExp(r'(19|20)\d{2}').firstMatch(paren.group(0)!)!.group(0)!);
      s = '${s.substring(0, paren.start)} ${s.substring(paren.end)}'.trim();
    } else {
      final tail = RegExp(r'[\s\-\(\[]?(19|20)\d{2}[\)\]]?\s*$').firstMatch(s);
      if (tail != null) {
        year = int.tryParse(RegExp(r'(19|20)\d{2}').firstMatch(tail.group(0)!)!.group(0)!);
        s = s.substring(0, tail.start).trim();
      }
    }
    // Drop common quality / version tokens wherever they sit.
    final qualityTokens = RegExp(
      r'\b(FHD|HD|SD|4K|UHD|HEVC|HDR|H\.?264|H\.?265|X\.?264|X\.?265|'
      r'BluRay|BRRip|WEB[-.]?DL|WEBRip|HDTV|DVDRip|REMUX|MULTI|DV|'
      r'VOSTFR|VOST|STFR|VFQ|VFF|VF|VO)\b',
      caseSensitive: false,
    );
    s = s.replaceAll(qualityTokens, '');
    // Bracket / pipe separators → space.
    s = s.replaceAll(RegExp(r'[\(\)\[\]\|]+'), ' ');
    // Per-token cleanup: strip edge dashes (drops standalone "-" and the
    // trailing dash left by "Title - 2025") while preserving intra-word
    // dashes like "9-1-1".
    s = s
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'^[-–]+|[-–]+$'), ''))
        .where((t) => t.isNotEmpty)
        .join(' ')
        .trim();

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
