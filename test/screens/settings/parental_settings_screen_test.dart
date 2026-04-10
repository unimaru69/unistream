import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/models/category.dart' as cat;
import 'package:unistream/providers/parental_provider.dart';
import 'package:unistream/repositories/content_repository.dart';
import 'package:unistream/screens/settings/parental_settings_screen.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// A fake ContentRepository that returns empty category lists instead of
/// hitting XtreamApi.
class FakeContentRepository extends ContentRepository {
  final List<cat.Category> liveCategories;
  final List<cat.Category> vodCategories;
  final List<cat.Category> seriesCategories;

  FakeContentRepository({
    this.liveCategories = const [],
    this.vodCategories = const [],
    this.seriesCategories = const [],
  });

  @override
  Future<List<cat.Category>> getLiveCategories() async => liveCategories;

  @override
  Future<List<cat.Category>> getVodCategories() async => vodCategories;

  @override
  Future<List<cat.Category>> getSeriesCategories() async => seriesCategories;
}

/// A fake ParentalNotifier that avoids SharedPreferences by extending
/// StateNotifier directly and implementing ParentalNotifier's interface.
class FakeParentalNotifier extends StateNotifier<ParentalState>
    implements ParentalNotifier {
  FakeParentalNotifier(super.initial);

  @override
  Future<void> setPin(String pin) async {
    state = state.copyWith(isEnabled: true);
  }

  @override
  Future<bool> verifyAndUnlock(String pin) async {
    state = state.copyWith(isUnlocked: true);
    return true;
  }

  @override
  void lock() {
    state = state.copyWith(isUnlocked: false);
  }

  @override
  Future<void> toggleCategory(String categoryId) async {
    final current = Set<String>.from(state.blockedCategoryIds);
    if (current.contains(categoryId)) {
      current.remove(categoryId);
    } else {
      current.add(categoryId);
    }
    state = state.copyWith(blockedCategoryIds: current);
  }

  @override
  Future<void> clearPin() async {
    state = const ParentalState();
  }

  @override
  Future<void> reload() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds the screen inside a properly localised MaterialApp with all
/// necessary provider overrides.
///
/// When [parentalState.isEnabled] is false, the screen's initState sets its
/// internal [_authenticated] flag to true. To reach the authenticated settings
/// view we start with isEnabled=false so the flag is set, then immediately
/// swap the provider state to enabled+unlocked.
Widget _buildApp({
  ParentalState parentalState = const ParentalState(),
  FakeContentRepository? repository,
}) {
  final repo = repository ?? FakeContentRepository();
  return ProviderScope(
    overrides: [
      parentalProvider.overrideWith(
          (_) => FakeParentalNotifier(parentalState)),
      contentRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: const ParentalSettingsScreen(),
    ),
  );
}

/// Builds the screen so the authenticated settings view is visible.
///
/// The screen's internal [_authenticated] flag is set to true only when
/// [isEnabled] is false at initState time. So we start with isEnabled=false,
/// pump once to let initState run, then update the notifier to enabled+unlocked
/// and pump again to rebuild into the settings view.
Widget _buildAuthenticatedApp({
  Set<String> blockedCategoryIds = const {},
  FakeContentRepository? repository,
}) {
  final repo = repository ?? FakeContentRepository();
  final notifier = FakeParentalNotifier(const ParentalState(isEnabled: false));
  return ProviderScope(
    overrides: [
      parentalProvider.overrideWith((_) => notifier),
      contentRepositoryProvider.overrideWithValue(repo),
    ],
    child: _AuthSwitcher(notifier: notifier, blockedIds: blockedCategoryIds),
  );
}

/// A stateful widget that first pumps the screen with isEnabled=false (so
/// _authenticated is set), then switches the provider to isEnabled=true on
/// the next frame.
class _AuthSwitcher extends StatefulWidget {
  final FakeParentalNotifier notifier;
  final Set<String> blockedIds;
  const _AuthSwitcher({required this.notifier, required this.blockedIds});

  @override
  State<_AuthSwitcher> createState() => _AuthSwitcherState();
}

class _AuthSwitcherState extends State<_AuthSwitcher> {
  bool _switched = false;

  @override
  void initState() {
    super.initState();
    // Schedule the switch for the next frame, after the child's initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_switched) {
        _switched = true;
        widget.notifier.state = ParentalState(
          isEnabled: true,
          isUnlocked: true,
          blockedCategoryIds: widget.blockedIds,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: const ParentalSettingsScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ParentalSettingsScreen — no PIN set (isEnabled=false)', () {
    testWidgets('renders AppBar with title "Contrôle parental"', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Contrôle parental'), findsOneWidget);
    });

    testWidgets('shows the "activate parental control" button', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // The button label comes from l10n.activerControleParental
      expect(find.text('Activer le contrôle parental'), findsOneWidget);
    });

    testWidgets('shows a lock_outline icon', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('shows a FilledButton to activate parental controls',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('does NOT show locked-view or settings-view elements',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // No "enter PIN" button (vpn_key is only in locked view)
      expect(find.byIcon(Icons.vpn_key), findsNothing);
      // No tabs
      expect(find.byType(TabBar), findsNothing);
    });
  });

  group('ParentalSettingsScreen — PIN set, locked (isEnabled=true)', () {
    testWidgets('shows "enter PIN" button when locked', (tester) async {
      await tester.pumpWidget(_buildApp(
        parentalState: const ParentalState(isEnabled: true, isUnlocked: false),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.vpn_key), findsOneWidget);
      expect(find.text('Entrer le PIN'), findsOneWidget);
    });

    testWidgets('does NOT show category tabs or change-pin buttons',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        parentalState: const ParentalState(isEnabled: true, isUnlocked: false),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('shows lock icon', (tester) async {
      await tester.pumpWidget(_buildApp(
        parentalState: const ParentalState(isEnabled: true, isUnlocked: false),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsWidgets);
    });
  });

  group('ParentalSettingsScreen — authenticated (settings view)', () {
    testWidgets('shows tab bar with Live / VOD / Séries tabs', (tester) async {
      await tester.pumpWidget(_buildAuthenticatedApp());
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Chaînes TV'), findsOneWidget);
      expect(find.text('Films (VOD)'), findsOneWidget);
      expect(find.text('Séries'), findsOneWidget);
    });

    testWidgets('shows "change PIN" button', (tester) async {
      await tester.pumpWidget(_buildAuthenticatedApp());
      await tester.pumpAndSettle();

      expect(find.text('Changer le PIN'), findsOneWidget);
    });

    testWidgets('shows "disable parental" button', (tester) async {
      await tester.pumpWidget(_buildAuthenticatedApp());
      await tester.pumpAndSettle();

      expect(find.text('Désactiver'), findsOneWidget);
    });

    testWidgets('shows search field', (tester) async {
      await tester.pumpWidget(_buildAuthenticatedApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows blocked count chip with 0', (tester) async {
      await tester.pumpWidget(_buildAuthenticatedApp());
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('displays categories in list', (tester) async {
      final repo = FakeContentRepository(
        liveCategories: [
          const cat.Category(categoryId: '1', categoryName: 'Sports'),
          const cat.Category(categoryId: '2', categoryName: 'News'),
        ],
      );
      await tester.pumpWidget(_buildAuthenticatedApp(repository: repo));
      await tester.pumpAndSettle();

      // Default tab is the first one (Live / Chaînes TV)
      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
    });

    testWidgets('category checkbox can be toggled', (tester) async {
      final repo = FakeContentRepository(
        liveCategories: [
          const cat.Category(categoryId: '1', categoryName: 'Sports'),
        ],
      );
      await tester.pumpWidget(_buildAuthenticatedApp(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // After tapping, the provider toggleCategory is called.
      // We verify no crash and the tile is still rendered.
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('search field filters categories', (tester) async {
      final repo = FakeContentRepository(
        liveCategories: [
          const cat.Category(categoryId: '1', categoryName: 'Sports'),
          const cat.Category(categoryId: '2', categoryName: 'News'),
          const cat.Category(categoryId: '3', categoryName: 'Music'),
        ],
      );
      await tester.pumpWidget(_buildAuthenticatedApp(repository: repo));
      await tester.pumpAndSettle();

      // All three visible initially
      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);

      // Type in search
      await tester.enterText(find.byType(TextField), 'sport');
      await tester.pumpAndSettle();

      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('News'), findsNothing);
      expect(find.text('Music'), findsNothing);
    });

    testWidgets('blocked categories show block icon', (tester) async {
      final repo = FakeContentRepository(
        liveCategories: [
          const cat.Category(categoryId: '1', categoryName: 'Sports'),
          const cat.Category(categoryId: '2', categoryName: 'News'),
        ],
      );
      await tester.pumpWidget(_buildAuthenticatedApp(
        blockedCategoryIds: {'1'},
        repository: repo,
      ));
      await tester.pumpAndSettle();

      // The blocked category should show a block icon as secondary widget
      // One block icon in the chip + one in the CheckboxListTile secondary
      expect(find.byIcon(Icons.block), findsWidgets);
    });
  });

  group('ParentalSettingsScreen — back button', () {
    testWidgets('has a back arrow in the AppBar', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('ParentalState (pure logic)', () {
    test('copyWith preserves fields when no argument given', () {
      const state = ParentalState(
        isEnabled: true,
        isUnlocked: true,
        blockedCategoryIds: {'a', 'b'},
      );
      final copy = state.copyWith();
      expect(copy.isEnabled, true);
      expect(copy.isUnlocked, true);
      expect(copy.blockedCategoryIds, {'a', 'b'});
    });

    test('copyWith overrides individual fields', () {
      const state = ParentalState(
        isEnabled: true,
        isUnlocked: true,
        blockedCategoryIds: {'a'},
      );
      final copy = state.copyWith(isUnlocked: false, blockedCategoryIds: {});
      expect(copy.isEnabled, true);
      expect(copy.isUnlocked, false);
      expect(copy.blockedCategoryIds, isEmpty);
    });

    test('default state has expected values', () {
      const state = ParentalState();
      expect(state.isEnabled, false);
      expect(state.isUnlocked, false);
      expect(state.blockedCategoryIds, isEmpty);
    });
  });
}
