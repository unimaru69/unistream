import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/services/auth_service.dart';

void main() {
  group('AuthService', () {
    test('is a singleton', () {
      expect(AuthService.instance, same(AuthService.instance));
    });

    test('isAuthenticated is false when Supabase not initialized', () {
      // SupabaseConfig.client is null in test environment
      expect(AuthService.instance.isAuthenticated, isFalse);
    });

    test('currentSession is null when Supabase not initialized', () {
      expect(AuthService.instance.currentSession, isNull);
    });

    test('currentUser is null when Supabase not initialized', () {
      expect(AuthService.instance.currentUser, isNull);
    });

    test('userId is null when Supabase not initialized', () {
      expect(AuthService.instance.userId, isNull);
    });

    test('onAuthStateChange is null when Supabase not initialized', () {
      expect(AuthService.instance.onAuthStateChange, isNull);
    });

    test('fetchAccountInfo returns null when Supabase not initialized', () async {
      final result = await AuthService.instance.fetchAccountInfo();
      expect(result, isNull);
    });

    test('claimProfileData does not throw when Supabase not initialized', () async {
      // Should fail gracefully (client is null → TypeError caught)
      // In real app, _client is null → throws, caught by try/catch
      await AuthService.instance.claimProfileData('test-hash');
      // No exception = success
    });
  });
}
