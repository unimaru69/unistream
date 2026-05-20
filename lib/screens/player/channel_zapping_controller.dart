import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../repositories/content_repository.dart';
import '../../utils/routes.dart';
import 'player_screen.dart';

/// Manages channel zapping state: channel +/-, direct numeric input,
/// and channel list visibility.
class ChannelZappingController {
  ChannelZappingController({
    required this.channelList,
    required this.channelIndex,
    required this.onStateChanged,
    required ContentRepository repo,
    this.getPlayer,
    this.getController,
    this.onHandoff,
  }) : _repo = repo;

  final ContentRepository _repo;

  final List<Channel>? channelList;
  final int? channelIndex;
  final VoidCallback onStateChanged;

  /// Hooks used to hand the live Player+VideoController from the
  /// CURRENT PlayerScreen over to the next one when zapping. Without
  /// the handoff, every channel switch recreates the whole pipeline:
  /// new Player → new VideoController → new EGL context → 1-2 seconds
  /// of "frozen last frame, then black" before the new stream takes
  /// over. Predidit's fork on Linux makes this especially visible
  /// because each VideoOutput init drags the swap-chain emulation
  /// + dedicated render thread along.
  ///
  /// Caller sets `onHandoff` to flag the outgoing PlayerScreen as
  /// "handed off" so its dispose() skips `_player.dispose()` (the new
  /// screen now owns the player).
  final Player? Function()? getPlayer;
  final VideoController? Function()? getController;
  final VoidCallback? onHandoff;

  bool showChannelList = false;
  String digitBuffer = '';
  Timer? _digitTimer;

  bool get hasZapping =>
      channelList != null && channelList!.length > 1 && channelIndex != null;

  void toggleChannelList() {
    showChannelList = !showChannelList;
    onStateChanged();
  }

  void closeChannelList() {
    showChannelList = false;
    onStateChanged();
  }

  void onDigitInput(int digit) {
    _digitTimer?.cancel();
    digitBuffer += digit.toString();
    onStateChanged();
    _digitTimer = Timer(const Duration(seconds: 2), () => tuneToBufferedChannel(null));
  }

  void tuneToBufferedChannel(BuildContext? context) {
    if (digitBuffer.isEmpty) return;
    final num = int.tryParse(digitBuffer);
    digitBuffer = '';
    _digitTimer?.cancel();
    onStateChanged();
    if (num == null || channelList == null || context == null) return;

    final list = channelList!;
    int targetIdx = -1;
    for (var i = 0; i < list.length; i++) {
      final chNum = int.tryParse(list[i].num?.toString() ?? '');
      if (chNum == num) {
        targetIdx = i;
        break;
      }
    }
    // Fallback: treat as 1-based index
    if (targetIdx < 0 && num >= 1 && num <= list.length) {
      targetIdx = num - 1;
    }
    if (targetIdx >= 0 && targetIdx != channelIndex) {
      zapToIndex(targetIdx, context);
    }
  }

  void zapChannel(int delta, BuildContext context) {
    final list = channelList;
    final idx = channelIndex;
    if (list == null || idx == null || list.isEmpty) return;
    final newIdx = (idx + delta) % list.length;
    zapToIndex(newIdx, context);
  }

  void zapToIndex(int idx, BuildContext context) {
    final list = channelList;
    if (list == null || idx < 0 || idx >= list.length) return;
    final ch = list[idx];
    final sid = ch.id;
    final url = _repo.getLiveStreamUrl(sid);
    final name = ch.name.isNotEmpty ? ch.name : AppLocalizations.of(context)!.sansTitre;
    // Grab the current screen's Player + VideoController BEFORE we push
    // the replacement, then flag the outgoing screen so its dispose
    // skips tearing them down. The new PlayerScreen reuses them, so
    // there's a single EGL context for the whole zapping session.
    //
    // We swap the URL HERE (not in the new screen's initState) because
    // PlayerScreen treats `existingPlayer != null` as a mini-player
    // handoff and deliberately skips `.open()` to preserve the current
    // playback position. For zap we want the opposite — load the new
    // channel right now, while the EGL pipeline stays untouched.
    final handoffPlayer = getPlayer?.call();
    final handoffController = getController?.call();
    if (handoffPlayer != null) {
      handoffPlayer.open(Media(url));
      onHandoff?.call();
    }
    Navigator.pushReplacement(context, slideRoute(PlayerScreen(
      url: url,
      title: name,
      streamId: sid,
      coverUrl: ch.displayIcon.isNotEmpty ? ch.displayIcon : null,
      channelList: list,
      channelIndex: idx,
      existingPlayer: handoffPlayer,
      existingController: handoffController,
    )));
  }

  void dispose() {
    _digitTimer?.cancel();
  }
}
