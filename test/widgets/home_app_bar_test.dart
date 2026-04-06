import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/content_mode.dart';
import 'package:unistream/screens/home/widgets/home_app_bar.dart';

void main() {
  Widget buildTestWidget({
    ContentMode mode = ContentMode.live,
    bool showGrid = false,
    String sortMode = 'default',
  }) {
    return MaterialApp(
      localizationsDelegates: const [],
      home: Scaffold(
        appBar: HomeAppBar(
          mode: mode,
          showGrid: showGrid,
          sortMode: sortMode,
          selectedCategory: null,
          onModeChanged: (_) {},
          onGridToggle: () {},
          onSortChanged: (_) {},
          onEpgPressed: () {},
          onSearchPressed: () {},
          onSettingsPressed: () {},
          onShortcutsPressed: () {},
          onProfileChanged: (_) {},
        ),
      ),
    );
  }

  test('HomeAppBar implements PreferredSizeWidget', () {
    final bar = HomeAppBar(
      mode: ContentMode.live,
      showGrid: false,
      sortMode: 'default',
      selectedCategory: null,
      onModeChanged: (_) {},
      onGridToggle: () {},
      onSortChanged: (_) {},
      onEpgPressed: () {},
      onSearchPressed: () {},
      onSettingsPressed: () {},
      onShortcutsPressed: () {},
      onProfileChanged: (_) {},
    );
    expect(bar, isA<PreferredSizeWidget>());
    expect(bar.preferredSize.height, kToolbarHeight);
  });
}
