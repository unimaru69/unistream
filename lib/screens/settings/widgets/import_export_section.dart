import 'package:flutter/material.dart';
import '../../../core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';

class ImportExportSection extends StatelessWidget {
  final VoidCallback onImportM3U;
  final VoidCallback onExportFavorites;
  final VoidCallback onBackupConfig;
  final VoidCallback onRestoreConfig;

  const ImportExportSection({
    super.key,
    required this.onImportM3U,
    required this.onExportFavorites,
    required this.onBackupConfig,
    required this.onRestoreConfig,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: tc.divider),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.importExport,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tc.textDisabled,
                  letterSpacing: 1)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
            onPressed: onImportM3U,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: Text(l10n.importM3U),
            style: OutlinedButton.styleFrom(
              foregroundColor: tc.textSecondary,
              side: BorderSide(color: tc.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton.icon(
            onPressed: onExportFavorites,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: Text(l10n.exportFavoris),
            style: OutlinedButton.styleFrom(
              foregroundColor: tc.textSecondary,
              side: BorderSide(color: tc.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
            onPressed: onBackupConfig,
            icon: const Icon(Icons.backup_outlined, size: 18),
            label: Text(l10n.sauvegarderConfigBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: tc.textSecondary,
              side: BorderSide(color: tc.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton.icon(
            onPressed: onRestoreConfig,
            icon: const Icon(Icons.restore, size: 18),
            label: Text(l10n.restaurerConfigBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: tc.textSecondary,
              side: BorderSide(color: tc.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          )),
        ]),
      ],
    );
  }
}
