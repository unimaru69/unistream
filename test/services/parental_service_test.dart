import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/services/parental_service.dart';
import 'package:unistream/core/storage_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Use mock secure storage
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('ParentalService PIN', () {
    test('hasPin returns false when no PIN is set', () async {
      expect(await ParentalService.hasPin(), isFalse);
    });

    test('setPin stores a hashed PIN and hasPin returns true', () async {
      await ParentalService.setPin('1234');
      expect(await ParentalService.hasPin(), isTrue);
    });

    test('verifyPin returns true for correct PIN', () async {
      await ParentalService.setPin('5678');
      expect(await ParentalService.verifyPin('5678'), isTrue);
    });

    test('verifyPin returns false for wrong PIN', () async {
      await ParentalService.setPin('1234');
      expect(await ParentalService.verifyPin('0000'), isFalse);
    });

    test('verifyPin returns false when no PIN is set', () async {
      expect(await ParentalService.verifyPin('1234'), isFalse);
    });

    test('clearPin removes the PIN', () async {
      await ParentalService.setPin('1234');
      expect(await ParentalService.hasPin(), isTrue);
      await ParentalService.clearPin();
      expect(await ParentalService.hasPin(), isFalse);
    });

    test('PIN is stored as SHA-256 hash', () async {
      await ParentalService.setPin('1234');
      final storage = const FlutterSecureStorage();
      final stored = await storage.read(key: StorageKeys.parentalPinHash);
      final expected = sha256.convert(utf8.encode('1234')).toString();
      expect(stored, equals(expected));
    });
  });

  group('ParentalService blocked categories', () {
    test('getBlockedCategories returns empty set initially', () async {
      final result = await ParentalService.getBlockedCategories('profile1');
      expect(result, isEmpty);
    });

    test('setBlockedCategories stores and retrieves IDs', () async {
      final ids = {'cat_1', 'cat_2', 'cat_3'};
      await ParentalService.setBlockedCategories('profile1', ids);
      final result = await ParentalService.getBlockedCategories('profile1');
      expect(result, equals(ids));
    });

    test('blocked categories are per-profile', () async {
      await ParentalService.setBlockedCategories('p1', {'cat_1'});
      await ParentalService.setBlockedCategories('p2', {'cat_2', 'cat_3'});

      expect(await ParentalService.getBlockedCategories('p1'), equals({'cat_1'}));
      expect(await ParentalService.getBlockedCategories('p2'), equals({'cat_2', 'cat_3'}));
    });

    test('setBlockedCategories overwrites previous values', () async {
      await ParentalService.setBlockedCategories('p1', {'cat_1', 'cat_2'});
      await ParentalService.setBlockedCategories('p1', {'cat_3'});
      final result = await ParentalService.getBlockedCategories('p1');
      expect(result, equals({'cat_3'}));
    });

    test('setBlockedCategories with empty set clears all', () async {
      await ParentalService.setBlockedCategories('p1', {'cat_1'});
      await ParentalService.setBlockedCategories('p1', {});
      final result = await ParentalService.getBlockedCategories('p1');
      expect(result, isEmpty);
    });
  });
}
