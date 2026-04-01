import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/screens/player/widgets/sleep_timer_dialog.dart';

void main() {
  group('showSleepTimerPicker', () {
    Widget buildApp({
      Duration? sleepRemaining,
      void Function()? onCancel,
      void Function(Duration)? onStart,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showSleepTimerPicker(
                context,
                sleepRemaining: sleepRemaining,
                onCancel: onCancel ?? () {},
                onStart: onStart ?? (_) {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
    }

    testWidgets('shows timer title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Minuterie de veille'), findsOneWidget);
    });

    testWidgets('shows preset duration options', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('15 minutes'), findsOneWidget);
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.text('45 minutes'), findsOneWidget);
      expect(find.text('60 minutes'), findsOneWidget);
      expect(find.text('90 minutes'), findsOneWidget);
      expect(find.text('120 minutes'), findsOneWidget);
    });

    testWidgets('shows timer icons', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.timer), findsAtLeast(1));
    });

    testWidgets('tapping a preset calls onStart with correct duration',
        (tester) async {
      Duration? startedDuration;
      await tester.pumpWidget(buildApp(onStart: (d) => startedDuration = d));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('30 minutes'));
      await tester.pumpAndSettle();

      expect(startedDuration, const Duration(minutes: 30));
    });

    testWidgets('shows cancel option when sleepRemaining is set',
        (tester) async {
      await tester.pumpWidget(
          buildApp(sleepRemaining: const Duration(minutes: 25)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('does not show cancel option when no timer is active',
        (tester) async {
      await tester.pumpWidget(buildApp(sleepRemaining: null));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('tapping cancel calls onCancel', (tester) async {
      var cancelCalled = false;
      await tester.pumpWidget(buildApp(
        sleepRemaining: const Duration(minutes: 25),
        onCancel: () => cancelCalled = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the cancel tile (has the cancel icon)
      await tester.tap(find.byIcon(Icons.cancel));
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });
  });
}
