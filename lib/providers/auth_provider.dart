import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import '../models/account_info.dart';
import '../services/auth_service.dart';
import '../services/supabase_config.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final User? user;
  final AccountInfo? accountInfo;
  final String? error;

  const AuthState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.user,
    this.accountInfo,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    User? user,
    AccountInfo? accountInfo,
    String? error,
    bool clearError = false,
    bool clearUser = false,
    bool clearAccountInfo = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: clearUser ? null : (user ?? this.user),
      accountInfo: clearAccountInfo ? null : (accountInfo ?? this.accountInfo),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  final _auth = AuthService.instance;
  StreamSubscription<AuthState>? _authSub;

  Future<void> _init() async {
    // Check for existing session (auto-restored by supabase_flutter)
    final supabaseAvailable = SupabaseConfig.isAvailable;
    final session = _auth.currentSession;
    AppLogger.info(LogModule.sync,
        'AuthNotifier._init: supabaseAvailable=$supabaseAvailable, '
        'session=${session != null ? "exists" : "null"}, '
        'user=${_auth.currentUser?.email ?? "none"}');
    if (session != null) {
      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        user: _auth.currentUser,
      );
      // Fetch account info in background
      _fetchAccountInfo();
    } else {
      state = const AuthState(isLoading: false, isAuthenticated: false);
    }
  }

  Future<void> _fetchAccountInfo() async {
    final info = await _auth.fetchAccountInfo();
    if (info != null && mounted) {
      state = state.copyWith(accountInfo: info);
    }
  }

  // ── Sign Up ──

  Future<bool> signUp({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _auth.signUp(email: email, password: password);
      if (!mounted) return false;
      if (response?.user != null) {
        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          user: response!.user,
        );
        _fetchAccountInfo();
        return true;
      }
      // Email confirmation may be required
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: _mapError(e),
      );
      return false;
    }
  }

  // ── Sign In ──

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _auth.signIn(email: email, password: password);
      if (!mounted) return false;
      if (response?.user != null) {
        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          user: response!.user,
        );
        _fetchAccountInfo();
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Authentication failed');
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: _mapError(e),
      );
      return false;
    }
  }

  // ── Apple Sign-In ──

  Future<bool> signInWithApple() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _auth.signInWithApple();
      if (!mounted) return false;
      if (response?.user != null) {
        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          user: response!.user,
        );
        _fetchAccountInfo();
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: _mapError(e),
      );
      return false;
    }
  }

  // ── Password Reset ──

  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _auth.resetPassword(email);
      if (!mounted) return false;
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: _mapError(e),
      );
      return false;
    }
  }

  // ── Magic Link (passwordless email OTP) ──

  /// Requests Supabase to email a 6-digit code for [email].
  /// Returns true when the send succeeded.
  Future<bool> sendMagicLink(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _auth.sendMagicLink(email);
      if (!mounted) return false;
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, error: _mapError(e));
      return false;
    }
  }

  /// Verifies the 6-10 digit OTP. On success Supabase returns a
  /// session and we flip our local AuthState to authenticated so
  /// AuthGate picks it up and routes to the splash flow.
  ///
  /// Earlier version relied on an `onAuthStateChange` listener
  /// supposedly flipping `isAuthenticated` automatically — but
  /// `AuthNotifier` only reads `currentSession` once at startup
  /// (see `_init`). So we have to mirror what `signIn` / `signUp`
  /// do: update state explicitly with the user from the response.
  Future<bool> verifyMagicLinkCode({
    required String email,
    required String code,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response =
          await _auth.verifyMagicLinkCode(email: email, code: code);
      if (!mounted) return false;
      if (response?.user != null) {
        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          user: response!.user,
        );
        _fetchAccountInfo();
        return true;
      }
      // Supabase returned no user — unexpected but treat as failure.
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, error: _mapError(e));
      return false;
    }
  }

  // ── Sign Out ──

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    state = const AuthState(
      isLoading: false,
      isAuthenticated: false,
    );
  }

  // ── Delete Account ──

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _auth.deleteAccount();
      if (!mounted) return false;
      state = const AuthState(
        isLoading: false,
        isAuthenticated: false,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: _mapError(e),
      );
      return false;
    }
  }

  // ── Refresh Account Info ──

  Future<void> refreshAccountInfo() async {
    await _fetchAccountInfo();
  }

  // ── Clear Error ──

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ── Error mapping ──

  String _mapError(Object e) {
    if (e is AuthException) {
      return e.message;
    }
    final msg = e.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'Invalid email or password';
    }
    if (msg.contains('User already registered')) {
      return 'An account with this email already exists';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Please confirm your email before signing in';
    }
    return 'An error occurred. Please try again.';
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
