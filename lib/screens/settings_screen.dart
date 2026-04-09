import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/app_config.dart';
import '../providers/config_provider.dart';
import '../repositories/content_repository.dart';
import '../services/import_export.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../utils/api_error_localizer.dart';
import '../utils/snackbar_helper.dart';

import 'settings/widgets/server_config_section.dart';
import 'settings/widgets/import_export_section.dart';
import 'settings/widgets/appearance_section.dart';
import 'settings/widgets/language_prefs_section.dart';
import 'settings/widgets/cache_section.dart';
import 'settings/widgets/advanced_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);
  final _serverCtrl = TextEditingController(text: AppConfig.serverUrl);
  final _userCtrl   = TextEditingController(text: AppConfig.username);
  final _passCtrl   = TextEditingController(text: AppConfig.password);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _serverCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final server = _serverCtrl.text.trim();
    final user   = _userCtrl.text.trim();
    final pass   = _passCtrl.text.trim();
    if (server.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.tousChampRequis);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(configProvider.notifier).save(server, user, pass);
      final auth = await _repo.authenticate();
      if (auth['user_info']?['auth'] != 1) {
        setState(() { _error = AppLocalizations.of(context)!.authEchouee; _saving = false; });
        return;
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = localizeApiError(_repo.errorKey(e), AppLocalizations.of(context)!); _saving = false; });
    }
  }

  Future<void> _importM3U() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final entries = ImportExport.parseM3U(content);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(context, l10n.entreesImporteesMu3(entries.length));
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context)!.erreurImport(e.toString()), isError: true);
      }
    }
  }

  Future<void> _exportFavorites() async {
    try {
      final m3u = await ImportExport.exportFavoritesM3U();
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null) return;
      final file = File('$dir/unistream_favoris.m3u');
      await file.writeAsString(m3u);
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context)!.favorisExportesVers(file.path));
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context)!.erreurExport(e.toString()), isError: true);
      }
    }
  }

  Future<void> _backupConfig() async {
    try {
      final json = await ImportExport.exportConfigJSON();
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null) return;
      final file = File('$dir/unistream_backup.json');
      await file.writeAsString(json);
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context)!.configSauvegardeeVers(file.path));
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context)!.erreurSauvegarde(e.toString()), isError: true);
      }
    }
  }

  Future<void> _restoreConfig() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      await ImportExport.importConfigJSON(content);
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context)!.configRestauree);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context)!.erreurRestauration(e.toString()), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.parametres),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ServerConfigSection(
                  serverCtrl: _serverCtrl,
                  userCtrl: _userCtrl,
                  passCtrl: _passCtrl,
                  saving: _saving,
                  error: _error,
                  onSave: _save,
                ),
                const SizedBox(height: 16),
                ImportExportSection(
                  onImportM3U: _importM3U,
                  onExportFavorites: _exportFavorites,
                  onBackupConfig: _backupConfig,
                  onRestoreConfig: _restoreConfig,
                ),
                const SizedBox(height: 16),
                const AppearanceSection(),
                const SizedBox(height: 16),
                const LanguagePrefsSection(),
                const SizedBox(height: 16),
                const CacheSection(),
                const SizedBox(height: 16),
                const AdvancedSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
