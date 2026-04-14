import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/colors.dart';
import '../../../core/theme_colors.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/parental_provider.dart';
import '../../../utils/feature_access.dart';
import '../../../widgets/premium_gate.dart';
import '../../profiles/profiles_screen.dart';
import '../parental_settings_screen.dart';
import 'package:unistream/l10n/app_localizations.dart';

class ServerConfigSection extends ConsumerStatefulWidget {
  final TextEditingController serverCtrl;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final bool saving;
  final String? error;
  final VoidCallback onSave;

  const ServerConfigSection({
    super.key,
    required this.serverCtrl,
    required this.userCtrl,
    required this.passCtrl,
    required this.saving,
    required this.error,
    required this.onSave,
  });

  @override
  ConsumerState<ServerConfigSection> createState() =>
      _ServerConfigSectionState();
}

class _ServerConfigSectionState extends ConsumerState<ServerConfigSection> {
  bool _obscure = true;
  final _formKey = GlobalKey<FormState>();

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, IconData? icon, String? Function(String?)? validator}) {
    final tc = AppThemeColors.of(context);
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(fontSize: 14),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: tc.inputFill,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(l10n.serverUrl, widget.serverCtrl,
            hint: 'http://monserveur.com:8080', icon: Icons.dns,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.champObligatoire;
              final uri = Uri.tryParse(v.trim());
              if (uri == null || !uri.hasScheme) return l10n.urlInvalide;
              return null;
            }),
        const SizedBox(height: 16),
        _field(l10n.nomUtilisateur, widget.userCtrl,
            hint: 'username', icon: Icons.person,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.champObligatoire;
              return null;
            }),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.passCtrl,
          obscureText: _obscure,
          style: const TextStyle(fontSize: 14),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return l10n.champObligatoire;
            return null;
          },
          decoration: InputDecoration(
            labelText: l10n.motDePasse,
            prefixIcon: const Icon(Icons.lock, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscure ? Icons.visibility : Icons.visibility_off,
                  size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            filled: true,
            fillColor: tc.inputFill,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(widget.error!,
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: widget.saving ? null : () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onSave();
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: widget.saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(l10n.enregistrer,
                  style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 24),
        if (ref.watch(configProvider).profiles.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () async {
              final reload = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProfilesScreen(
                            onAdd: (pr) => ref
                                .read(configProvider.notifier)
                                .addProfile(pr),
                            onUpdate: (pr) => ref
                                .read(configProvider.notifier)
                                .updateProfile(pr),
                            onDelete: (id) => ref
                                .read(configProvider.notifier)
                                .deleteProfile(id),
                            onSwitch: (id) => ref
                                .read(configProvider.notifier)
                                .switchProfile(id),
                          )));
              if (reload == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
            icon: const Icon(Icons.people_outline, size: 18),
            label: Text(l10n.gererProfilsBouton),
            style: OutlinedButton.styleFrom(
              foregroundColor: tc.textSecondary,
              side: BorderSide(color: tc.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        const SizedBox(height: 16),
        Builder(builder: (context) {
          final parental = ref.watch(parentalProvider);
          return OutlinedButton.icon(
            onPressed: () {
              if (!checkPremiumAccess(context, ref, Feature.parentalControls)) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ParentalSettingsScreen()));
            },
            icon: Icon(
              parental.isEnabled ? Icons.lock : Icons.lock_open,
              size: 18,
            ),
            label: const Text('Contr\u00f4le parental'),
            style: OutlinedButton.styleFrom(
              foregroundColor: tc.textSecondary,
              side: BorderSide(color: tc.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }),
      ],
    ),
    );
  }
}
