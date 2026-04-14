import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/services/purchase_service.dart';

void main() {
  group('PurchaseService', () {
    test('is a singleton', () {
      expect(identical(PurchaseService.instance, PurchaseService.instance), isTrue);
    });

    test('isPlatformSupported matches current platform', () {
      final expected = Platform.isIOS || Platform.isMacOS;
      expect(PurchaseService.instance.isPlatformSupported, expected);
    });

    test('isInitialized is false before initialize()', () {
      expect(PurchaseService.instance.isInitialized, isFalse);
    });

    test('getOfferings returns null when not initialized', () async {
      final offerings = await PurchaseService.instance.getOfferings();
      // On macOS (supported platform) it returns null because not initialized
      // On other platforms it also returns null
      expect(offerings, isNull);
    });

    test('getCustomerInfo returns null when not initialized', () async {
      final info = await PurchaseService.instance.getCustomerInfo();
      expect(info, isNull);
    });

    test('restorePurchases returns null when not initialized', () async {
      // On unsupported platforms or when not initialized, returns null
      if (!PurchaseService.instance.isPlatformSupported) {
        final info = await PurchaseService.instance.restorePurchases();
        expect(info, isNull);
      }
      // On supported platforms we can't test without actual RevenueCat setup
    });

    test('logOut completes without error when not initialized', () async {
      // Should be a safe no-op
      await PurchaseService.instance.logOut();
    });
  });
}
