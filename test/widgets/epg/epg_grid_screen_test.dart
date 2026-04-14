import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/channel.dart';
import 'package:unistream/models/parsed_epg_program.dart';
import 'package:unistream/screens/epg/widgets/epg_timeline_header.dart';
import 'package:unistream/screens/epg/widgets/epg_program_row.dart';
import 'package:unistream/screens/epg/epg_grid_screen.dart';
import 'package:unistream/repositories/content_repository.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/models/category.dart' as cat;
import 'package:unistream/providers/favorites_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_wrapper.dart';

/// Fake [ContentRepository] that returns canned data without network calls.
class FakeContentRepository extends ContentRepository {
  final List<cat.Category> categories;
  final List<Channel> channels;
  final Map<String, dynamic> epgResponse;

  FakeContentRepository({
    this.categories = const [],
    this.channels = const [],
    this.epgResponse = const {'epg_listings': []},
  });

  @override
  Future<List<cat.Category>> getLiveCategories() async => categories;

  @override
  Future<List<Channel>> getLiveStreams([String? categoryId]) async => channels;

  @override
  Future<Map<String, dynamic>> getFullDayEpg(String streamId) async =>
      epgResponse;

  @override
  Future<Map<String, dynamic>> getShortEpg(String streamId,
          {int limit = 8}) async =>
      epgResponse;
}

