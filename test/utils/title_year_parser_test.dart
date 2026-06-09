import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/utils/title_year_parser.dart';

void main() {
  group('TitleYearParser', () {
    void expectParse(String raw, String title, int? year) {
      final r = TitleYearParser.parse(raw);
      expect(r.title, title, reason: 'title for "$raw"');
      expect(r.year, year, reason: 'year for "$raw"');
    }

    test('empty / blank', () {
      expectParse('', '', null);
      expectParse('   ', '', null);
    });

    // Legacy format (no leading pipe) — must keep working.
    test('non-piped prefix "FR| Title - year"', () {
      expectParse('FR| Fire Country - 2025', 'Fire Country', 2025);
      expectParse('SD| Cold Wallet FHD - 2023', 'Cold Wallet', 2023);
      expectParse('FHD Fire Country', 'Fire Country', null);
    });

    // Regression: the new server wraps the tag in pipes ("|FR| ..."), which
    // the old parser left as "FR Title" and broke every TMDB lookup.
    test('leading pipe-wrapped tag "|FR| Title (year)"', () {
      expectParse('|FR| Extravagances (1995)', 'Extravagances', 1995);
      expectParse('|FR| Nuremberg (2025)', 'Nuremberg', 2025);
      expectParse('|IT| Mortal Kombat II (2026)', 'Mortal Kombat II', 2026);
    });

    test('pipe tag with quality "|FR-4K DV| Title"', () {
      expectParse('|FR-4K DV| Michael (2026)', 'Michael', 2026);
      expectParse('|IT-4K| Mortal Kombat II (2026)', 'Mortal Kombat II', 2026);
    });

    test('stacked pipe tags "|VO|STFR| Title"', () {
      expectParse('|VO|STFR| Yowayowa Sensei (2026)', 'Yowayowa Sensei', 2026);
    });

    test('trailing junk after "||"', () {
      expectParse('|FR| La casa de papel (2017) || MULTI', 'La casa de papel', 2017);
    });

    test('year not at end (tag after year)', () {
      expectParse('|QC| Vie de chantier (2018) (VFQ)', 'Vie de chantier', 2018);
    });

    test('preserves intra-word dashes', () {
      expectParse('|FR| 9-1-1: Lone Star (2020)', '9-1-1: Lone Star', 2020);
    });

    test('noise title without a real name stays non-empty or harmless', () {
      // "=FR= FRANCE =FR=" has no pipe tag — parser returns it as-is-ish.
      final r = TitleYearParser.parse('=FR= FRANCE =FR=');
      expect(r.year, isNull);
    });
  });
}
