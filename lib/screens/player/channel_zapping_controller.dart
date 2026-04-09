import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../services/xtream_api.dart';
import '../../utils/routes.dart';
import 'player_screen.dart';

/// Manages channel zapping state: channel +/-, direct numeric input,
/// and channel list visibility.
class ChannelZappingController {
  ChannelZappingController({
    required this.channelList,
    required this.channelIndex,
    required this.onStateChanged,
  });

  final List<Channel>? channelList;
  final int? channelIndex;
  final VoidCallback onStateChanged;

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
    final url = XtreamApi.getLiveStreamUrl(sid);
    final name = ch.name.isNotEmpty ? ch.name : AppLocalizations.of(context)!.sansTitre;
    Navigator.pushReplacement(context, slideRoute(PlayerScreen(
      url: url,
      title: name,
      streamId: sid,
      coverUrl: ch.displayIcon.isNotEmpty ? ch.displayIcon : null,
      channelList: list,
      channelIndex: idx,
    )));
  }

  void dispose() {
    _digitTimer?.cancel();
  }
}
