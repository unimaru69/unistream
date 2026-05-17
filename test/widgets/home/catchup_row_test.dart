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

  group('CatchupRow (non-collapsible)', () {
    testWidgets('renders nothing when programs list is empty', (tester) async {
      await tester.pumpWidget(buildApp(programs: []));
      await tester.pumpAndSettle();
      expect(find.byType(CatchupRow), findsOneWidget);
      expect(find.byIcon(Icons.replay), findsNothing);
    });

    testWidgets('shows header with count', (tester) async {
      await tester.pumpWidget(buildApp(programs: samplePrograms()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Replay disponible'), findsOneWidget);
      expect(find.text('(2)'), findsOneWidget);
    });

    testWidgets('renders programs immediately (no tap needed)', (tester) async {
      await tester.pumpWidget(buildApp(programs: samplePrograms()));
      await tester.pumpAndSettle();

      // Program titles visible from the start — no expand toggle.
      expect(find.text('Journal 20h'), findsOneWidget);
      expect(find.text('Film du soir'), findsOneWidget);
      expect(find.text('TF1'), findsOneWidget);
      expect(find.text('France 2'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('150 min'), findsOneWidget);
    });

    testWidgets('header is not a toggle — no chevron, no InkWell', (tester) async {
      await tester.pumpWidget(buildApp(programs: samplePrograms()));
      await tester.pumpAndSettle();

      // Chevron used to be rendered with `expand_more`; the
      // non-collapsible header should not show it any more.
      expect(find.byIcon(Icons.expand_more), findsNothing);
      // And no InkWell wraps the header.
      expect(find.byType(InkWell), findsNothing);
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

      expect(find.textContaining('il y a'), findsOneWidget);
    });
  });
}
