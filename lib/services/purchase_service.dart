import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/logger.dart';

/// RevenueCat API key for Apple platforms.
///
/// This is the **public** API key — safe to embed in the client.
/// Replace with your actual key from the RevenueCat dashboard.
const _revenueCatAppleApiKey = 'appl_hCGnNALIWCBnGEVfAGBDCmodKTR';

/// Singleton service wrapping the RevenueCat SDK.
///
/// On unsupported platforms (Windows/Linux), all methods are safe no-ops.
class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  bool _initialized = false;

  /// Whether the current platform supports in-app purchases.
  bool get isPlatformSupported => Platform.isIOS || Platform.isMacOS;

  /// Whether the SDK has been initialized.
  bool get isInitialized => _initialized;

  /// Initialize RevenueCat with the given Supabase [appUserId].
  ///
  /// Must be called after Supabase auth is ready. No-op on unsupported platforms.
  Future<void> initialize(String appUserId) async {
    if (!isPlatformSupported) return;
    if (_initialized) {
      // Already initialized — just log in the new user
      try {
        await Purchases.logIn(appUserId);
      } catch (e, st) {
        AppLogger.warning(LogModule.sync, 'RevenueCat logIn failed', error: e, stackTrace: st);
      }
      return;
    }

    try {
      final config = PurchasesConfiguration(_revenueCatAppleApiKey)
        ..appUserID = appUserId;
      await Purchases.configure(config);
      _initialized = true;
      AppLogger.info(LogModule.sync, 'RevenueCat initialized for user: ${appUserId.substring(0, 8)}…');
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'RevenueCat init failed', error: e, stackTrace: st);
    }
  }

  /// Fetch available offerings (products/packages).
  Future<Offerings?> getOfferings() async {
    if (!isPlatformSupported || !_initialized) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'getOfferings failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Purchase a specific [package].
  ///
  /// Returns the [CustomerInfo] after purchase, or null on failure/cancellation.
  Future<CustomerInfo?> purchase(Package package) async {
    if (!isPlatformSupported || !_initialized) return null;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      AppLogger.info(LogModule.sync, 'Purchase successful');
      return result.customerInfo;
    } on PlatformException catch (e) {
      // User cancelled
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) {
        AppLogger.info(LogModule.sync, 'Purchase cancelled by user');
        return null;
      }
      AppLogger.error(LogModule.sync, 'Purchase failed', error: e);
      rethrow;
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Purchase failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Restore previous purchases.
  Future<CustomerInfo?> restorePurchases() async {
    if (!isPlatformSupported || !_initialized) return null;
    try {
      final info = await Purchases.restorePurchases();
      AppLogger.info(LogModule.sync, 'Purchases restored');
      return info;
    } catch (e, st) {
      AppLogger.error(LogModule.sync, 'Restore purchases failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get current customer info (entitlements, subscriptions).
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!isPlatformSupported || !_initialized) return null;
    try {
      return await Purchases.getCustomerInfo();
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'getCustomerInfo failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Listen for customer info updates (subscription changes, etc.).
  void addCustomerInfoListener(CustomerInfoUpdateListener listener) {
    if (!isPlatformSupported) return;
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  /// Remove a customer info listener.
  void removeCustomerInfoListener(CustomerInfoUpdateListener listener) {
    if (!isPlatformSupported) return;
    Purchases.removeCustomerInfoUpdateListener(listener);
  }

  /// Log out the current RevenueCat user (e.g. on sign-out).
  Future<void> logOut() async {
    if (!isPlatformSupported || !_initialized) return;
    try {
      await Purchases.logOut();
      AppLogger.info(LogModule.sync, 'RevenueCat user logged out');
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'RevenueCat logOut failed', error: e, stackTrace: st);
    }
  }
}
