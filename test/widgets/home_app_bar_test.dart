import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/content_mode.dart';
import 'package:unistream/screens/home/widgets/home_app_bar.dart';

void main() {
  test('HomeAppBar implements PreferredSizeWidget', () {
    final bar = HomeAppBar(
      segment: HomeSegment.live,
      showGrid: false,
      sortMode: 'default',
      selectedCategory: null,
      onSegmentChanged: (_) {},
      onGridToggle: () {},
      onSortChanged: (_) {},
      onEpgPressed: () {},
      onSearchPressed: () {},
      onFavoritesPressed: () {},
      onSettingsPressed: () {},
      onShortcutsPressed: () {},
      onProfileChanged: (_) {},
    );
    expect(bar, isA<PreferredSizeWidget>());
    expect(bar.preferredSize.height, kToolbarHeight);
  });
}
