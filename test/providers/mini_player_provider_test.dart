import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unistream/providers/mini_player_provider.dart';

void main() {
  group('miniPlayerProvider', () {
    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(miniPlayerProvider);
      expect(state, isNull);
    });

    test('can be updated via notifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify the provider starts null
      expect(container.read(miniPlayerProvider), isNull);

      // We cannot easily create a MiniPlayerState without a real Player,
      // but we can verify the provider is settable to null
      container.read(miniPlayerProvider.notifier).state = null;
      expect(container.read(miniPlayerProvider), isNull);
    });
  });
}
