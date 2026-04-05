import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:unistream/l10n/app_localizations.dart';
import '../../core/colors.dart';
import '../../core/theme_colors.dart';
import '../../models/profile.dart';
import '../../services/xtream_api.dart';
import '../../utils/api_error_localizer.dart';

class ProfileDialog extends StatefulWidget {
  final Profile? profile;
  const ProfileDialog({super.key, this.profile});
  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
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
    final l10n = AppLocalizations.of(context)!;
    final name = _nameCtrl.text.trim();
    final server = _serverCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (!_formKey.currentState!.validate()) return;
    setState(() { _testing = true; _error = null; });
    try {
      final url = '$server/player_api.php?username=$user&password=$pass';
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final auth = jsonDecode(r.body);
      if (auth['user_info']?['auth'] != 1) {
        setState(() { _error = l10n.authEchouee; _testing = false; });
        return;
      }
      if (!mounted) return;
      final pr = Profile(
        id: widget.profile?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name, serverUrl: server, username: user, password: pass,
      );
      Navigator.pop(context, pr);
    } catch (e) {
      setState(() { _error = localizeApiError(XtreamApi.errorKey(e), AppLocalizations.of(context)!); _testing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: tc.surface,
      title: Text(widget.profile != null ? l10n.modifierProfil : l10n.nouveauProfil),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: l10n.nomProfil, hintText: 'Mon serveur',
                  prefixIcon: const Icon(Icons.label_outline, size: 20),
                  filled: true, fillColor: tc.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.tousChampRequis : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serverCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: l10n.serverUrl, hintText: 'http://monserveur.com:8080',
                  prefixIcon: const Icon(Icons.dns, size: 20),
                  filled: true, fillColor: tc.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l10n.tousChampRequis;
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme) return 'URL invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _userCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: l10n.nomUtilisateur,
                  prefixIcon: const Icon(Icons.person, size: 20),
                  filled: true, fillColor: tc.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.tousChampRequis : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
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
                  filled: true, fillColor: tc.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.tousChampRequis : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.annuler)),
        FilledButton(
          onPressed: _testing ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
          child: _testing
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.profile != null ? l10n.enregistrer : l10n.testerEtAjouter),
        ),
      ],
    );
  }
}
