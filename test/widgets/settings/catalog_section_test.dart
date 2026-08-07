import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/providers/catalog_refresh_provider.dart';
import 'package:unistream/screens/settings/widgets/catalog_section.dart';

import '../../helpers/test_wrapper.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CatalogSection', () {
    testWidgets('renders the refresh action and the never-refreshed state',
        (tester) async {
      await tester.pumpWidget(testApp(
        const SingleChildScrollView(child: CatalogSection()),
      ));
      await tester.pump();

      expect(find.text('CATALOGUE'), findsOneWidget);
      expect(find.text('Actualiser le catalogue'), findsOneWidget);
      expect(find.text('Dernière actualisation : jamais'), findsOneWidget);
    });

    testWidgets('interval dropdown defaults to 6 h and persists a change',
        (tester) async {
      await tester.pumpWidget(testApp(
        const SingleChildScrollView(child: CatalogSection()),
      ));
      await tester.pump();

      expect(
        tester
            .widget<DropdownButton<CatalogRefreshInterval>>(
                find.byType(DropdownButton<CatalogRefreshInterval>))
            .value,
        CatalogRefreshInterval.sixHours,
      );

      await tester.tap(find.byType(DropdownButton<CatalogRefreshInterval>));
      await tester.pumpAndSettle();
      // The menu duplicates the button's own label, so target the last
      // match — the one inside the opened overlay.
      await tester.tap(find.text('Une fois par jour').last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DropdownButton<CatalogRefreshInterval>>(
                find.byType(DropdownButton<CatalogRefreshInterval>))
            .value,
        CatalogRefreshInterval.daily,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('catalog_auto_refresh_interval'),
          CatalogRefreshInterval.daily.seconds);
    });
  });
}
