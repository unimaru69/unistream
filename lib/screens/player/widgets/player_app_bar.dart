import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../../core/colors.dart';
import 'quality_badge.dart';
import 'sleep_timer_dialog.dart';
import 'track_selector.dart';
import 'epg_overlay.dart';
import 'player_controls.dart';
import 'quality_selector.dart';

/// Extracted AppBar for PlayerScreen — replay/live badges, channel zapping,
/// quality, EPG, tracks, subtitles, aspect ratio, speed, sleep, mini-player.
class PlayerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PlayerAppBar({
    super.key,
    required this.title,
    required this.epgNow,
    required this.epgNext,
    required this.epgProgress,
    required this.isCatchupMode,
    required this.isLiveMode,
    required this.streamId,
    required this.channelList,
    required this.qualityBadge,
    required this.bitrate,
    required this.epgListings,
    required this.catchupSupported,
    required this.audioTracks,
    required this.subtitleTracks,
    required this.player,
    required this.aspectRatio,
    required this.deinterlace,
    required this.speed,
    required this.sleepRemaining,
    required this.onReturnToLive,
    required this.onZapChannel,
    required this.onSubtitleStylePicker,
    required this.onSetAspectRatio,
    required this.onToggleDeinterlace,
    required this.onSpeedChanged,
    required this.onStartSleepTimer,
    required this.onCancelSleepTimer,
    required this.onMinimize,
    required this.hlsVariants,
    required this.activeVariantUrl,
    required this.onVariantSelected,
  });

  final String title;
  final String? epgNow;
  final String? epgNext;
  final double? epgProgress;
  final bool isCatchupMode;
  final bool isLiveMode;
  final String? streamId;
  final bool channelList; // whether channel zapping is available
  final String qualityBadge;
  final String bitrate;
  final List<Map<String, String>> epgListings;
  final bool catchupSupported;
  final List<AudioTrack> audioTracks;
  final List<SubtitleTrack> subtitleTracks;
  final Player player;
  final String aspectRatio;
  final bool deinterlace;
  final double speed;
  final Duration? sleepRemaining;
  final VoidCallback onReturnToLive;
  final void Function(int delta) onZapChannel;
  final VoidCallback onSubtitleStylePicker;
  final void Function(String ratio) onSetAspectRatio;
  final VoidCallback onToggleDeinterlace;
  final void Function(double speed) onSpeedChanged;
  final void Function(Duration duration) onStartSleepTimer;
  final VoidCallback onCancelSleepTimer;
  final VoidCallback onMinimize;
  final List<HlsVariant> hlsVariants;
  final String? activeVariantUrl;
  final void Function(HlsVariant? variant) onVariantSelected;

  @override
  Size get preferredSize {
    // Account for optional EPG progress bar
    final h = kToolbarHeight + (epgProgress != null ? 4.0 : 0.0);
    return Size.fromHeight(h);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasTracks = audioTracks.length > 1 || subtitleTracks.length > 1;

    final titleWidget = epgNow != null
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis),
            Text(epgNow!, style: const TextStyle(fontSize: 11, color: Colors.white54),
                overflow: TextOverflow.ellipsis),
          ])
        : Text(title, style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis);

    return AppBar(
      backgroundColor: Colors.black87,
      elevation: 0,
      title: titleWidget,
      bottom: epgProgress != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: epgProgress!,
                  backgroundColor: Colors.white12,
                  color: AppColors.primaryBlue,
                  minHeight: 4,
                ),
              ),
            )
          : null,
      actions: [
        if (isCatchupMode)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(l10n.replay,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
        if (isCatchupMode && streamId != null)
          TextButton.icon(
            icon: const Icon(Icons.circle, size: 10, color: Colors.redAccent),
            label: Text(l10n.live,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: onReturnToLive,
          ),
        if (isLiveMode && channelList) ...[
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 22),
            tooltip: '${l10n.chainePrecSuiv} (P)',
            onPressed: () => onZapChannel(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 22),
            tooltip: '${l10n.chainePrecSuiv} (N)',
            onPressed: () => onZapChannel(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
        QualityBadge(qualityBadge: qualityBadge, bitrate: bitrate),
        if (hlsVariants.isNotEmpty)
          IconButton(
            icon: Icon(Icons.hd, size: 22,
                color: activeVariantUrl != null ? AppColors.primaryBlue : Colors.white),
            tooltip: l10n.qualiteStream,
            onPressed: () => showQualityPicker(context,
              qualityBadge: qualityBadge,
              bitrate: bitrate,
              variants: hlsVariants,
              activeVariantUrl: activeVariantUrl,
              onVariantSelected: onVariantSelected,
            ),
          ),
        if (epgListings.length > 1)
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            tooltip: l10n.guideTV,
            onPressed: () => showEpgGuide(context,
              epgListings: epgListings,
              catchupSupported: catchupSupported,
              streamId: streamId,
            ),
          ),
        if (epgNext != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text(l10n.suivantEpg(epgNext!),
                style: const TextStyle(fontSize: 11, color: Colors.white38),
                overflow: TextOverflow.ellipsis)),
          ),
        if (hasTracks)
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '${l10n.langueAudio} / ${l10n.langueSousTitres}',
            onPressed: () => showTrackPicker(context,
              player: player,
              audioTracks: audioTracks,
              subtitleTracks: subtitleTracks,
            ),
          ),
        IconButton(
          icon: const Icon(Icons.subtitles, size: 20),
          tooltip: l10n.styleSousTitres,
          onPressed: onSubtitleStylePicker,
        ),
        IconButton(
          icon: const Icon(Icons.aspect_ratio, size: 20),
          tooltip: l10n.ratioAspect,
          onPressed: () => showAspectRatioPicker(context,
            currentRatio: aspectRatio,
            onRatioSelected: onSetAspectRatio,
          ),
        ),
        IconButton(
          icon: Icon(Icons.deblur, size: 20,
              color: deinterlace ? AppColors.primaryBlue : Colors.white),
          tooltip: l10n.desentrelacement,
          onPressed: onToggleDeinterlace,
        ),
        IconButton(
          icon: const Icon(Icons.speed),
          tooltip: l10n.vitesseLecture,
          onPressed: () => showSpeedPicker(context,
            currentSpeed: speed,
            onSpeedChanged: onSpeedChanged,
          ),
        ),
        IconButton(
          icon: Icon(Icons.timer, size: 20,
              color: sleepRemaining != null ? Colors.amber : Colors.white),
          tooltip: sleepRemaining != null
              ? l10n.veilleActive(sleepRemaining!.inMinutes)
              : l10n.minuterieVeille,
          onPressed: () => showSleepTimerPicker(context,
            sleepRemaining: sleepRemaining,
            onCancel: onCancelSleepTimer,
            onStart: onStartSleepTimer,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.picture_in_picture_alt, size: 20),
          tooltip: l10n.miniPlayer,
          onPressed: onMinimize,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
