import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/screens/player/player_keyboard_handler.dart';

void main() {
  group('handlePlayerKeyEvent', () {
    late bool playPauseCalled;
    late Duration? lastSeek;
    late double? lastVolumeDelta;
    late bool muteCalled;
    late bool fullscreenCalled;
    late bool escapeCalled;
    late int? lastZapDelta;
    late bool volumeOsdCalled;
    late bool channelListToggled;
    late int? lastDigitInput;
    late bool digitConfirmCalled;
    late PlayerKeyCallbacks callbacks;

    setUp(() {
      playPauseCalled = false;
      lastSeek = null;
      lastVolumeDelta = null;
      muteCalled = false;
      fullscreenCalled = false;
      escapeCalled = false;
      lastZapDelta = null;
      volumeOsdCalled = false;
      channelListToggled = false;
      lastDigitInput = null;
      digitConfirmCalled = false;
      callbacks = PlayerKeyCallbacks(
        playPause: () => playPauseCalled = true,
        seek: (d) => lastSeek = d,
        adjustVolume: (d) => lastVolumeDelta = d,
        toggleMute: () => muteCalled = true,
        enterFullscreen: () => fullscreenCalled = true,
        escape: () => escapeCalled = true,
        zapChannel: (d) => lastZapDelta = d,
        onVolumeOsd: () => volumeOsdCalled = true,
        toggleChannelList: () => channelListToggled = true,
        onDigitInput: (d) => lastDigitInput = d,
        onDigitConfirm: () => digitConfirmCalled = true,
      );
    });

    KeyDownEvent keyDown(LogicalKeyboardKey key) {
      return KeyDownEvent(
        logicalKey: key,
        physicalKey: PhysicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );
    }

    KeyRepeatEvent keyRepeat(LogicalKeyboardKey key) {
      return KeyRepeatEvent(
        logicalKey: key,
        physicalKey: PhysicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );
    }

    KeyUpEvent keyUp(LogicalKeyboardKey key) {
      return KeyUpEvent(
        logicalKey: key,
        physicalKey: PhysicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );
    }

    // ── Existing key mappings ──

    test('space triggers playPause', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.space),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(playPauseCalled, isTrue);
    });

    test('left arrow seeks backward in VOD mode', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastSeek, const Duration(seconds: -10));
    });

    test('right arrow seeks forward in VOD mode', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.arrowRight),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastSeek, const Duration(seconds: 10));
    });

    test('arrows do not seek in live mode', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: false,
        isRouteActive: true,
      );
      // In live mode without zapping, arrows adjust volume
      expect(handled, isFalse);
      expect(lastSeek, isNull);
    });

    test('F triggers fullscreen', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.keyF),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(fullscreenCalled, isTrue);
    });

    test('M triggers mute', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.keyM),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(muteCalled, isTrue);
    });

    test('Escape triggers escape callback', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.escape),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(escapeCalled, isTrue);
    });

    test('up arrow adjusts volume up when no zapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.arrowUp),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastVolumeDelta, 10);
    });

    test('down arrow adjusts volume down when no zapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.arrowDown),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastVolumeDelta, -10);
    });

    test('up arrow zaps channel when hasZapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.arrowUp),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastZapDelta, -1);
    });

    test('down arrow zaps channel when hasZapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.arrowDown),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastZapDelta, 1);
    });

    test('P zaps previous channel in live mode', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.keyP),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastZapDelta, -1);
    });

    test('N zaps next channel in live mode', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.keyN),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastZapDelta, 1);
    });

    test('P/N do nothing in VOD mode', () {
      final handledP = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.keyP),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handledP, isFalse);

      final handledN = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.keyN),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handledN, isFalse);
    });

    test('KeyUp events are ignored', () {
      final handled = handlePlayerKeyEvent(
        keyUp(LogicalKeyboardKey.space),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isFalse);
      expect(playPauseCalled, isFalse);
    });

    test('when route not active, only Escape passes through', () {
      final handledSpace = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.space),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: false,
      );
      expect(handledSpace, isFalse);
      expect(playPauseCalled, isFalse);

      final handledEsc = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.escape),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: false,
      );
      expect(handledEsc, isTrue);
      expect(escapeCalled, isTrue);
    });

    test('when route not active, F also passes through (calls escape)', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.keyF),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: false,
      );
      expect(handled, isTrue);
      expect(escapeCalled, isTrue);
    });

    test('key repeat on arrow left seeks repeatedly', () {
      final handled = handlePlayerKeyEvent(
        keyRepeat(LogicalKeyboardKey.arrowLeft),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastSeek, const Duration(seconds: -10));
    });

    test('key repeat on arrow up adjusts volume when no zapping', () {
      final handled = handlePlayerKeyEvent(
        keyRepeat(LogicalKeyboardKey.arrowUp),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastVolumeDelta, 5);
    });

    // ── Volume OSD trigger ──

    test('volume up triggers onVolumeOsd callback', () {
      handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.arrowUp),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(volumeOsdCalled, isTrue);
    });

    test('volume down triggers onVolumeOsd callback', () {
      handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.arrowDown),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(volumeOsdCalled, isTrue);
    });

    test('volume repeat triggers onVolumeOsd callback', () {
      handlePlayerKeyEvent(
        keyRepeat(LogicalKeyboardKey.arrowUp),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(volumeOsdCalled, isTrue);
    });

    test('volume OSD not triggered when zapping (arrows zap channels)', () {
      handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.arrowUp),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(volumeOsdCalled, isFalse);
      expect(lastZapDelta, -1);
    });

    // ── Channel list toggle ──

    test('L toggles channel list when hasZapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.keyL),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(channelListToggled, isTrue);
    });

    test('L does nothing when not in zapping mode', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.keyL),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isFalse);
      expect(channelListToggled, isFalse);
    });

    // ── Digit input ──

    test('digit 1 triggers onDigitInput when hasZapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.digit1),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastDigitInput, 1);
    });

    test('digit 0 triggers onDigitInput when hasZapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.digit0),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastDigitInput, 0);
    });

    test('numpad digit triggers onDigitInput when hasZapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.numpad5),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(lastDigitInput, 5);
    });

    test('digits do nothing when not hasZapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.digit3),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isFalse);
      expect(lastDigitInput, isNull);
    });

    test('Enter confirms digit input when hasZapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.enter),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(digitConfirmCalled, isTrue);
    });

    test('numpadEnter confirms digit input when hasZapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.numpadEnter),
        callbacks: callbacks,
        isLiveMode: true,
        hasZapping: true,
        isRouteActive: true,
      );
      expect(handled, isTrue);
      expect(digitConfirmCalled, isTrue);
    });

    test('Enter does nothing when not hasZapping', () {
      final handled = handlePlayerKeyEvent(
        keyDown(LogicalKeyboardKey.enter),
        callbacks: callbacks,
        isLiveMode: false,
        hasZapping: false,
        isRouteActive: true,
      );
      expect(handled, isFalse);
      expect(digitConfirmCalled, isFalse);
    });

    // ── All digits 0-9 produce correct values ──

    test('all digit keys 0-9 produce correct values', () {
      final digitKeys = [
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.digit8,
        LogicalKeyboardKey.digit9,
      ];
      for (var i = 0; i < digitKeys.length; i++) {
        lastDigitInput = null;
        handlePlayerKeyEvent(
          keyDown(digitKeys[i]),
          callbacks: callbacks,
          isLiveMode: true,
          hasZapping: true,
          isRouteActive: true,
        );
        expect(lastDigitInput, i, reason: 'digit$i should produce $i');
      }
    });
  });
}
