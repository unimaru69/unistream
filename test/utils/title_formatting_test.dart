import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/utils/title_formatting.dart';

void main() {
  group('strippingProviderTag', () {
    // Legacy format (no leading pipe) — must keep working.
    test('legacy "XX| Title"', () {
      expect('FR| Drag Race France'.strippingProviderTag, 'Drag Race France');
      expect('ARI| Bhramam'.strippingProviderTag, 'Bhramam');
    });

    // Regression: the new server wraps the tag in pipes ("|FR| ..."), which the
    // old logic left untouched (pipe at index 0) → "|FR|" leaked into the UI.
    test('leading pipe-wrapped "|FR| Title"', () {
      expect('|FR| Extravagances'.strippingProviderTag, 'Extravagances');
      expect('|IT| Mortal Kombat II'.strippingProviderTag, 'Mortal Kombat II');
    });

    test('leading pipe tag with quality "|FR-4K DV| Title"', () {
      expect('|FR-4K DV| Michael'.strippingProviderTag, 'Michael');
    });

    test('stacked pipe tags "|VO|STFR| Title"', () {
      expect('|VO|STFR| Yowayowa Sensei'.strippingProviderTag, 'Yowayowa Sensei');
    });

    test('untagged title is untouched', () {
      expect('Blade Runner 2049'.strippingProviderTag, 'Blade Runner 2049');
      expect('Mr & Mrs Smith'.strippingProviderTag, 'Mr & Mrs Smith');
    });

    test('cleanedTitleNoYear strips tag and trailing year', () {
      expect('|FR| Extravagances (1995)'.cleanedTitleNoYear, 'Extravagances');
      expect('FR| Dune (2021)'.cleanedTitleNoYear, 'Dune');
      // Mid-string year is preserved.
      expect('|FR| Blade Runner 2049'.cleanedTitleNoYear, 'Blade Runner 2049');
    });
  });
}
