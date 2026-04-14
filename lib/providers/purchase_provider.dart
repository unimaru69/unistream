import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/purchase_service.dart';
import 'auth_provider.dart';

class PurchaseState {
  /// Whether the platform supports IAP (iOS/macOS).
  final bool isAvailable;

  /// Whether an operation (purchase, restore) is in progress.
  final bool isLoading;

  /// Available offerings from RevenueCat.
  final Offerings? offerings;

  /// The user's active entitlement identifier ('basic', 'premium'), or null.
  final String? activeEntitlement;

  /// Error message from the last operation.
  final String? error;

  const PurchaseState({
    this.isAvailable = false,
    this.isLoading = false,
    this.offerings,
    this.activeEntitlement,
    this.error,
  });

  PurchaseState copyWith({
    bool? isAvailable,
    bool? isLoading,
    Offerings? offerings,
    String? activeEntitlement,
    String? error,
    bool clearError = false,
    bool clearEntitlement = false,
  }) {
    return PurchaseState(
      isAvailable: isAvailable ?? this.isAvailable,
      isLoading: isLoading ?? this.isLoading,
      offerings: offerings ?? this.offerings,
      activeEntitlement:
          clearEntitlement ? null : (activeEntitlement ?? this.activeEntitlement),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PurchaseNotifier extends StateNotifier<PurchaseState> {
  PurchaseNotifier(this._ref) : super(const PurchaseState());

  final Ref _ref;
  final _service = PurchaseService.instance;

  /// Initialize RevenueCat and fetch offerings.
  ///
  /// Call this after the user is authenticated.
  Future<void> initialize(String appUserId) async {
    if (!_service.isPlatformSupported) return;

    state = state.copyWith(isAvailable: true, isLoading: true, clearError: true);

    await _service.initialize(appUserId);
    if (!mounted) return;

    // Fetch offerings
    final offerings = await _service.getOfferings();
    if (!mounted) return;

    // Get current entitlements
    final customerInfo = await _service.getCustomerInfo();
    if (!mounted) return;
    final entitlement = _activeEntitlement(customerInfo);

    state = state.copyWith(
      isLoading: false,
      offerings: offerings,
      activeEntitlement: entitlement,
      clearEntitlement: entitlement == null,
    );

    // Listen for customer info changes
    _service.addCustomerInfoListener(_onCustomerInfoUpdate);
  }

  void _onCustomerInfoUpdate(CustomerInfo info) {
    if (!mounted) return;
    final entitlement = _activeEntitlement(info);
    state = state.copyWith(
      activeEntitlement: entitlement,
      clearEntitlement: entitlement == null,
    );
    // Refresh account info from Supabase (webhook may have updated it)
    _ref.read(authProvider.notifier).refreshAccountInfo();
  }

  /// Purchase a package. Returns true on success.
  Future<bool> purchase(Package package) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final info = await _service.purchase(package);
      if (!mounted) return false;
      if (info != null) {
        final entitlement = _activeEntitlement(info);
        state = state.copyWith(
          isLoading: false,
          activeEntitlement: entitlement,
          clearEntitlement: entitlement == null,
        );
        _ref.read(authProvider.notifier).refreshAccountInfo();
        return true;
      }
      // User cancelled
      state = state.copyWith(isLoading: false);
      return false;
    } on PlatformException {
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, error: 'Purchase failed');
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Restore purchases. Returns true on success.
  Future<bool> restore() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final info = await _service.restorePurchases();
      if (!mounted) return false;
      if (info != null) {
        final entitlement = _activeEntitlement(info);
        state = state.copyWith(
          isLoading: false,
          activeEntitlement: entitlement,
          clearEntitlement: entitlement == null,
        );
        _ref.read(authProvider.notifier).refreshAccountInfo();
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Log out from RevenueCat (call on sign-out).
  Future<void> logOut() async {
    await _service.logOut();
    if (!mounted) return;
    state = const PurchaseState();
  }

  /// Extract the highest active entitlement from customer info.
  String? _activeEntitlement(CustomerInfo? info) {
    if (info == null) return null;
    final entitlements = info.entitlements.active;
    if (entitlements.containsKey('premium')) return 'premium';
    if (entitlements.containsKey('basic')) return 'basic';
    return null;
  }

  @override
  void dispose() {
    _service.removeCustomerInfoListener(_onCustomerInfoUpdate);
    super.dispose();
  }
}

final purchaseProvider =
    StateNotifierProvider<PurchaseNotifier, PurchaseState>((ref) {
  return PurchaseNotifier(ref);
});
