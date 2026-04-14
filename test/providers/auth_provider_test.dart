import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/providers/auth_provider.dart';

void main() {
  group('AuthState', () {
    test('default state is loading', () {
      const state = AuthState();
      expect(state.isLoading, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
      expect(state.accountInfo, isNull);
      expect(state.error, isNull);
    });

    test('copyWith preserves existing values', () {
      const state = AuthState(isLoading: false, isAuthenticated: true);
      final updated = state.copyWith(error: 'oops');
      expect(updated.isLoading, isFalse);
      expect(updated.isAuthenticated, isTrue);
      expect(updated.error, 'oops');
    });

    test('copyWith clearError sets error to null', () {
      const state = AuthState(error: 'something');
      final updated = state.copyWith(clearError: true);
      expect(updated.error, isNull);
    });

    test('copyWith clearUser sets user to null', () {
      const state = AuthState(isAuthenticated: true);
      final updated = state.copyWith(clearUser: true);
      expect(updated.user, isNull);
    });

    test('copyWith clearAccountInfo sets accountInfo to null', () {
      const state = AuthState();
      final updated = state.copyWith(clearAccountInfo: true);
      expect(updated.accountInfo, isNull);
    });
  });

  group('AuthNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state resolves to unauthenticated when Supabase not initialized', () async {
      // AuthNotifier._init() checks AuthService.instance.currentSession
      // which is null when Supabase is not initialized
      // Give time for _init() async to complete
      await Future.delayed(const Duration(milliseconds: 50));
      final state = container.read(authProvider);
      expect(state.isLoading, isFalse);
      expect(state.isAuthenticated, isFalse);
    });

    test('signOut sets unauthenticated state', () async {
      await Future.delayed(const Duration(milliseconds: 50));
      await container.read(authProvider.notifier).signOut();
      final state = container.read(authProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.user, isNull);
      expect(state.accountInfo, isNull);
    });

    test('clearError removes the error from state', () async {
      await Future.delayed(const Duration(milliseconds: 50));
      container.read(authProvider.notifier).clearError();
      final state = container.read(authProvider);
      expect(state.error, isNull);
    });
  });
}
