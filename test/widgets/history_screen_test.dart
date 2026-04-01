import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/providers/watch_progress_provider.dart';
import 'package:unistream/screens/history_screen.dart';

/// A fake HistoryNotifier that returns controlled data without touching SharedPreferences.
class FakeHistoryNotifier extends StateNotifier<AsyncValue<List<Map<String, String>>>>
    implements HistoryNotifier {
  FakeHistoryNotifier(List<Map<String, String>> data)
      : super(AsyncValue.data(data));

  @override
  Future<void> load() async {}

  @override
  Future<void> deleteEntry(String key) async {}

  @override
  Future<void> reInsertEntry(Map<String, String> entry) async {}

  @override
  Future<void> clearAll() async {
    state = const AsyncValue.data([]);
  }
}

void main() {
  group('HistoryScreen', () {
    Widget buildHistory({List<Map<String, String>>? items}) {
      final data = items ?? [];
      return ProviderScope(
        overrides: [
          historyProvider.overrideWith((_) => FakeHistoryNotifier(data)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: const HistoryScreen(),
        ),
      );
    }

    testWidgets('renders title Historique', (tester) async {
      await tester.pumpWidget(buildHistory());
      await tester.pumpAndSettle();

      expect(find.text('Historique'), findsOneWidget);
    });

    testWidgets('shows empty state message when no history', (tester) async {
      await tester.pumpWidget(buildHistory());
      await tester.pumpAndSettle();

      expect(find.text('Aucun historique'), findsOneWidget);
    });

    testWidgets('renders history items', (tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.pumpWidget(buildHistory(items: [
        {
          'name': 'Test Movie',
          'mode': 'vod',
          'cover': '',
          'url': 'http://test.com/movie.mp4',
          'timestamp': now,
          'key': 'vod:1',
        },
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Test Movie'), findsOneWidget);
      expect(find.text('VOD'), findsOneWidget);
    });

    testWidgets('renders mode badge with correct label', (tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.pumpWidget(buildHistory(items: [
        {
          'name': 'Live Channel',
          'mode': 'live',
          'cover': '',
          'url': 'http://test.com/live',
          'timestamp': now,
          'key': 'live:1',
        },
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('shows clear button when history is not empty', (tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.pumpWidget(buildHistory(items: [
        {
          'name': 'Something',
          'mode': 'vod',
          'cover': '',
          'url': '',
          'timestamp': now,
          'key': 'vod:1',
        },
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Effacer l\'historique'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsAtLeast(1));
    });

    testWidgets('does not show clear button when history is empty',
        (tester) async {
      await tester.pumpWidget(buildHistory());
      await tester.pumpAndSettle();

      expect(find.text('Effacer l\'historique'), findsNothing);
    });

    testWidgets('each item has a delete icon button', (tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.pumpWidget(buildHistory(items: [
        {
          'name': 'Item 1',
          'mode': 'vod',
          'cover': '',
          'url': '',
          'timestamp': now,
          'key': 'vod:1',
        },
      ]));
      await tester.pumpAndSettle();

      // The trailing delete icon button on the list tile
      expect(find.byIcon(Icons.delete_outline), findsAtLeast(1));
    });

    testWidgets('shows play_circle icon when no cover', (tester) async {
      final now = DateTime.now().toIso8601String();
      await tester.pumpWidget(buildHistory(items: [
        {
          'name': 'No Cover Item',
          'mode': 'vod',
          'cover': '',
          'url': '',
          'timestamp': now,
          'key': 'vod:1',
        },
      ]));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle), findsOneWidget);
    });
  });
}
