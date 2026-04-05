import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/screens/home/widgets/catchup_row.dart';

void main() {
  Widget buildApp({required List<CatchupProgram> programs, void Function(CatchupProgram)? onTap}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(
        body: CatchupRow(
          programs: programs,
          onTap: onTap ?? (_) {},
        ),
      ),
    );
  }

  group('CatchupRow', () {
    testWidgets('renders nothing when programs list is empty', (tester) async {
      await tester.pumpWidget(buildApp(programs: []));
      await tester.pumpAndSettle();
      expect(find.byType(CatchupRow), findsOneWidget);
      // SizedBox.shrink — no visible content
      expect(find.byIcon(Icons.replay), findsNothing);
    });

    testWidgets('renders section title and programs', (tester) async {
      final programs = [
        CatchupProgram(
          streamId: '1',
          channelName: 'TF1',
          channelIcon: '',
          title: 'Journal 20h',
          description: 'Les news',
          startUtc: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
          endUtc: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
          durationMin: 60,
        ),
        CatchupProgram(
          streamId: '2',
          channelName: 'France 2',
          channelIcon: '',
          title: 'Film du soir',
          description: 'Un film',
          startUtc: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
          endUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 30)),
          durationMin: 150,
        ),
      ];
      await tester.pumpWidget(buildApp(programs: programs));
      await tester.pumpAndSettle();

      // Section title
      expect(find.text('Replay disponible'), findsOneWidget);
      // Program titles
      expect(find.text('Journal 20h'), findsOneWidget);
      expect(find.text('Film du soir'), findsOneWidget);
      // Channel names
      expect(find.text('TF1'), findsOneWidget);
      expect(find.text('France 2'), findsOneWidget);
      // Duration
      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('150 min'), findsOneWidget);
    });

    testWidgets('calls onTap when program card is tapped', (tester) async {
      CatchupProgram? tapped;
      final prog = CatchupProgram(
        streamId: '1',
        channelName: 'TF1',
        channelIcon: '',
        title: 'Journal 20h',
        description: '',
        startUtc: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        endUtc: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        durationMin: 60,
      );
      await tester.pumpWidget(buildApp(
        programs: [prog],
        onTap: (p) => tapped = p,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal 20h'));
      expect(tapped?.streamId, '1');
    });

    testWidgets('shows time ago for recently ended programs', (tester) async {
      final programs = [
        CatchupProgram(
          streamId: '1',
          channelName: 'TF1',
          channelIcon: '',
          title: 'News',
          description: '',
          startUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 40)),
          endUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
          durationMin: 30,
        ),
      ];
      await tester.pumpWidget(buildApp(programs: programs));
      await tester.pumpAndSettle();

      // Should show "il y a 10 min" (approximately)
      expect(find.textContaining('il y a'), findsOneWidget);
    });
  });
}
