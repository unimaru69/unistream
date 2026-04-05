import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../../models/content_mode.dart';

/// Shows a dialog to create a new collection. Returns the collection name or null.
Future<String?> showCreateCollectionDialog(BuildContext context) async {
  final tc = AppThemeColors.of(context);
  final nameCtrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: tc.surface,
      title: Text(AppLocalizations.of(context)!.nouvelleCollection),
      content: TextField(
        controller: nameCtrl,
        autofocus: true,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.nomLabel,
          filled: true, fillColor: tc.inputFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.annuler)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
          child: Text(AppLocalizations.of(context)!.creer),
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
  final tc = AppThemeColors.of(context);
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: tc.surface,
      title: Text(AppLocalizations.of(context)!.ajouterCollection),
      children: [
        ...collections.map((col) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, col['id'] as String),
          child: Text(col['name'] as String, style: const TextStyle(fontSize: 14)),
        )),
        Divider(color: tc.divider),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            onCreateNew();
          },
          child: Row(children: [
            const Icon(Icons.add, size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.nouvelleCollection, style: const TextStyle(fontSize: 14, color: AppColors.primaryBlue)),
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
  final tc = AppThemeColors.of(context);
  final nameCtrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: tc.surface,
      title: Text(AppLocalizations.of(context)!.nouvelleCollectionAvec(itemCount)),
      content: TextField(
        controller: nameCtrl,
        autofocus: true,
        decoration: InputDecoration(hintText: AppLocalizations.of(context)!.nomCollection),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.annuler)),
        TextButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: Text(AppLocalizations.of(context)!.creer)),
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
  final tc = AppThemeColors.of(context);
  final l10n = AppLocalizations.of(context)!;
  final name = stream['name'] ?? l10n.sansTitre;
  final modeLabels = {ContentMode.live: l10n.live, ContentMode.vod: l10n.vod, ContentMode.series: l10n.serie};
  final modeColors = {ContentMode.live: Colors.redAccent, ContentMode.vod: Colors.amber, ContentMode.series: Colors.tealAccent};

  final infoParts = <String>[];
  if (stream['category_name'] != null) infoParts.add(l10n.categorie(stream['category_name'].toString()));
  if (stream['rating'] != null && stream['rating'].toString().isNotEmpty && stream['rating'].toString() != '0') {
    infoParts.add(l10n.note(stream['rating'].toString()));
  }
  if (mode == ContentMode.series && stream['num_seasons'] != null) {
    infoParts.add(l10n.nbSaisons(stream['num_seasons'].toString()));
  }
  if (mode == ContentMode.vod && stream['stream_type'] != null) {
    infoParts.add(l10n.typeStream(stream['stream_type'].toString()));
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
      label: Text(l10n.collectionLabel),
    ),
    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.fermer)),
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
        epgNotifier.value = prog ?? l10n.aucunProgramme;
      }).catchError((_) {
        epgNotifier.value = 'EPG indisponible';
      });
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: tc.surface,
      title: Text(name, style: const TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        modeTag(),
        if (infoParts.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...infoParts.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(p, style: TextStyle(fontSize: 13, color: tc.textSecondary)),
          )),
        ],
        const SizedBox(height: 8),
        Text('Programme en cours :', style: TextStyle(fontSize: 12, color: tc.textDisabled)),
        const SizedBox(height: 4),
        ValueListenableBuilder<String?>(
          valueListenable: epgNotifier,
          builder: (_, val, __) => Text(val ?? l10n.aucunProgramme,
              style: const TextStyle(fontSize: 13, color: Colors.tealAccent)),
        ),
      ]),
      actions: dialogActions(ctx),
    ));
  } else {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: tc.surface,
      title: Text(name, style: const TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        modeTag(),
        if (infoParts.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...infoParts.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(p, style: TextStyle(fontSize: 13, color: tc.textSecondary)),
          )),
        ],
      ]),
      actions: dialogActions(ctx),
    ));
  }
}