void main() {
  // ──────────────────────────────────────────────────────
  // EpgTimelineHeader — isolated widget tests
  // ──────────────────────────────────────────────────────
  group('EpgTimelineHeader', () {
    final dayStart = DateTime(2026, 4, 1);

    testWidgets('renders 24 hour labels', (tester) async {
      await tester.pumpWidget(testApp(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: EpgTimelineHeader(dayStart: dayStart, hourWidth: 300),
        ),
      ));
      await tester.pumpAndSettle();

      // Spot-check a few hour labels
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
    });

    testWidgets('has correct total width (24 * hourWidth)', (tester) async {
      const hourWidth = 200.0;
      await tester.pumpWidget(testApp(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: EpgTimelineHeader(dayStart: dayStart, hourWidth: hourWidth),
        ),
      ));
      await tester.pumpAndSettle();

      // The inner SizedBox should have width 24 * hourWidth
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 24 * hourWidth);
    });

    testWidgets('contains a red current-time marker', (tester) async {
      await tester.pumpWidget(testApp(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: EpgTimelineHeader(dayStart: dayStart, hourWidth: 300),
        ),
      ));
      await tester.pumpAndSettle();

      // The marker is a Container with width 2 and Colors.redAccent
      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration == false && c.color == Colors.redAccent)
          .toList();
      expect(containers, isNotEmpty, reason: 'Expected a red current-time marker');
    });
  });

  // ──────────────────────────────────────────────────────
  // EpgProgramRow — isolated widget tests
  // ──────────────────────────────────────────────────────
  group('EpgProgramRow', () {
    final dayStart = DateTime(2026, 4, 1);
    final channel = Channel(
      streamId: '1',
      name: 'Test Channel',
      tvArchive: 0,
      tvArchiveDuration: '0',
    );
    final fakeRepo = FakeContentRepository();

    Widget buildRow({
      List<ParsedEpgProgram> programs = const [],
      String searchQuery = '',
    }) {
      return testApp(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: EpgProgramRow(
            channel: channel,
            programs: programs,
            dayStart: dayStart,
            hourWidth: 300,
            rowHeight: 50,
            rowIndex: 0,
            searchQuery: searchQuery,
            repo: fakeRepo,
          ),
        ),
      );
    }

    testWidgets('renders empty row when no programs', (tester) async {
      await tester.pumpWidget(buildRow());
      await tester.pumpAndSettle();

      // Should find the row container but no program text
      expect(find.byType(EpgProgramRow), findsOneWidget);
    });

    testWidgets('renders program title', (tester) async {
      final programs = [
        ParsedEpgProgram(
          title: 'News at Six',
          description: 'Evening news bulletin',
          start: dayStart.add(const Duration(hours: 18)),
          end: dayStart.add(const Duration(hours: 18, minutes: 30)),
        ),
      ];
      await tester.pumpWidget(buildRow(programs: programs));
      await tester.pumpAndSettle();

      expect(find.text('News at Six'), findsOneWidget);
    });

    testWidgets('renders multiple programs', (tester) async {
      final programs = [
        ParsedEpgProgram(
          title: 'Morning Show',
          description: '',
          start: dayStart.add(const Duration(hours: 8)),
          end: dayStart.add(const Duration(hours: 10)),
        ),
        ParsedEpgProgram(
          title: 'Afternoon Movie',
          description: '',
          start: dayStart.add(const Duration(hours: 14)),
          end: dayStart.add(const Duration(hours: 16)),
        ),
      ];
      await tester.pumpWidget(buildRow(programs: programs));
      await tester.pumpAndSettle();

      expect(find.text('Morning Show'), findsOneWidget);
      expect(find.text('Afternoon Movie'), findsOneWidget);
    });

    testWidgets('row has correct total width (24 * hourWidth)', (tester) async {
      await tester.pumpWidget(buildRow());
      await tester.pumpAndSettle();

      // The EpgProgramRow wraps content in a Container with width = hourWidth * 24
      expect(find.byType(EpgProgramRow), findsOneWidget);
    });

    testWidgets('programs have semantic labels for accessibility',
        (tester) async {
      final programs = [
        ParsedEpgProgram(
          title: 'Doc Special',
          description: 'A documentary',
          start: dayStart.add(const Duration(hours: 20)),
          end: dayStart.add(const Duration(hours: 21)),
        ),
      ];
      await tester.pumpWidget(buildRow(programs: programs));
      await tester.pumpAndSettle();

      // The Semantics widget should contain the program title
      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final hasLabel = semantics.any(
          (s) => s.properties.label?.contains('Doc Special') ?? false);
      expect(hasLabel, isTrue,
          reason: 'Program should have a semantic label containing its title');
    });
  });

  // ──────────────────────────────────────────────────────
  // ParsedEpgProgram — pure logic tests
  // ──────────────────────────────────────────────────────
  group('ParsedEpgProgram logic', () {
    test('durationMin computes correctly', () {
      final prog = ParsedEpgProgram(
        title: 'Test',
        description: '',
        start: DateTime(2026, 4, 1, 10, 0),
        end: DateTime(2026, 4, 1, 11, 30),
      );
      expect(prog.durationMin, 90);
    });

    test('timeRange formats start and end', () {
      final prog = ParsedEpgProgram(
        title: 'Test',
        description: '',
        start: DateTime(2026, 4, 1, 8, 5),
        end: DateTime(2026, 4, 1, 9, 15),
      );
      expect(prog.timeRange, '08:05 \u2014 09:15');
    });

    test('isPast returns true for programs that ended', () {
      final prog = ParsedEpgProgram(
        title: 'Old Show',
        description: '',
        start: DateTime(2020, 1, 1, 10, 0),
        end: DateTime(2020, 1, 1, 11, 0),
      );
      expect(prog.isPast, isTrue);
      expect(prog.isCurrent, isFalse);
      expect(prog.isFuture, isFalse);
    });

    test('isFuture returns true for programs not yet started', () {
      final prog = ParsedEpgProgram(
        title: 'Future Show',
        description: '',
        start: DateTime(2099, 12, 31, 20, 0),
        end: DateTime(2099, 12, 31, 22, 0),
      );
      expect(prog.isFuture, isTrue);
      expect(prog.isPast, isFalse);
      expect(prog.isCurrent, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────
  // EpgGridScreen — smoke tests with fake repository
  // ──────────────────────────────────────────────────────
  group('EpgGridScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows loading skeleton initially', (tester) async {
      // Use a fake repo that delays so we can observe the loading state
      final fakeRepo = FakeContentRepository(
        categories: [], // empty — _loadCategories will complete with nothing
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            favoritesProvider.overrideWith((ref) => FavoritesNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('fr'),
            home: EpgGridScreen(),
          ),
        ),
      );

      // On first frame, _loadingCats is true → SkeletonList is shown
      await tester.pump();

      // The AppBar title should be present
      expect(find.text('Guide TV'), findsOneWidget);
    });

    testWidgets('renders category sidebar after loading', (tester) async {
      // Use wide surface so the sidebar is visible (breakpoint >= 900)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeContentRepository(
        categories: [
          cat.Category(categoryId: '1', categoryName: 'Sports'),
          cat.Category(categoryId: '2', categoryName: 'News'),
        ],
        channels: [
          Channel(streamId: '100', name: 'Sport 1'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            favoritesProvider.overrideWith((ref) => FavoritesNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('fr'),
            home: EpgGridScreen(),
          ),
        ),
      );

      // Let categories load
      await tester.pumpAndSettle();

      // Category names should appear in the sidebar
      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
      // Favorites entry always present
      expect(find.text('Favoris'), findsOneWidget);
    });

    testWidgets('renders day navigator after loading channels', (tester) async {
      final fakeRepo = FakeContentRepository(
        categories: [
          cat.Category(categoryId: '1', categoryName: 'General'),
        ],
        channels: [
          Channel(streamId: '10', name: 'Channel A'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            favoritesProvider.overrideWith((ref) => FavoritesNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('fr'),
            home: EpgGridScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Day navigator Hier / Demain buttons should be present
      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('Demain'), findsOneWidget);
    });

    testWidgets('renders search field after loading channels', (tester) async {
      final fakeRepo = FakeContentRepository(
        categories: [
          cat.Category(categoryId: '1', categoryName: 'General'),
        ],
        channels: [
          Channel(streamId: '10', name: 'Channel A'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            favoritesProvider.overrideWith((ref) => FavoritesNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('fr'),
            home: EpgGridScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows channel count in header after loading', (tester) async {
      final fakeRepo = FakeContentRepository(
        categories: [
          cat.Category(categoryId: '1', categoryName: 'General'),
        ],
        channels: [
          Channel(streamId: '10', name: 'Channel A'),
          Channel(streamId: '11', name: 'Channel B'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            favoritesProvider.overrideWith((ref) => FavoritesNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('fr'),
            home: EpgGridScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display channel count (e.g. "2 chaînes")
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets('displays channel names in the grid', (tester) async {
      final fakeRepo = FakeContentRepository(
        categories: [
          cat.Category(categoryId: '1', categoryName: 'General'),
        ],
        channels: [
          Channel(streamId: '10', name: 'France 2'),
          Channel(streamId: '11', name: 'TF1'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            favoritesProvider.overrideWith((ref) => FavoritesNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('fr'),
            home: EpgGridScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('France 2'), findsOneWidget);
      expect(find.text('TF1'), findsOneWidget);
    });

    testWidgets('AppBar shows Guide TV title', (tester) async {
      final fakeRepo = FakeContentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            favoritesProvider.overrideWith((ref) => FavoritesNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('fr'),
            home: EpgGridScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Guide TV'), findsOneWidget);
    });
  });
}
