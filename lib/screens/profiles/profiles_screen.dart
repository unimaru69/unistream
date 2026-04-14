import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../core/colors.dart';
import '../../core/theme_colors.dart';
import '../../models/profile.dart';
import '../../models/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../utils/feature_access.dart';
import '../../widgets/pin_dialog.dart';
import '../../widgets/premium_gate.dart';
import 'profile_dialog.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  final Future<void> Function(Profile) onAdd;
  final Future<void> Function(Profile) onUpdate;
  final Future<void> Function(String) onDelete;
  final Future<void> Function(String) onSwitch;
  const ProfilesScreen({
    super.key,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.onSwitch,
  });
  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  bool _changed = false;

  Future<void> _addProfile() async {
    final account = ref.read(authProvider).accountInfo;
    final maxAllowed = FeatureAccess.maxProfiles(account);
    if (AppConfig.profiles.length >= maxAllowed) {
      if (!checkPremiumAccess(context, ref, Feature.multipleProfiles)) return;
    }
    final result = await showDialog<Profile>(
      context: context,
      builder: (ctx) => const ProfileDialog(),
    );
    if (result != null) {
      await widget.onAdd(result);
      setState(() => _changed = true);
    }
  }

  /// Verify profile PIN before a sensitive action. Returns true if no PIN
  /// is set or if the user enters it correctly.
  Future<bool> _checkPin(Profile pr) async {
    if (!pr.hasPin) return true;
    final l10n = AppLocalizations.of(context)!;
    bool verified = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinDialog(
        title: l10n.entrerPinProfil,
        onPinEntered: (pin) {
          final hash = sha256.convert(utf8.encode(pin)).toString();
          if (hash == pr.pinHash) {
            verified = true;
            Navigator.pop(ctx);
          }
          // Wrong PIN — dialog stays open for retry
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
    return verified;
  }

  Future<void> _editProfile(Profile pr) async {
    if (!await _checkPin(pr)) return;
    final result = await showDialog<Profile>(
      context: context,
      builder: (ctx) => ProfileDialog(profile: pr),
    );
    if (result != null) {
      await widget.onUpdate(result);
      setState(() => _changed = true);
    }
  }

  Future<void> _deleteProfile(Profile pr) async {
    if (!await _checkPin(pr)) return;
    final config = ref.read(configProvider);
    if (config.profiles.length <= 1) return;
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surface,
        title: Text(l10n.supprimerProfil),
        content: Text(l10n.profilDonneesSupprimees(pr.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.annuler)),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.supprimer, style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      final wasActive = pr.id == config.activeProfileId;
      await widget.onDelete(pr.id);
      if (wasActive) {
        final updatedConfig = ref.read(configProvider);
        if (updatedConfig.profiles.isNotEmpty) {
          await widget.onSwitch(updatedConfig.profiles.first.id);
        }
      }
      setState(() => _changed = true);
    }
  }

  Future<void> _switchTo(Profile pr) async {
    await widget.onSwitch(pr.id);
    setState(() => _changed = true);
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final config = ref.watch(configProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profils, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _changed),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: l10n.ajouterProfil, onPressed: _addProfile),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: config.profiles.length,
            itemBuilder: (_, i) {
              final pr = config.profiles[i];
              final isActive = pr.id == config.activeProfileId;
              return Card(
                color: isActive ? AppColors.primaryBlue.withValues(alpha: 0.15) : tc.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: isActive ? const BorderSide(color: AppColors.primaryBlue, width: 1) : BorderSide.none,
                ),
                child: ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primaryBlue.withValues(alpha: 0.2)
                          : tc.inputFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(pr.avatar, style: const TextStyle(fontSize: 22))),
                  ),
                  title: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(pr.name, style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis)),
                    if (pr.hasPin)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.lock_outline, size: 14, color: tc.textDisabled),
                      ),
                  ]),
                  subtitle: Text(pr.serverUrl, style: TextStyle(fontSize: 11, color: tc.textDisabled),
                      overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!isActive)
                      TextButton(onPressed: () => _switchTo(pr),
                          child: Text(l10n.activer, style: const TextStyle(fontSize: 12))),
                    IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editProfile(pr)),
                    if (config.profiles.length > 1)
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
