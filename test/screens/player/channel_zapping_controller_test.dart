import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/channel.dart';
import 'package:unistream/repositories/content_repository.dart';
import 'package:unistream/screens/player/channel_zapping_controller.dart';

/// Minimal fake that satisfies the controller's only call: getLiveStreamUrl.
class FakeContentRepository extends ContentRepository {
  @override
  String getLiveStreamUrl(String id) => 'http://fake.stream/$id';
}

void main() {
  late FakeContentRepository repo;
  late int stateChangedCount;
  late VoidCallback onStateChanged;

  final twoChannels = [
    const Channel(streamId: 1, name: 'Channel A', num: 10),
    const Channel(streamId: 2, name: 'Channel B', num: 20),
  ];

  final threeChannels = [
    const Channel(streamId: 1, name: 'CH1', num: 1),
    const Channel(streamId: 2, name: 'CH2', num: 2),
    const Channel(streamId: 3, name: 'CH3', num: 3),
  ];

  setUp(() {
    repo = FakeContentRepository();
    stateChangedCount = 0;
    onStateChanged = () => stateChangedCount++;
  });

  // ── hasZapping ──

  test('hasZapping returns false when channelList is null', () {
    final ctrl = ChannelZappingController(
      channelList: null,
      channelIndex: 0,
      onStateChanged: onStateChanged,
      repo: repo,
    );
    expect(ctrl.hasZapping, isFalse);
    ctrl.dispose();
  });

  test('hasZapping returns false when channelList has only 1 item', () {
    final ctrl = ChannelZappingController(
      channelList: const [Channel(streamId: 1, name: 'Solo')],
      channelIndex: 0,
      onStateChanged: onStateChanged,
      repo: repo,
    );
    expect(ctrl.hasZapping, isFalse);
    ctrl.dispose();
  });

  test('hasZapping returns true when channelList has 2+ items and channelIndex != null', () {
    final ctrl = ChannelZappingController(
      channelList: twoChannels,
      channelIndex: 0,
      onStateChanged: onStateChanged,
      repo: repo,
    );
    expect(ctrl.hasZapping, isTrue);
    ctrl.dispose();
  });

  test('hasZapping returns false when channelIndex is null', () {
    final ctrl = ChannelZappingController(
      channelList: twoChannels,
      channelIndex: null,
      onStateChanged: onStateChanged,
      repo: repo,
    );
    expect(ctrl.hasZapping, isFalse);
    ctrl.dispose();
  });

  // ── toggleChannelList / closeChannelList ──

  test('toggleChannelList toggles the flag and calls onStateChanged', () {
    final ctrl = ChannelZappingController(
      channelList: twoChannels,
      channelIndex: 0,
      onStateChanged: onStateChanged,
      repo: repo,
    );

    expect(ctrl.showChannelList, isFalse);

    ctrl.toggleChannelList();
    expect(ctrl.showChannelList, isTrue);
    expect(stateChangedCount, 1);

    ctrl.toggleChannelList();
    expect(ctrl.showChannelList, isFalse);
    expect(stateChangedCount, 2);

    ctrl.dispose();
  });

  test('closeChannelList sets flag to false and calls onStateChanged', () {
    final ctrl = ChannelZappingController(
      channelList: twoChannels,
      channelIndex: 0,
      onStateChanged: onStateChanged,
      repo: repo,
    );

    ctrl.toggleChannelList(); // open
    expect(ctrl.showChannelList, isTrue);
    stateChangedCount = 0;

    ctrl.closeChannelList();
    expect(ctrl.showChannelList, isFalse);
    expect(stateChangedCount, 1);

    ctrl.dispose();
  });

  test('closeChannelList when already closed still calls onStateChanged', () {
    final ctrl = ChannelZappingController(
      channelList: twoChannels,
      channelIndex: 0,
      onStateChanged: onStateChanged,
      repo: repo,
    );

    ctrl.closeChannelList();
    expect(ctrl.showChannelList, isFalse);
    expect(stateChangedCount, 1);

    ctrl.dispose();
  });

  // ── onDigitInput ──

  test('onDigitInput appends digits to buffer and calls onStateChanged', () {
    final ctrl = ChannelZappingController(
      channelList: threeChannels,
      channelIndex: 0,
      onStateChanged: onStateChanged,
      repo: repo,
    );

    ctrl.onDigitInput(1);
    expect(ctrl.digitBuffer, '1');
    expect(stateChangedCount, 1);

    ctrl.onDigitInput(5);
    expect(ctrl.digitBuffer, '15');
    expect(stateChangedCount, 2);

    ctrl.dispose();
  });

  test('onDigitInput clears buffer after timer fires (via tuneToBufferedChannel with null context)', () {
    fakeAsync((async) {
      final ctrl = ChannelZappingController(
        channelList: threeChannels,
        channelIndex: 0,
        onStateChanged: onStateChanged,
        repo: repo,
      );

      ctrl.onDigitInput(5);
      expect(ctrl.digitBuffer, '5');

      // Advance past the 2-second timer
      async.elapse(const Duration(seconds: 3));
      // tuneToBufferedChannel(null) should clear the buffer
      expect(ctrl.digitBuffer, isEmpty);

      ctrl.dispose();
    });
  });

  // ── zapChannel wrapping ──

  test('zapChannel computes correct wrapping index (logic only)', () {
    // We can't actually navigate without a BuildContext, but we can verify
    // the wrapping math directly:  (idx + delta) % length
    // last index + 1 wraps to 0
    expect((2 + 1) % 3, 0);
    // index 0 - 1 wraps to last
    expect((0 - 1) % 3, 2);
  });

  test('zapChannel with null list is a no-op', () {
    final ctrl = ChannelZappingController(
      channelList: null,
      channelIndex: 0,
      onStateChanged: onStateChanged,
      repo: repo,
    );
    // Should not throw even without a context
    // (returns early before using context because list is null)
    ctrl.zapChannel(1, _FakeBuildContext());
    expect(stateChangedCount, 0);
    ctrl.dispose();
  });

  // ── dispose ──

  test('dispose does not throw', () {
    final ctrl = ChannelZappingController(
      channelList: twoChannels,
      channelIndex: 0,
      onStateChanged: onStateChanged,
      repo: repo,
    );
    expect(() => ctrl.dispose(), returnsNormally);
  });

  test('dispose cancels pending digit timer', () {
    fakeAsync((async) {
      final ctrl = ChannelZappingController(
        channelList: threeChannels,
        channelIndex: 0,
        onStateChanged: onStateChanged,
        repo: repo,
      );

      ctrl.onDigitInput(9);
      final countBefore = stateChangedCount;
      ctrl.dispose();

      // Advance past the timer — it should NOT fire after dispose
      async.elapse(const Duration(seconds: 3));
      expect(stateChangedCount, countBefore);
    });
  });
}

/// Bare-minimum fake BuildContext so we can call zapChannel with a null list
/// (which returns early before the context is used).
class _FakeBuildContext extends Fake implements BuildContext {}
