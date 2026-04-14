import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import '../models/app_config.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl =
      'https://aslqfsoyhjuomfxopsvs.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzbHFmc295aGp1b21meG9wc3ZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzNDUxODEsImV4cCI6MjA5MDkyMTE4MX0.UdfG1MJmVrGLHgdqT3uYbOKJKJnUcnTWW-z7Qq1WmyI';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _initialized = true;
      final session = Supabase.instance.client.auth.currentSession;
      AppLogger.info(LogModule.sync,
          'Supabase initialized — session=${session != null ? "exists (${session.user.email})" : "null"}');
    } catch (e, st) {
      AppLogger.error(
        LogModule.sync,
        'Supabase initialization FAILED (sync disabled)',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Whether Supabase was successfully initialized.
  static bool get isAvailable => _initialized;

  /// Returns the Supabase client, or null if not initialized.
  static SupabaseClient? get client =>
      _initialized ? Supabase.instance.client : null;

  /// Compute a SHA-256 profile hash from the current AppConfig credentials.
  /// Returns an empty string if not configured.
  static String get profileHash {
    if (AppConfig.serverUrl.isEmpty || AppConfig.username.isEmpty) return '';
    return computeProfileHash(AppConfig.serverUrl, AppConfig.username);
  }

  /// Compute a profile hash for arbitrary server/user values.
  static String computeProfileHash(String serverUrl, String username) {
    final input = '$serverUrl:$username';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Returns the current authenticated user's ID, or null.
  static String? get currentUserId => client?.auth.currentUser?.id;
}
