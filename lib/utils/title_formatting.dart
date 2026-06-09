/// String + format helpers shared with the tvOS `DesignSystem.swift`
/// extension on `String` and the free `formattedRuntime` /
/// `formattedRating` functions. Keep the two in lock-step — anything
/// that changes user-facing title formatting on one platform should
/// change here too.
library;

extension TitleFormatting on String {
  /// Strip the IPTV provider's "XX|" tag from the start of a title
  /// (≤4 alphanumeric characters followed by a pipe). Returns the
  /// trimmed remainder, or the original string when no tag is found.
  ///
  /// Example: `"FR| Drag Race France"` → `"Drag Race France"`.
  ///
  /// Conservative on purpose: requires the prefix to be 1–4 chars and
  /// mostly letters/digits, so titles that legitimately contain a "|"
  /// early on (rare, but it happens with episode titles) are untouched.
  String get strippingProviderTag {
    var s = this;
    // New-style leading pipe-wrapped tags: "|FR|", "|FR-4K DV|", and stacked
    // ones like "|VO|STFR|". A title that *starts* with '|' is a provider-tag
    // wrapper, so strip each leading "|…|" block (loop handles stacking).
    while (s.startsWith('|')) {
      final close = s.indexOf('|', 1);
      if (close < 0) break;
      s = s.substring(close + 1).trimLeft();
    }
    // Legacy "XX| " tag: 1–4 mostly-alphanumeric chars then a pipe. Also
    // catches the residue of a stacked tag ("|VO|STFR| …") after the loop.
    final pipe = s.indexOf('|');
    if (pipe >= 1 && pipe <= 4) {
      final prefix = s.substring(0, pipe);
      final ok = prefix.codeUnits.every((c) {
        return (c >= 0x30 && c <= 0x39) || // 0-9
            (c >= 0x41 && c <= 0x5A) || // A-Z
            (c >= 0x61 && c <= 0x7A) || // a-z
            c == 0x20; // space
      });
      if (ok) s = s.substring(pipe + 1).trim();
    }
    return identical(s, this) ? this : s.trim();
  }

  /// Strip a trailing parenthesised 4-digit year — e.g.
  /// `"Dune (2021)"` → `"Dune"`. Used in detail views where the year
  /// already appears in the metadata strip; leaving "(2021)" in the
  /// title duplicates the info and crowds the headline.
  ///
  /// Conservative: only matches `(YYYY)` at the very end (after trim)
  /// with YYYY in 1900–2099, so titles like "Blade Runner 2049" are
  /// untouched.
  String get strippingYearSuffix {
    final trimmed = trim();
    if (trimmed.length < 7 || !trimmed.endsWith(')')) return this;
    final open = trimmed.length - 6;
    if (trimmed[open] != '(') return this;
    final year = trimmed.substring(open + 1, trimmed.length - 1);
    if (year.length != 4) return this;
    final n = int.tryParse(year);
    if (n == null || n < 1900 || n > 2099) return this;
    return trimmed.substring(0, open).trim();
  }

  /// Convenience: strip the provider tag *and* a trailing year. Use in
  /// detail headlines where the year is rendered in the metadata strip
  /// on its own.
  String get cleanedTitleNoYear => strippingProviderTag.strippingYearSuffix;
}

/// Format minutes as `"2h17"` / `"47 min"` — matches the Apple TV+ /
/// Strimr convention. Returns an empty string on `null` or non-positive
/// input so call-sites can do `if (formattedRuntime(m).isNotEmpty)`.
String formattedRuntime(int? minutes) {
  if (minutes == null || minutes <= 0) return '';
  if (minutes >= 60) {
    final h = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '${h}h' : '${h}h${rem.toString().padLeft(2, '0')}';
  }
  return '$minutes min';
}

/// One-decimal star rating ("8.4"), or empty for missing / zero.
String formattedRating(double? score) {
  if (score == null || score <= 0) return '';
  return score.toStringAsFixed(1);
}
