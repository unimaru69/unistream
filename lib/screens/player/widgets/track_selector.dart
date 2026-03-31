import 'package:flutter/material.dart';
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
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF12122A),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _TrackPickerSheet(
        player: player, audioTracks: audioTracks, subtitleTracks: subtitleTracks),
  );
}

class _TrackPickerSheet extends StatefulWidget {
  final Player player;
  final List<AudioTrack>    audioTracks;
  final List<SubtitleTrack> subtitleTracks;
  const _TrackPickerSheet({required this.player, required this.audioTracks, required this.subtitleTracks});
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const TabBar(
          tabs: [Tab(text: 'Audio'), Tab(text: 'Sous-titres')],
          indicatorColor: Color(0xFF4A90D9),
        ),
        SizedBox(height: 280, child: TabBarView(children: [
          // Audio
          ListView(children: widget.audioTracks.map((t) => RadioListTile<AudioTrack>(
            title: Text(resolveTrackLabel(t.title, t.language, t.id, 'Piste audio'),
                style: const TextStyle(fontSize: 13)),
            value: t, groupValue: _curAudio,
            activeColor: const Color(0xFF4A90D9),
            onChanged: (v) {
              if (v == null) return;
              widget.player.setAudioTrack(v);
              setState(() => _curAudio = v);
            },
          )).toList()),
          // Sous-titres
          ListView(children: [
            RadioListTile<SubtitleTrack>(
              title: const Text('D\u00e9sactiv\u00e9s', style: TextStyle(fontSize: 13)),
              value: SubtitleTrack.no(), groupValue: _curSub,
              activeColor: const Color(0xFF4A90D9),
              onChanged: (v) {
                if (v == null) return;
                widget.player.setSubtitleTrack(v);
                setState(() => _curSub = v);
              },
            ),
            ...widget.subtitleTracks.map((t) => RadioListTile<SubtitleTrack>(
              title: Text(resolveTrackLabel(t.title, t.language, t.id, 'Sous-titres'),
                  style: const TextStyle(fontSize: 13)),
              value: t, groupValue: _curSub,
              activeColor: const Color(0xFF4A90D9),
              onChanged: (v) {
                if (v == null) return;
                widget.player.setSubtitleTrack(v);
                setState(() => _curSub = v);
              },
            )),
          ]),
        ])),
      ]),
    );
  }
}
