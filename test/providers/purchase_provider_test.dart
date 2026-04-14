import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/providers/purchase_provider.dart';

void main() {
  group('PurchaseState', () {
    test('default state has correct values', () {
      const state = PurchaseState();
      expect(state.isAvailable, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.offerings, isNull);
      expect(state.activeEntitlement, isNull);
      expect(state.error, isNull);
    });

    test('copyWith preserves unchanged values', () {
      const state = PurchaseState(
        isAvailable: true,
        isLoading: false,
        activeEntitlement: 'premium',
      );
      final updated = state.copyWith(isLoading: true);
      expect(updated.isAvailable, isTrue);
      expect(updated.isLoading, isTrue);
      expect(updated.activeEntitlement, 'premium');
      expect(updated.error, isNull);
    });

    test('copyWith clearError removes error', () {
      const state = PurchaseState(error: 'something failed');
      final updated = state.copyWith(clearError: true);
      expect(updated.error, isNull);
    });

    test('copyWith clearEntitlement removes entitlement', () {
      const state = PurchaseState(activeEntitlement: 'basic');
      final updated = state.copyWith(clearEntitlement: true);
      expect(updated.activeEntitlement, isNull);
    });

    test('copyWith can set new entitlement', () {
      const state = PurchaseState(activeEntitlement: 'basic');
      final updated = state.copyWith(activeEntitlement: 'premium');
      expect(updated.activeEntitlement, 'premium');
    });

    test('copyWith can set error', () {
      const state = PurchaseState();
      final updated = state.copyWith(error: 'Network error');
      expect(updated.error, 'Network error');
    });
  });
}
