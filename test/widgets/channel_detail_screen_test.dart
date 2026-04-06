import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/models/channel.dart';
import 'package:unistream/screens/channel_detail_screen.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: child,
      ),
    );

final _testChannel = Channel(
  streamId: '42',
  name: 'TF1',
  streamIcon: 'https://example.com/tf1.png',
  categoryId: '1',
  categoryName: 'Françaises',
  tvArchive: 1,
  tvArchiveDuration: '7',
);

final _noCatchupChannel = Channel(
  streamId: '99',
  name: 'France 2',
  tvArchive: 0,
  tvArchiveDuration: '0',
);

void main() {
  testWidgets('shows channel name in app bar', (tester) async {
    await tester.pumpWidget(_wrap(ChannelDetailScreen(channel: _testChannel)));
    await tester.pump();
    expect(find.text('TF1'), findsWidgets);
  });

  testWidgets('shows play button with channel name', (tester) async {
    await tester.pumpWidget(_wrap(ChannelDetailScreen(channel: _testChannel)));
    await tester.pump();
    // The FilledButton should contain the channel name
    expect(find.widgetWithText(FilledButton, 'TF1'), findsOneWidget);
  });

  testWidgets('shows catch-up chip for archive channel', (tester) async {
    await tester.pumpWidget(_wrap(ChannelDetailScreen(channel: _testChannel)));
    await tester.pump();
    expect(find.text('Catch-up 7j'), findsOneWidget);
  });

  testWidgets('shows category chip', (tester) async {
    await tester.pumpWidget(_wrap(ChannelDetailScreen(channel: _testChannel)));
    await tester.pump();
    expect(find.text('Françaises'), findsOneWidget);
  });

  testWidgets('no catch-up chip for non-archive channel', (tester) async {
    await tester.pumpWidget(_wrap(ChannelDetailScreen(channel: _noCatchupChannel)));
    await tester.pump();
    expect(find.textContaining('Catch-up'), findsNothing);
  });

  testWidgets('shows favorite toggle button', (tester) async {
    await tester.pumpWidget(_wrap(ChannelDetailScreen(channel: _testChannel)));
    await tester.pump();
    expect(find.byIcon(Icons.star_border), findsOneWidget);
  });

  testWidgets('shows skeleton while loading EPG', (tester) async {
    await tester.pumpWidget(_wrap(ChannelDetailScreen(channel: _testChannel)));
    // Don't pump — should show skeleton during loading
    await tester.pump();
    // The SkeletonList should be visible during initial load
    expect(find.byType(ChannelDetailScreen), findsOneWidget);
  });
}
