import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../core/colors.dart';
import '../../models/profile.dart';
import '../../widgets/pin_dialog.dart';

/// Result returned by [ProfileSelectorScreen] via `Navigator.pop`.
/// Sealed so the caller can `switch` over the outcomes without
/// magic sentinel values.
sealed class ProfileSelectorResult {
  const ProfileSelectorResult();
}

/// User picked an existing profile (PIN already verified inside the
/// selector if the profile was protected).
class ProfileSelectedResult extends ProfileSelectorResult {
  const ProfileSelectedResult(this.profile);
  final Profile profile;
}

/// User tapped the "+ Nouveau profil" tile — caller should push the
/// onboarding / server-config flow to create one.
class ProfileCreateRequested extends ProfileSelectorResult {
  const ProfileCreateRequested();
}

/// Full-screen profile picker shown at app startup.
///
/// Shows existing profiles (when any) plus a "+ Nouveau profil" tile
/// when [onCreateNew] is non-null. Even with zero profiles the screen
/// is the right landing — the "+" tile + a friendly headline beats
/// jumping the user straight into a server-config form before they've
/// understood the concept of a profile.
///
/// Returns a [ProfileSelectorResult] via `Navigator.pop`.
class ProfileSelectorScreen extends StatelessWidget {
  final List<Profile> profiles;
  final String? activeProfileId;
  final bool allowCreate;

  const ProfileSelectorScreen({
    super.key,
    required this.profiles,
    this.activeProfileId,
    this.allowCreate = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Empty-state headline differs from the "Qui regarde ?" Netflix-y
    // prompt — we're inviting the user to create their first profile.
    final title = profiles.isEmpty && allowCreate
        ? 'Bienvenue'
        : l10n.quiRegarde;
    final subtitle = profiles.isEmpty && allowCreate
        ? 'Créez un profil pour commencer'
        : null;
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
                  Text(title,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7))),
                  ],
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      ...profiles.map((pr) => _ProfileCard(
                        profile: pr,
                        isActive: pr.id == activeProfileId,
                        onTap: () => _selectProfile(context, pr),
                      )),
                      if (allowCreate)
                        _AddProfileCard(
                          onTap: () => Navigator.pop(
                            context,
                            const ProfileCreateRequested(),
                          ),
                        ),
                    ],
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
      Navigator.pop(context, ProfileSelectedResult(profile));
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

class _AddProfileCard extends StatelessWidget {
  const _AddProfileCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Nouveau profil',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                  // Dashed-style border would be nicer but Flutter
                  // ships no out-of-the-box dashed BorderSide; the
                  // solid + low-opacity treatment reads as "empty
                  // slot" well enough.
                ),
              ),
              child: const Center(
                child: Icon(Icons.add, size: 36, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nouveau profil',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
