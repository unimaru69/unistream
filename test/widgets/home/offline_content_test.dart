import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/models/continue_watching_item.dart';
import 'package:unistream/providers/favorites_provider.dart';
import 'package:unistream/providers/watch_progress_provider.dart';
import 'package:unistream/screens/home/widgets/offline_content.dart';

void main() {
  group('OfflineContent', () {
    Widget buildOfflineContent({
      VoidCallback? onRetry,
      List<ContinueWatchingItem>? continueItems,
      FavoritesState? favState,
    }) {
      return ProviderScope(
        overrides: [
          continueWatchingProvider.overrideWith(
            (ref) => Future.value(continueItems ?? <ContinueWatchingItem>[]),
          ),
          favoritesProvider.overrideWith((ref) {
            final notifier = FavoritesNotifier();
            return notifier;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: OfflineContent(onRetryConnection: onRetry ?? () {}),
            ),
          ),
        ),
      );
    }

    testWidgets('renders offline banner with cloud_off icon', (tester) async {
      await tester.pumpWidget(buildOfflineContent());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off), findsAtLeast(1));
    });

    testWidgets('renders mode hors ligne text', (tester) async {
      await tester.pumpWidget(buildOfflineContent());
      await tester.pumpAndSettle();

      expect(find.textContaining('Mode hors-ligne'), findsOneWidget);
    });

    testWidgets('renders retry button', (tester) async {
      await tester.pumpWidget(buildOfflineContent());
      await tester.pumpAndSettle();

      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('tapping retry calls onRetryConnection', (tester) async {
      var retryCalled = false;
      await tester
          .pumpWidget(buildOfflineContent(onRetry: () => retryCalled = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Réessayer'));
      expect(retryCalled, isTrue);
    });

    testWidgets('shows empty cache message when no data', (tester) async {
      await tester.pumpWidget(buildOfflineContent());
      await tester.pumpAndSettle();

      // When both continue watching and favorites are empty
      expect(find.text('Aucune donnée en cache disponible'), findsOneWidget);
    });
  });
}
