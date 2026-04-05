import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/providers/parental_provider.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/models/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    // Set up a default profile so AppConfig.activeProfileId works
    AppConfig.profiles = [
      Profile(id: 'test', name: 'Test', serverUrl: '', username: '', password: ''),
    ];
    AppConfig.activeProfileId = 'test';
  });

  group('ParentalNotifier', () {
    test('initial state is disabled, locked, no blocked categories', () async {
      final notifier = ParentalNotifier();
      // Allow async _load to complete
      await Future.delayed(const Duration(milliseconds: 100));
      expect(notifier.state.isEnabled, isFalse);
      expect(notifier.state.isUnlocked, isFalse);
      expect(notifier.state.blockedCategoryIds, isEmpty);
    });

    test('setPin enables parental controls', () async {
      final notifier = ParentalNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      await notifier.setPin('1234');
      expect(notifier.state.isEnabled, isTrue);
    });

    test('verifyAndUnlock unlocks on correct PIN', () async {
      final notifier = ParentalNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      await notifier.setPin('4321');
      final ok = await notifier.verifyAndUnlock('4321');
      expect(ok, isTrue);
      expect(notifier.state.isUnlocked, isTrue);
    });

    test('verifyAndUnlock stays locked on wrong PIN', () async {
      final notifier = ParentalNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      await notifier.setPin('1234');
      final ok = await notifier.verifyAndUnlock('0000');
      expect(ok, isFalse);
      expect(notifier.state.isUnlocked, isFalse);
    });

    test('lock re-engages parental controls', () async {
      final notifier = ParentalNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      await notifier.setPin('1234');
      await notifier.verifyAndUnlock('1234');
      expect(notifier.state.isUnlocked, isTrue);

      notifier.lock();
      expect(notifier.state.isUnlocked, isFalse);
      expect(notifier.state.isEnabled, isTrue);
    });

    test('toggleCategory adds and removes categories', () async {
      final notifier = ParentalNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      await notifier.toggleCategory('cat_1');
      expect(notifier.state.blockedCategoryIds, contains('cat_1'));

      await notifier.toggleCategory('cat_2');
      expect(notifier.state.blockedCategoryIds, containsAll(['cat_1', 'cat_2']));

      await notifier.toggleCategory('cat_1');
      expect(notifier.state.blockedCategoryIds, isNot(contains('cat_1')));
      expect(notifier.state.blockedCategoryIds, contains('cat_2'));
    });

    test('clearPin disables everything', () async {
      final notifier = ParentalNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      await notifier.setPin('1234');
      await notifier.toggleCategory('cat_1');
      expect(notifier.state.isEnabled, isTrue);
      expect(notifier.state.blockedCategoryIds, isNotEmpty);

      await notifier.clearPin();
      expect(notifier.state.isEnabled, isFalse);
      expect(notifier.state.isUnlocked, isFalse);
      expect(notifier.state.blockedCategoryIds, isEmpty);
    });
  });
}
