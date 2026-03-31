import 'package:flutter/material.dart';
import '../../../models/content_mode.dart';

/// Shows a dialog to create a new collection. Returns the collection name or null.
Future<String?> showCreateCollectionDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF12122A),
      title: const Text('Nouvelle collection'),
      content: TextField(
        controller: nameCtrl,
        autofocus: true,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: 'Nom',
          filled: true, fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A90D9)),
          child: const Text('Creer'),
        ),
      ],
    ),
  );
  nameCtrl.dispose();
  return name;
}

/// Shows a picker dialog to choose a collection to add an item to.
/// [collections] should be pre-filtered by mode.
/// Returns the selected collection ID or null.
Future<String?> showCollectionPickerDialog(
  BuildContext context, {
  required List<Map<String, dynamic>> collections,
  required VoidCallback onCreateNew,
}) async {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: const Color(0xFF12122A),
      title: const Text('Ajouter a une collection'),
      children: [
        ...collections.map((col) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, col['id'] as String),
          child: Text(col['name'] as String, style: const TextStyle(fontSize: 14)),
        )),
        const Divider(color: Colors.white12),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            onCreateNew();
          },
          child: const Row(children: [
            Icon(Icons.add, size: 18, color: Color(0xFF4A90D9)),
            SizedBox(width: 8),
            Text('Nouvelle collection', style: TextStyle(fontSize: 14, color: Color(0xFF4A90D9))),
          ]),
        ),
      ],
    ),
  );
}

/// Shows a dialog to create a collection from selected items.
/// Returns the name or null.
Future<String?> showCreateCollectionFromSelectedDialog(
  BuildContext context, {
  required int itemCount,
}) async {
  final nameCtrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF12122A),
      title: Text('Nouvelle collection ($itemCount éléments)'),
      content: TextField(
        controller: nameCtrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nom de la collection'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('Créer')),
      ],
    ),
  );
  nameCtrl.dispose();
  return name;
}

/// Shows the stream info dialog with EPG support for live channels.
/// EPG data is provided via callbacks to avoid tight coupling with XtreamApi.
void showStreamInfoDialogWithEpg(
  BuildContext context, {
  required Map<String, dynamic> stream,
  required ContentMode mode,
  required VoidCallback onAddToCollection,
  required String? Function(String streamId) getCachedEpgNow,
  required Future<dynamic> Function(String streamId, {int limit}) getShortEpg,
}) {
  final name = stream['name'] ?? 'Sans titre';
  final modeLabels = {ContentMode.live: 'Live', ContentMode.vod: 'VOD', ContentMode.series: 'Série'};
  final modeColors = {ContentMode.live: Colors.redAccent, ContentMode.vod: Colors.amber, ContentMode.series: Colors.tealAccent};

  final infoParts = <String>[];
  if (stream['category_name'] != null) infoParts.add('Catégorie : ${stream['category_name']}');
  if (stream['rating'] != null && stream['rating'].toString().isNotEmpty && stream['rating'].toString() != '0') {
    infoParts.add('Note : ${stream['rating']}');
  }
  if (mode == ContentMode.series && stream['num_seasons'] != null) {
    infoParts.add('Saisons : ${stream['num_seasons']}');
  }
  if (mode == ContentMode.vod && stream['stream_type'] != null) {
    infoParts.add('Type : ${stream['stream_type']}');
  }
  final plot = stream['plot'] ?? stream['description'];
  if (plot != null && plot.toString().isNotEmpty) {
    infoParts.add(plot.toString());
  }

  List<Widget> dialogActions(BuildContext ctx) => [
    TextButton.icon(
      onPressed: () {
        Navigator.pop(ctx);
        onAddToCollection();
      },
      icon: const Icon(Icons.folder_outlined, size: 16),
      label: const Text('Collection'),
    ),
    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
  ];

  Widget modeTag() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: (modeColors[mode] ?? Colors.grey).withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(4)),
    child: Text(modeLabels[mode] ?? mode.label,
        style: TextStyle(fontSize: 11, color: modeColors[mode] ?? Colors.grey)),
  );

  if (mode == ContentMode.live) {
    final streamId = stream['stream_id']?.toString() ?? '';
    final epgNotifier = ValueNotifier<String?>(
      getCachedEpgNow(streamId) ?? '...',
    );
    if (streamId.isNotEmpty && getCachedEpgNow(streamId) == null) {
      getShortEpg(streamId, limit: 2).then((data) {
        final prog = getCachedEpgNow(streamId);
        epgNotifier.value = prog ?? 'Aucun programme';
      }).catchError((_) {
        epgNotifier.value = 'EPG indisponible';
      });
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF12122A),
      title: Text(name, style: const TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        modeTag(),
        if (infoParts.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...infoParts.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(p, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          )),
        ],
        const SizedBox(height: 8),
        const Text('Programme en cours :', style: TextStyle(fontSize: 12, color: Colors.white38)),
        const SizedBox(height: 4),
        ValueListenableBuilder<String?>(
          valueListenable: epgNotifier,
          builder: (_, val, __) => Text(val ?? 'Aucun programme',
              style: const TextStyle(fontSize: 13, color: Colors.tealAccent)),
        ),
      ]),
      actions: dialogActions(ctx),
    ));
  } else {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF12122A),
      title: Text(name, style: const TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        modeTag(),
        if (infoParts.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...infoParts.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(p, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          )),
        ],
      ]),
      actions: dialogActions(ctx),
    ));
  }
}
