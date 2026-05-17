import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:media_kit/media_kit.dart';

// ── Language name resolution (ISO 639) ──
const _langNames = {
  'und': 'Ind\u00e9fini',
  'fr': 'Fran\u00e7ais',  'fre': 'Fran\u00e7ais',  'fra': 'Fran\u00e7ais',
  'en': 'Anglais',   'eng': 'Anglais',
  'es': 'Espagnol',  'spa': 'Espagnol',
  'de': 'Allemand',  'ger': 'Allemand',  'deu': 'Allemand',
  'it': 'Italien',   'ita': 'Italien',
  'pt': 'Portugais', 'por': 'Portugais',
  'ar': 'Arabe',     'ara': 'Arabe',
  'ru': 'Russe',     'rus': 'Russe',
  'zh': 'Chinois',   'chi': 'Chinois',   'zho': 'Chinois',
  'ja': 'Japonais',  'jpn': 'Japonais',
  'nl': 'N\u00e9erlandais','dut': 'N\u00e9erlandais','nld': 'N\u00e9erlandais',
  'pl': 'Polonais',  'pol': 'Polonais',
  'tr': 'Turc',      'tur': 'Turc',
  'sv': 'Su\u00e9dois',   'swe': 'Su\u00e9dois',
  'no': 'Norv\u00e9gien', 'nor': 'Norv\u00e9gien',
  'da': 'Danois',    'dan': 'Danois',
  'fi': 'Finnois',   'fin': 'Finnois',
  'he': 'H\u00e9breu',    'heb': 'H\u00e9breu',
  'ko': 'Cor\u00e9en',    'kor': 'Cor\u00e9en',
};

String resolveTrackLabel(String? title, String? language, String? id, String fallback) {
  final langName    = language != null ? _langNames[language.toLowerCase()] : null;
  final langDisplay = langName ?? (language?.isNotEmpty == true ? language!.toUpperCase() : null);
  if (title != null && title.isNotEmpty) {
    return langDisplay != null ? '$title ($langDisplay)' : title;
  }
  return langDisplay ?? id ?? fallback;
}

void showTrackPicker(BuildContext context, {
  required Player player,
  required List<AudioTrack> audioTracks,
  required List<SubtitleTrack> subtitleTracks,
  int initialTab = 0,
}) {
  final tc = AppThemeColors.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: tc.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _TrackPickerSheet(
        player: player,
        audioTracks: audioTracks,
        subtitleTracks: subtitleTracks,
        initialTab: initialTab),
  );
}

class _TrackPickerSheet extends StatefulWidget {
  final Player player;
  final List<AudioTrack>    audioTracks;
  final List<SubtitleTrack> subtitleTracks;
  final int initialTab;
  const _TrackPickerSheet({
    required this.player,
    required this.audioTracks,
    required this.subtitleTracks,
    this.initialTab = 0,
  });
  @override
  State<_TrackPickerSheet> createState() => _TrackPickerSheetState();
}

class _TrackPickerSheetState extends State<_TrackPickerSheet> {
  late AudioTrack    _curAudio;
  late SubtitleTrack _curSub;

  @override
  void initState() {
    super.initState();
    _curAudio = widget.player.state.track.audio;
    _curSub   = widget.player.state.track.subtitle;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TabBar(
          tabs: [Tab(text: AppLocalizations.of(context)!.audioTab), Tab(text: AppLocalizations.of(context)!.sousTitresTab)],
          indicatorColor: AppColors.primaryBlue,
        ), // Tabs provide built-in Semantics
        SizedBox(height: 280, child: TabBarView(children: [
          // Audio
          RadioGroup<AudioTrack>(
            groupValue: _curAudio,
            onChanged: (v) {
              if (v == null) return;
              widget.player.setAudioTrack(v);
              setState(() => _curAudio = v);
            },
            child: ListView(children: widget.audioTracks.map((t) => ListTile(
              dense: true,
              leading: Radio<AudioTrack>(
                value: t,
                activeColor: AppColors.primaryBlue,
              ),
              title: Text(resolveTrackLabel(t.title, t.language, t.id, AppLocalizations.of(context)!.pisteAudio),
                  style: const TextStyle(fontSize: 13)),
              onTap: () {
                widget.player.setAudioTrack(t);
                setState(() => _curAudio = t);
              },
            )).toList()),
          ),
          // Sous-titres
          RadioGroup<SubtitleTrack>(
            groupValue: _curSub,
            onChanged: (v) {
              if (v == null) return;
              widget.player.setSubtitleTrack(v);
              setState(() => _curSub = v);
            },
            child: ListView(children: [
              ListTile(
                dense: true,
                leading: Radio<SubtitleTrack>(
                  value: SubtitleTrack.no(),
                  activeColor: AppColors.primaryBlue,
                ),
                title: Text(AppLocalizations.of(context)!.desactiverSousTitres, style: const TextStyle(fontSize: 13)),
                onTap: () {
                  final noSub = SubtitleTrack.no();
                  widget.player.setSubtitleTrack(noSub);
                  setState(() => _curSub = noSub);
                },
              ),
              ...widget.subtitleTracks.map((t) => ListTile(
                dense: true,
                leading: Radio<SubtitleTrack>(
                  value: t,
                  activeColor: AppColors.primaryBlue,
                ),
                title: Text(resolveTrackLabel(t.title, t.language, t.id, AppLocalizations.of(context)!.sousTitresTab),
                    style: const TextStyle(fontSize: 13)),
                onTap: () {
                  widget.player.setSubtitleTrack(t);
                  setState(() => _curSub = t);
                },
              )),
            ]),
          ),
        ])),
      ]),
    );
  }
}
