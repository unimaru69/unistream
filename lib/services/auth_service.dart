import 'dart:io';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import '../models/account_info.dart';
import 'supabase_config.dart';

/// Singleton authentication service wrapping Supabase Auth.
///
/// Follows the same fire-and-forget pattern as [SyncService]:
/// methods log errors and return null/void on failure so the app never crashes.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient? get _client => SupabaseConfig.client;

  /// Last fetched account info, cached for imperative checks
  /// (e.g. player screen which doesn't use Riverpod).
  AccountInfo? cachedAccountInfo;

  // ── Session accessors ──

  Session? get currentSession => _client?.auth.currentSession;
  User? get currentUser => _client?.auth.currentUser;
  String? get userId => currentUser?.id;
  bool get isAuthenticated => currentSession != null;

  /// Stream of auth state changes (sign-in, sign-out, token refresh).
  Stream<AuthState>? get onAuthStateChange =>
      _client?.auth.onAuthStateChange;

  // ── Sign Up ──

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client!.auth.signUp(
        email: email,
        password: password,
      );
      AppLogger.info(LogModule.sync, 'Sign up successful: ${response.user?.email}');
      return response;
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Sign up failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Sign In ──

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client!.auth.signInWithPassword(
        email: email,
        password: password,
      );
      AppLogger.info(LogModule.sync, 'Sign in successful: ${response.user?.email}');
      return response;
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Sign in failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Apple Sign-In ──

  /// Returns true if Apple Sign-In is available on this platform AND
  /// runtime build.
  ///
  /// macOS Release: false. Sign in with Apple requires the
  /// `com.apple.developer.applesignin` entitlement which in turn
  /// requires an embedded provisioning profile only available to
  /// App Store / TestFlight builds. Off-store Developer ID DMGs
  /// drop the entitlement (see `macos/Runner/Release.entitlements`)
  /// so AMFI doesn't refuse the binary. macOS Debug keeps the
  /// entitlement (via DebugProfile.entitlements) for `flutter run`
  /// iteration.
  bool get isAppleSignInAvailable {
    if (Platform.isIOS) return true;
    if (Platform.isMacOS) return !kReleaseMode;
    return false;
  }

  Future<AuthResponse?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (credential.identityToken == null) {
        throw Exception('Apple Sign-In: no identity token received');
      }

      final response = await _client!.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
      );
      AppLogger.info(LogModule.sync, 'Apple Sign-In successful: ${response.user?.email}');
      return response;
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Apple Sign-In failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Password Reset ──

  Future<void> resetPassword(String email) async {
    try {
      await _client!.auth.resetPasswordForEmail(email);
      AppLogger.info(LogModule.sync, 'Password reset email sent to $email');
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Password reset failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Magic Link (email OTP) ──
  // Two-step passwordless sign-in: ask Supabase to email a 6-digit
  // code (`signInWithOtp` with `shouldCreateUser: true` so a brand
  // new user is provisioned on first try), then verify the code
  // (`verifyOTP` with `OtpType.email`) which exchanges it for a
  // full session. Used on macOS DMG builds where "Sign in with
  // Apple" is not available (restricted entitlement, see
  // macos/Runner/Release.entitlements) — gives the same one-click
  // feel using only an email address.

  Future<void> sendMagicLink(String email) async {
    try {
      await _client!.auth.signInWithOtp(
        email: email,
        // True so an Apple-only iOS account whose user re-arrives on
        // Mac with the same email can still log in. False would
        // refuse if the email isn't yet in Supabase, which is the
        // wrong default for a magic-link flow.
        shouldCreateUser: true,
      );
      AppLogger.info(LogModule.sync, 'Magic link OTP sent to $email');
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Magic link send failed',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<AuthResponse?> verifyMagicLinkCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _client!.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      AppLogger.info(
          LogModule.sync, 'Magic link verified for ${response.user?.email}');
      return response;
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Magic link verify failed',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Identity linking ──────────────────────────────────────────
  //
  // Goal: one Supabase user, multiple sign-in methods. The canonical
  // cross-device sync trap is an iOS user who signs in via Apple with
  // "Hide my email" → Supabase stores `xyz@privaterelay.appleid.com`.
  // They then open the macOS DMG / Linux AppImage / Windows build and
  // sign in via magic-link with their real address → Supabase creates
  // a SECOND user (different user_id) → favorites / progress are tied
  // to the iOS account, invisible from the desktop.
  //
  // updateEmail() flips the primary email on the currently-signed-in
  // user. Apple Sign-In keeps working because its identity is keyed
  // by the Apple `sub`, not the email. Magic-link OTPs sent to the
  // new email then resolve to the SAME user_id → sync works.
  //
  // Pre-requisite: the new email must NOT already be on another
  // Supabase user (Supabase rejects with `email_exists` otherwise).
  // The UI surfaces this so the user can delete the orphan account
  // from the Supabase dashboard before retrying.

  /// Lists the OAuth + email identities currently linked to the
  /// signed-in user. Each entry's `provider` is `"apple"`,
  /// `"google"`, `"email"`, etc. Returns an empty list when there
  /// is no session.
  List<UserIdentity> get currentIdentities =>
      currentUser?.identities ?? const [];

  /// Sends a confirmation link to [newEmail]. Once the user clicks
  /// the link, Supabase swaps their primary email; OAuth identities
  /// (Apple in particular) remain attached to the same user_id.
  ///
  /// Throws if [newEmail] is malformed or already belongs to another
  /// Supabase user. Caller is expected to localize the error.
  Future<void> updateEmail(String newEmail) async {
    try {
      await _client!.auth.updateUser(UserAttributes(email: newEmail));
      AppLogger.info(LogModule.sync,
          'Email update requested — confirmation sent to $newEmail');
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Email update failed',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Sign Out ──

  Future<void> signOut() async {
    try {
      await _client!.auth.signOut();
      AppLogger.info(LogModule.sync, 'Signed out');
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Sign out failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Delete Account ──

  /// Invokes the `delete-user` Edge Function which:
  /// 1. Deletes all user data from the 5 tables
  /// 2. Deletes the auth user via admin API
  Future<void> deleteAccount() async {
    try {
      final token = _client!.auth.currentSession?.accessToken;
      if (token == null) throw Exception('No active session');
      final response = await _client!.functions.invoke(
        'delete-user',
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.status != 200) {
        throw Exception('Delete account failed: status ${response.status}');
      }
      AppLogger.info(LogModule.sync, 'Account deleted');
      // Clear local session (server-side user is already gone)
      try { await _client!.auth.signOut(); } catch (_) {}
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Delete account failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Claim orphaned data ──

  /// Claims pre-auth data for a given profile hash by setting user_id = auth.uid().
  Future<void> claimProfileData(String profileHash) async {
    try {
      await _client!.rpc('claim_profile_data', params: {
        'p_profile_hash': profileHash,
      });
      AppLogger.info(LogModule.sync, 'Claimed data for profile hash: ${profileHash.substring(0, 8)}…');
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'Claim profile data failed (non-critical)',
          error: e, stackTrace: st);
    }
  }

  // ── Account Info ──

  /// Fetches the user's account info (trial status, subscription, etc.).
  Future<AccountInfo?> fetchAccountInfo() async {
    try {
      final uid = userId;
      if (uid == null) return null;

      final data = await _client!
          .from('user_accounts')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (data == null) return null;
      final info = AccountInfo.fromJson(data);
      cachedAccountInfo = info;
      return info;
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'Fetch account info failed',
          error: e, stackTrace: st);
      return null;
    }
  }
}
