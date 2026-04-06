import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/content_mode.dart';
import 'package:unistream/models/favorite_item.dart';
import 'package:unistream/screens/home/widgets/category_sidebar.dart';

import '../../helpers/mock_data.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('CategorySidebar', () {
    Widget buildSidebar({
      List<dynamic>? categories,
      String? selectedCategory,
      List<FavoriteItem> favItems = const [],
      List<FavoriteItem> wlItems = const [],
      List<Map<String, dynamic>> collections = const [],
      void Function(String)? onCategorySelected,
      void Function(String, List<Map<String, dynamic>>)? onSpecialCategorySelected,
      VoidCallback? onHistoryTap,
      VoidCallback? onCreateCollection,
      void Function(String)? onCollectionSelected,
      void Function(String)? onDeleteCollection,
    }) {
      return testApp(
        SizedBox(
          width: 250,
          height: 600,
          child: CategorySidebar(
            width: 200,
            minWidth: 150,
            maxWidth: 300,
            onWidthChanged: (_) {},
            onDragEnd: () {},
            categories: categories?.cast() ??
                [mockCategory(id: '1', name: 'Films'), mockCategory(id: '2', name: 'Sports')],
            collections: collections,
            mode: ContentMode.vod,
            selectedCategory: selectedCategory,
            progress: const {},
            favItems: favItems,
            wlItems: wlItems,
            onCategorySelected: onCategorySelected ?? (_) {},
            onSpecialCategorySelected: onSpecialCategorySelected ?? (_, __) {},
            onHistoryTap: onHistoryTap ?? () {},
            onCreateCollection: onCreateCollection ?? () {},
            onCollectionSelected: onCollectionSelected ?? (_) {},
            onDeleteCollection: onDeleteCollection ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('renders category names', (tester) async {
      await tester.pumpWidget(buildSidebar());
      await tester.pumpAndSettle();

      expect(find.text('Films'), findsOneWidget);
      expect(find.text('Sports'), findsOneWidget);
    });

    testWidgets('renders Favoris row', (tester) async {
      await tester.pumpWidget(buildSidebar());
      await tester.pumpAndSettle();

      expect(find.text('Favoris'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('renders Historique row', (tester) async {
      await tester.pumpWidget(buildSidebar());
      await tester.pumpAndSettle();

      expect(find.text('Historique'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('tap on category calls onCategorySelected', (tester) async {
      String? tappedId;
      await tester.pumpWidget(buildSidebar(
        onCategorySelected: (id) => tappedId = id,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Films'));
      expect(tappedId, '1');
    });

    testWidgets('tap on Historique calls onHistoryTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildSidebar(
        onHistoryTap: () => tapped = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Historique'));
      expect(tapped, isTrue);
    });
  });
}
