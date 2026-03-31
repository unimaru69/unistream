import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/profile.dart';
import '../models/app_config.dart';
import '../services/xtream_api.dart';
import '../services/import_export.dart';
import '../core/storage_keys.dart';
import 'home/home_screen.dart';

import '../utils/theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  const SettingsScreen({super.key, this.isOnboarding = false});
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
      setState(() => _error = 'Tous les champs sont requis');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await AppConfig.save(server, user, pass);
      final auth = await XtreamApi.authenticate();
      if (auth['user_info']?['auth'] != 1) {
        setState(() { _error = 'Authentification echouee'; _saving = false; });
        return;
      }
      if (!mounted) return;
      if (widget.isOnboarding) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() { _error = XtreamApi.friendlyError(e); _saving = false; });
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${entries.length} entrees importees depuis M3U'),
        backgroundColor: const Color(0xFF12122A),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur import: $e'),
          backgroundColor: Colors.redAccent,
        ));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Favoris exportes -> ${file.path}'),
          backgroundColor: const Color(0xFF12122A),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur export: $e'),
          backgroundColor: Colors.redAccent,
        ));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Configuration sauvegardee -> ${file.path}'),
          backgroundColor: const Color(0xFF12122A),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur sauvegarde: $e'),
          backgroundColor: Colors.redAccent,
        ));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Configuration restauree. Redemarrage...'),
          backgroundColor: Color(0xFF12122A),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur restauration: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isOnboarding
          ? null
          : AppBar(title: const Text('Parametres'), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (widget.isOnboarding) ...[
                const Icon(Icons.stream, size: 64, color: Color(0xFF4A90D9)),
                const SizedBox(height: 16),
                const Text('UniStream', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Configure ton serveur IPTV pour commencer',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 40),
              ],
              _field('URL du serveur', _serverCtrl, hint: 'http://monserveur.com:8080', icon: Icons.dns),
              const SizedBox(height: 16),
              _field('Nom d\'utilisateur', _userCtrl, hint: 'username', icon: Icons.person),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
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
                  backgroundColor: const Color(0xFF4A90D9),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isOnboarding ? 'Connexion' : 'Enregistrer',
                        style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 24),
              if (!widget.isOnboarding && AppConfig.profiles.length > 0)
                OutlinedButton.icon(
                  onPressed: () async {
                    final reload = await Navigator.push<bool>(context,
                        MaterialPageRoute(builder: (_) => const ProfilesScreen()));
                    if (reload == true && mounted) Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Gerer les profils'),
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
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('IMPORT / EXPORT', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: _importM3U,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Import M3U'),
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
                  label: const Text('Export favoris'),
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
                  label: const Text('Sauvegarder'),
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
                  label: const Text('Restaurer'),
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
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('APPARENCE', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, _) => Row(children: [
                  const Icon(Icons.brightness_6, size: 20, color: Colors.white54),
                  const SizedBox(width: 12),
                  const Text('Theme', style: TextStyle(fontSize: 14)),
                  const Spacer(),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Systeme', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Sombre', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: ThemeMode.light, label: Text('Clair', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) => saveThemeMode(v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('LANGUES', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.audiotrack, size: 20, color: Colors.white54),
                const SizedBox(width: 12),
                const Expanded(child: Text('Langue audio préférée', style: TextStyle(fontSize: 14))),
                DropdownButton<String>(
                  value: _prefAudioLang,
                  dropdownColor: const Color(0xFF12122A),
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
                const Expanded(child: Text('Langue sous-titres préférée', style: TextStyle(fontSize: 14))),
                DropdownButton<String>(
                  value: _prefSubLang,
                  dropdownColor: const Color(0xFF12122A),
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  underline: const SizedBox.shrink(),
                  items: _subLangOptions.map((opt) => DropdownMenuItem(
                    value: opt.$1, child: Text(opt.$2),
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
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('CACHE', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.data_usage, size: 20, color: Colors.white54),
                const SizedBox(width: 12),
                Expanded(child: Text('Cache EPG : ${XtreamApi.epgCacheSize} entrees',
                    style: const TextStyle(fontSize: 14))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    XtreamApi.clearEpgCache();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Cache EPG vide'),
                      backgroundColor: Color(0xFF12122A),
                    ));
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Vider le cache EPG'),
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
                    await DefaultCacheManager().emptyCache();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Cache images vide'),
                        backgroundColor: Color(0xFF12122A),
                      ));
                    }
                  },
                  icon: const Icon(Icons.image_not_supported_outlined, size: 18),
                  label: const Text('Vider le cache images'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
              const SizedBox(height: 8),
              const Text('Le cache EPG stocke les programmes TV pour un acces rapide. '
                  'Le cache images stocke les affiches et logos telecharges.',
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
            ]),
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

// ── Profiles Screen ──
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});
  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  bool _changed = false;

  Future<void> _addProfile() async {
    final result = await showDialog<Profile>(
      context: context,
      builder: (ctx) => const ProfileDialog(),
    );
    if (result != null) {
      await AppConfig.addProfile(result);
      setState(() => _changed = true);
    }
  }

  Future<void> _editProfile(Profile pr) async {
    final result = await showDialog<Profile>(
      context: context,
      builder: (ctx) => ProfileDialog(profile: pr),
    );
    if (result != null) {
      await AppConfig.updateProfile(result);
      setState(() => _changed = true);
    }
  }

  Future<void> _deleteProfile(Profile pr) async {
    if (AppConfig.profiles.length <= 1) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text('Supprimer ce profil ?'),
        content: Text('Le profil "${pr.name}" et ses donnees seront supprimes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      final wasActive = pr.id == AppConfig.activeProfileId;
      await AppConfig.deleteProfile(pr.id);
      if (wasActive && AppConfig.profiles.isNotEmpty) {
        await AppConfig.switchProfile(AppConfig.profiles.first.id);
      }
      setState(() => _changed = true);
    }
  }

  Future<void> _switchTo(Profile pr) async {
    await AppConfig.switchProfile(pr.id);
    setState(() => _changed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profils', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _changed),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Ajouter un profil', onPressed: _addProfile),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: AppConfig.profiles.length,
            itemBuilder: (_, i) {
              final pr = AppConfig.profiles[i];
              final isActive = pr.id == AppConfig.activeProfileId;
              return Card(
                color: isActive ? const Color(0xFF4A90D9).withValues(alpha: 0.15) : const Color(0xFF12122A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: isActive ? const BorderSide(color: Color(0xFF4A90D9), width: 1) : BorderSide.none,
                ),
                child: ListTile(
                  leading: Icon(isActive ? Icons.check_circle : Icons.account_circle_outlined,
                      color: isActive ? const Color(0xFF4A90D9) : Colors.white38),
                  title: Text(pr.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(pr.serverUrl, style: const TextStyle(fontSize: 11, color: Colors.white38),
                      overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!isActive)
                      TextButton(onPressed: () => _switchTo(pr),
                          child: const Text('Activer', style: TextStyle(fontSize: 12))),
                    IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editProfile(pr)),
                    if (AppConfig.profiles.length > 1)
                      IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () => _deleteProfile(pr)),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ProfileDialog extends StatefulWidget {
  final Profile? profile;
  const ProfileDialog({super.key, this.profile});
  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _serverCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  bool _testing = false;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl   = TextEditingController(text: widget.profile?.name ?? '');
    _serverCtrl = TextEditingController(text: widget.profile?.serverUrl ?? '');
    _userCtrl   = TextEditingController(text: widget.profile?.username ?? '');
    _passCtrl   = TextEditingController(text: widget.profile?.password ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _serverCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final server = _serverCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (name.isEmpty || server.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Tous les champs sont requis');
      return;
    }
    setState(() { _testing = true; _error = null; });
    try {
      // Test connection
      final url = '$server/player_api.php?username=$user&password=$pass';
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final auth = jsonDecode(r.body);
      if (auth['user_info']?['auth'] != 1) {
        setState(() { _error = 'Authentification echouee'; _testing = false; });
        return;
      }
      if (!mounted) return;
      final pr = Profile(
        id: widget.profile?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name, serverUrl: server, username: user, password: pass,
      );
      Navigator.pop(context, pr);
    } catch (e) {
      setState(() { _error = XtreamApi.friendlyError(e); _testing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF12122A),
      title: Text(widget.profile != null ? 'Modifier le profil' : 'Nouveau profil'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nom du profil', hintText: 'Mon serveur',
                prefixIcon: const Icon(Icons.label_outline, size: 20),
                filled: true, fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serverCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'URL du serveur', hintText: 'http://monserveur.com:8080',
                prefixIcon: const Icon(Icons.dns, size: 20),
                filled: true, fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nom d\'utilisateur',
                prefixIcon: const Icon(Icons.person, size: 20),
                filled: true, fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
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
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _testing ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A90D9)),
          child: _testing
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.profile != null ? 'Enregistrer' : 'Tester et ajouter'),
        ),
      ],
    );
  }
}
