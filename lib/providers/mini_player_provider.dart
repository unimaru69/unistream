import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart' show MiniPlayerState;

/// Provider for mini-player state.
/// Note: The overlay system (navKey, OverlayEntry) remains global for now
/// because it requires direct access to the Navigator overlay.
/// This provider tracks the state for reactive UI updates.
final miniPlayerProvider = StateProvider<MiniPlayerState?>((ref) => null);
