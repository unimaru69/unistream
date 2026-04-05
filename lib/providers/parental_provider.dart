import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config.dart';
import '../services/parental_service.dart';

class ParentalState {
  /// Whether a PIN has been configured (parental controls enabled).
  final bool isEnabled;

  /// Whether the current session is unlocked (PIN was entered).
  final bool isUnlocked;

  /// Category IDs that are blocked when locked.
  final Set<String> blockedCategoryIds;

  const ParentalState({
    this.isEnabled = false,
    this.isUnlocked = false,
    this.blockedCategoryIds = const {},
  });

  ParentalState copyWith({
    bool? isEnabled,
    bool? isUnlocked,
    Set<String>? blockedCategoryIds,
  }) {
    return ParentalState(
      isEnabled: isEnabled ?? this.isEnabled,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      blockedCategoryIds: blockedCategoryIds ?? this.blockedCategoryIds,
    );
  }
}

class ParentalNotifier extends StateNotifier<ParentalState> {
  ParentalNotifier() : super(const ParentalState()) {
    _load();
  }

  Future<void> _load() async {
    final hasPin = await ParentalService.hasPin();
    final blocked = await ParentalService.getBlockedCategories(
        AppConfig.activeProfileId);
    state = ParentalState(
      isEnabled: hasPin,
      isUnlocked: false,
      blockedCategoryIds: blocked,
    );
  }

  /// Set a new PIN (enables parental controls).
  Future<void> setPin(String pin) async {
    await ParentalService.setPin(pin);
    state = state.copyWith(isEnabled: true);
  }

  /// Verify PIN and unlock the session if correct. Returns true on success.
  Future<bool> verifyAndUnlock(String pin) async {
    final ok = await ParentalService.verifyPin(pin);
    if (ok) {
      state = state.copyWith(isUnlocked: true);
    }
    return ok;
  }

  /// Lock the session (re-engage parental controls).
  void lock() {
    state = state.copyWith(isUnlocked: false);
  }

  /// Toggle a category between blocked and unblocked.
  Future<void> toggleCategory(String categoryId) async {
    final current = Set<String>.from(state.blockedCategoryIds);
    if (current.contains(categoryId)) {
      current.remove(categoryId);
    } else {
      current.add(categoryId);
    }
    await ParentalService.setBlockedCategories(
        AppConfig.activeProfileId, current);
    state = state.copyWith(blockedCategoryIds: current);
  }

  /// Remove the PIN entirely (disables parental controls).
  Future<void> clearPin() async {
    await ParentalService.clearPin();
    await ParentalService.setBlockedCategories(
        AppConfig.activeProfileId, {});
    state = const ParentalState(
      isEnabled: false,
      isUnlocked: false,
      blockedCategoryIds: {},
    );
  }

  /// Reload state (e.g. after profile switch).
  Future<void> reload() async => _load();
}

final parentalProvider =
    StateNotifierProvider<ParentalNotifier, ParentalState>((ref) {
  return ParentalNotifier();
});
