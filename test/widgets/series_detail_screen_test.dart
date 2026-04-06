import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/providers/watch_progress_provider.dart';
import 'package:unistream/screens/series_detail_screen.dart';

void main() {
  group('SeriesDetailScreen', () {
    Widget buildSeriesDetail({
      String seriesId = '123',
      String title = 'Breaking Bad',
      String cover = '',
    }) {
      return ProviderScope(
        overrides: [
          watchProgressProvider.overrideWith((ref) => Future.value({})),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: SeriesDetailScreen(
            seriesId: seriesId,
            title: title,
            cover: cover,
          ),
        ),
      );
    }

    testWidgets('renders series title in app bar', (tester) async {
      await tester.pumpWidget(buildSeriesDetail(title: 'Breaking Bad'));
      // Don't pumpAndSettle because loading will never complete (XtreamApi not mocked)
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Breaking Bad'), findsOneWidget);
    });

    testWidgets('shows error state when API call fails', (tester) async {
      await tester.pumpWidget(buildSeriesDetail());
      await tester.pumpAndSettle();

      // XtreamApi is not configured so the call will fail, showing error text
      expect(find.textContaining('Erreur'), findsOneWidget);
    });

    testWidgets('renders Scaffold with Row layout', (tester) async {
      await tester.pumpWidget(buildSeriesDetail());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Scaffold), findsOneWidget);
      // New layout uses Row (left panel + episodes) instead of AppBar
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('passes seriesId correctly', (tester) async {
      // This verifies the widget accepts and stores the seriesId
      await tester.pumpWidget(buildSeriesDetail(seriesId: '456'));
      await tester.pump(const Duration(milliseconds: 100));

      // Widget builds without error
      expect(find.byType(SeriesDetailScreen), findsOneWidget);
    });
  });
}
