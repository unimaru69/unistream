import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../core/colors.dart';
import '../../models/profile.dart';
import '../../widgets/pin_dialog.dart';

/// Full-screen profile selector shown at app startup when multiple profiles exist.
///
/// Returns the selected [Profile] via Navigator.pop.
class ProfileSelectorScreen extends StatelessWidget {
  final List<Profile> profiles;
  final String? activeProfileId;

  const ProfileSelectorScreen({
    super.key,
    required this.profiles,
    this.activeProfileId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.quiRegarde,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: profiles.map((pr) => _ProfileCard(
                      profile: pr,
                      isActive: pr.id == activeProfileId,
                      onTap: () => _selectProfile(context, pr),
                    )).toList(),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectProfile(BuildContext context, Profile profile) async {
    if (profile.hasPin) {
      // Show PIN dialog
      final ok = await _verifyPin(context, profile);
      if (!ok) return;
    }
    if (context.mounted) {
      Navigator.pop(context, profile);
    }
  }

  Future<bool> _verifyPin(BuildContext context, Profile profile) async {
    final l10n = AppLocalizations.of(context)!;
    bool verified = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinDialog(
        title: l10n.entrerPinProfil,
        onPinEntered: (pin) {
          final hash = sha256.convert(utf8.encode(pin)).toString();
          if (hash == profile.pinHash) {
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
}

class _ProfileCard extends StatelessWidget {
  final Profile profile;
  final bool isActive;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: [
        profile.name,
        if (profile.hasPin) 'protégé par PIN',
        if (isActive) 'profil actif',
      ].join(', '),
      child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primaryBlue.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: isActive
                  ? Border.all(color: AppColors.primaryBlue, width: 2)
                  : Border.all(color: Colors.white24, width: 1),
            ),
            child: Center(
              child: Text(profile.avatar,
                  style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 8),
          Text(profile.name,
              style: const TextStyle(fontSize: 13, color: Colors.white,
                  fontWeight: FontWeight.w500)),
          if (profile.hasPin)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ExcludeSemantics(child: Icon(Icons.lock_outline, size: 12,
                  color: Colors.white.withValues(alpha: 0.5))),
            ),
        ],
      ),
    ));
  }
}
