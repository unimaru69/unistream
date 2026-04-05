import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_config.dart';
import '../services/sync_service.dart';

/// Provides the SyncService singleton.
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService.instance;
});

/// Provides the current profile hash (reactive to config changes).
final profileHashProvider = Provider<String>((ref) {
  return SupabaseConfig.profileHash;
});
