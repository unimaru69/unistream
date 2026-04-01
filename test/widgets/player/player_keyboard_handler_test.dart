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
    late PlayerKeyCallbacks callbacks;

    setUp(() {
      playPauseCalled = false;
      lastSeek = null;
      lastVolumeDelta = null;
      muteCalled = false;
      fullscreenCalled = false;
      escapeCalled = false;
      lastZapDelta = null;
      callbacks = PlayerKeyCallbacks(
        playPause: () => playPauseCalled = true,
        seek: (d) => lastSeek = d,
        adjustVolume: (d) => lastVolumeDelta = d,
        toggleMute: () => muteCalled = true,
        enterFullscreen: () => fullscreenCalled = true,
        escape: () => escapeCalled = true,
        zapChannel: (d) => lastZapDelta = d,
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
  });
}
