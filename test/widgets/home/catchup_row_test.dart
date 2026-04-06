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

  List<CatchupProgram> samplePrograms() => [
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

  group('CatchupRow', () {
    testWidgets('renders nothing when programs list is empty', (tester) async {
      await tester.pumpWidget(buildApp(programs: []));
      await tester.pumpAndSettle();
      expect(find.byType(CatchupRow), findsOneWidget);
      expect(find.byIcon(Icons.replay), findsNothing);
    });

    testWidgets('starts collapsed, shows header with count', (tester) async {
      await tester.pumpWidget(buildApp(programs: samplePrograms()));
      await tester.pumpAndSettle();

      // Header visible with count
      expect(find.textContaining('Replay disponible'), findsOneWidget);
      expect(find.text('(2)'), findsOneWidget);
      // Programs NOT visible (collapsed)
      expect(find.text('Journal 20h'), findsNothing);
    });

    testWidgets('renders section title and programs after expanding', (tester) async {
      await tester.pumpWidget(buildApp(programs: samplePrograms()));
      await tester.pumpAndSettle();

      // Tap header to expand
      await tester.tap(find.textContaining('Replay disponible'));
      await tester.pumpAndSettle();

      // Program titles now visible
      expect(find.text('Journal 20h'), findsOneWidget);
      expect(find.text('Film du soir'), findsOneWidget);
      expect(find.text('TF1'), findsOneWidget);
      expect(find.text('France 2'), findsOneWidget);
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

      // Expand first
      await tester.tap(find.textContaining('Replay disponible'));
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

      // Expand first
      await tester.tap(find.textContaining('Replay disponible'));
      await tester.pumpAndSettle();

      expect(find.textContaining('il y a'), findsOneWidget);
    });

    testWidgets('collapses on second tap', (tester) async {
      await tester.pumpWidget(buildApp(programs: samplePrograms()));
      await tester.pumpAndSettle();

      // Expand
      await tester.tap(find.textContaining('Replay disponible'));
      await tester.pumpAndSettle();
      expect(find.text('Journal 20h'), findsOneWidget);

      // Collapse
      await tester.tap(find.textContaining('Replay disponible'));
      await tester.pumpAndSettle();
      expect(find.text('Journal 20h'), findsNothing);
    });
  });
}
