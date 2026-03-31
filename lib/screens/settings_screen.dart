import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/cache_config.dart';
import '../models/app_config.dart';
import '../providers/config_provider.dart';
import '../services/xtream_api.dart';
import '../services/import_export.dart';
import '../core/colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../core/storage_keys.dart';
import '../utils/api_error_localizer.dart';
import '../utils/snackbar_helper.dart';
import 'profiles/profiles_screen.dart';

import '../utils/theme.dart';
import '../providers/locale_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _serverCtrl = TextEditingController(text: AppConfig.serverUrl);
  final _userCtrl   = TextEditingController(text: AppConfig.username);
  final _passCtrl   = TextEditingController(text: AppConfig.password);
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  // Language preferences
  String _prefAudioLang = 'original';
  String _prefSubLang = 'off';

  static const _langOptions = [
    ('original', 'Original'),
    ('fr', 'Français'),
    ('en', 'English'),
    ('de', 'Deutsch'),
    ('es', 'Español'),
    ('it', 'Italiano'),
  ];
  static const _subLangOptions = [
    ('off', 'Désactivés'),
    ('fr', 'Français'),
    ('en', 'English'),
    ('de', 'Deutsch'),
    ('es', 'Español'),
    ('it', 'Italiano'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLangPrefs();
  }

  Future<void> _loadLangPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _prefAudioLang = p.getString(StorageKeys.prefAudioLang) ?? 'original';
      _prefSubLang = p.getString(StorageKeys.prefSubLang) ?? 'off';
    });
  }

  Future<void> _saveLangPref(String key, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, value);
  }

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
      final auth = await XtreamApi.authenticate();
      if (auth['user_info']?['auth'] != 1) {
        setState(() { _error = AppLocalizations.of(context)!.authEchouee; _saving = false; });
        return;
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = localizeApiError(XtreamApi.errorKey(e), AppLocalizations.of(context)!); _saving = false; });
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.parametres), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Builder(builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _field(l10n.serverUrl, _serverCtrl, hint: 'http://monserveur.com:8080', icon: Icons.dns),
              const SizedBox(height: 16),
              _field(l10n.nomUtilisateur, _userCtrl, hint: 'username', icon: Icons.person),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: l10n.motDePasse,
                  prefixIcon: const Icon(Icons.lock, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true, fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppLocalizations.of(context)!.enregistrer,
                        style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 24),
              if (ref.watch(configProvider).profiles.length > 0)
                OutlinedButton.icon(
                  onPressed: () async {
                    final reload = await Navigator.push<bool>(context,
                        MaterialPageRoute(builder: (_) => ProfilesScreen(
                          onAdd: (pr) => ref.read(configProvider.notifier).addProfile(pr),
                          onUpdate: (pr) => ref.read(configProvider.notifier).updateProfile(pr),
                          onDelete: (id) => ref.read(configProvider.notifier).deleteProfile(id),
                          onSwitch: (id) => ref.read(configProvider.notifier).switchProfile(id),
                        )));
                    if (reload == true && mounted) Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: Text(l10n.gererProfilsBouton),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.importExport, style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: _importM3U,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: Text(l10n.importM3U),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  onPressed: _exportFavorites,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(l10n.exportFavoris),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: _backupConfig,
                  icon: const Icon(Icons.backup_outlined, size: 18),
                  label: Text(l10n.sauvegarderConfigBtn),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  onPressed: _restoreConfig,
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(l10n.restaurerConfigBtn),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.apparence, style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, _) => Row(children: [
                  const Icon(Icons.brightness_6, size: 20, color: Colors.white54),
                  const SizedBox(width: 12),
                  Text(l10n.themeMode, style: const TextStyle(fontSize: 14)),
                  const Spacer(),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(value: ThemeMode.system, label: Text(l10n.themeSysteme, style: const TextStyle(fontSize: 12))),
                      ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeSombre, style: const TextStyle(fontSize: 12))),
                      ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeClair, style: const TextStyle(fontSize: 12))),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) => saveThemeMode(v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final currentLocale = ref.watch(localeProvider);
                return Row(children: [
                  const Icon(Icons.language, size: 20, color: Colors.white54),
                  const SizedBox(width: 12),
                  Text(AppLocalizations.of(context)!.langueInterface, style: const TextStyle(fontSize: 14)),
                  const Spacer(),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'fr', label: Text('Français', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'en', label: Text('English', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {currentLocale.languageCode},
                    onSelectionChanged: (v) => ref.read(localeProvider.notifier).setLocale(Locale(v.first)),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ]);
              }),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.langues, style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.audiotrack, size: 20, color: Colors.white54),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.langueAudioPreferee, style: const TextStyle(fontSize: 14))),
                DropdownButton<String>(
                  value: _prefAudioLang,
                  dropdownColor: AppColors.darkSurface,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  underline: const SizedBox.shrink(),
                  items: _langOptions.map((opt) => DropdownMenuItem(
                    value: opt.$1, child: Text(opt.$2),
                  )).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _prefAudioLang = v);
                    _saveLangPref(StorageKeys.prefAudioLang, v);
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.subtitles, size: 20, color: Colors.white54),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.langueSousTitresPreferee, style: const TextStyle(fontSize: 14))),
                DropdownButton<String>(
                  value: _prefSubLang,
                  dropdownColor: AppColors.darkSurface,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  underline: const SizedBox.shrink(),
                  items: _subLangOptions.map((opt) => DropdownMenuItem(
                    value: opt.$1, child: Text(opt.$1 == 'off' ? l10n.desactive : opt.$2),
                  )).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _prefSubLang = v);
                    _saveLangPref(StorageKeys.prefSubLang, v);
                  },
                ),
              ]),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.cacheSection, style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.data_usage, size: 20, color: Colors.white54),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.cacheEpgEntrees(XtreamApi.epgCacheSize),
                    style: const TextStyle(fontSize: 14))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.darkSurface,
                        title: Text(l10n.confirmerViderCache,
                            style: const TextStyle(fontSize: 16)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n.annuler),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.supprimer,
                                style: const TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    XtreamApi.clearEpgCache();
                    setState(() {});
                    if (!mounted) return;
                    showAppSnackBar(context, l10n.cacheEpgVide);
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: Text(l10n.viderCacheEpg),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    await AppCacheManager.instance.emptyCache();
                    if (mounted) {
                      showAppSnackBar(context, l10n.cacheImagesVide);
                    }
                  },
                  icon: const Icon(Icons.image_not_supported_outlined, size: 18),
                  label: Text(l10n.viderCacheImages),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
              const SizedBox(height: 8),
              Text(l10n.descriptionCache,
                  style: const TextStyle(fontSize: 11, color: Colors.white38)),
            ]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, IconData? icon}) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          filled: true, fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      );
}
