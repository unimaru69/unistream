import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/colors.dart';
import '../core/logger.dart';
import '../l10n/app_localizations.dart';
import '../models/app_config.dart';
import '../models/profile.dart';
import '../repositories/content_repository.dart';
import '../services/supabase_config.dart';
import '../utils/profile_scope.dart';
import '../widgets/pin_dialog.dart';
import 'epg/epg_grid_screen.dart';
import 'home/home_screen.dart';
import 'onboarding_screen.dart';
import 'profiles/profile_selector_screen.dart';
import 'settings_screen.dart';

/// Allows injecting a custom HTTP client for testing.
@visibleForTesting
http.Client? splashHttpClient;

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  String? _statusMessage;
  bool _showLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startLoadingSequence();
      }
    });
  }

  Future<void> _startLoadingSequence() async {
    if (!mounted) return;

    setState(() => _showLoading = true);

    // Demo mode: configure a fake profile and go straight to home.
    if (kDemoMode) {
      AppConfig.currentUserId = 'demo-user';
      AppConfig.activeProfileId = 'demo';
      AppConfig.profiles = [
        Profile(
          id: 'demo',
          name: 'Demo',
          avatar: '🎬',
          serverUrl: 'https://demo.unimaru.fr',
          username: 'demo',
          password: 'demo',
        ),
      ];
      AppConfig.serverUrl = 'https://demo.unimaru.fr';
      AppConfig.username = 'demo';
      AppConfig.password = 'demo';
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final target = switch (kDemoScreen) {
        'epg' => const EpgGridScreen(),
        'settings' => const SettingsScreen(),
        _ => const HomeScreen(),
      };
      _navigateTo(target);
      return;
    }

    // Step 1: Load config scoped to authenticated user
    final l10n = AppLocalizations.of(context);
    setState(() => _statusMessage = l10n?.splashLoadingConfig ?? 'Loading configuration...');
    AppLogger.breadcrumb('splash', 'Loading configuration');

    AppConfig.currentUserId = SupabaseConfig.currentUserId;
    await AppConfig.load();
    // `_initSync` (post-frame callback in main.dart) may have already
    // touched profile-scoped providers while `activeProfileId` was still
    // empty — drop their stale state so the next watcher rebuilds against
    // the now-loaded profile.
    if (mounted) invalidateProfileScopedProviders(ref.invalidate);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (!AppConfig.isConfigured) {
      // No profile yet — land the user on the ProfileSelector empty
      // state ("Bienvenue, créez un profil") instead of jumping
      // straight into the server-config form. The selector's "+"
      // tile pushes the OnboardingScreen when tapped, so the
      // server-config UX is still reachable in one click but the
      // user sees the concept of "profile" first.
      final result = await Navigator.push<ProfileSelectorResult>(
        context,
        MaterialPageRoute(builder: (_) => const ProfileSelectorScreen(
          profiles: [],
          activeProfileId: null,
          allowCreate: true,
        )),
      );
      if (!mounted) return;
      if (result is ProfileCreateRequested) {
        _navigateTo(const OnboardingScreen());
      } else if (result is ProfileSelectedResult) {
        // Edge case: result came from somewhere (sync race?). Bounce
        // through onboarding anyway — without a configured server
        // we can't go further.
        _navigateTo(const OnboardingScreen());
      } else {
        // User backed out via Esc / system back. Re-show the picker
        // by restarting the splash sequence so they don't get
        // stranded on a black screen.
        _startLoadingSequence();
      }
      return;
    }

    // Step 2: Connectivity check
    setState(() => _statusMessage = l10n?.splashConnecting ?? 'Connecting to server...');
    AppLogger.breadcrumb('splash', 'Connectivity check');

    try {
      final client = splashHttpClient ?? http.Client();
      final shouldClose = splashHttpClient == null;
      try {
        await client
            .head(Uri.parse(AppConfig.serverUrl))
            .timeout(const Duration(seconds: 3));
      } finally {
        if (shouldClose) client.close();
      }
    } catch (e) {
      AppLogger.warning(LogModule.api, 'Splash connectivity check failed', error: e);
      // Still navigate to HomeScreen — it handles offline mode
    }

    if (!mounted) return;

    // Step 3: Profile selection (if multiple profiles) or PIN check (single profile)
    if (AppConfig.profiles.length > 1) {
      setState(() => _statusMessage = l10n?.splashReady ?? 'Ready!');
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      final result = await Navigator.push<ProfileSelectorResult>(
        context,
        MaterialPageRoute(builder: (_) => ProfileSelectorScreen(
          profiles: AppConfig.profiles,
          activeProfileId: AppConfig.activeProfileId,
          // Multi-profile case: also offer "+ Nouveau profil" so
          // the user can add another from the same picker.
          allowCreate: true,
        )),
      );
      if (!mounted) return;
      if (result is ProfileSelectedResult) {
        final selected = result.profile;
        if (selected.id != AppConfig.activeProfileId) {
          await AppConfig.switchProfile(selected.id);
          if (mounted) invalidateProfileScopedProviders(ref.invalidate);
        }
      } else if (result is ProfileCreateRequested) {
        _navigateTo(const OnboardingScreen());
        return;
      }
    } else if (AppConfig.profiles.length == 1 && AppConfig.profiles.first.hasPin) {
      // Single profile with PIN — verify before granting access
      final profile = AppConfig.profiles.first;
      final ok = await _verifyPin(profile);
      if (!ok || !mounted) return;
    }

    // Step 4: Load EPG cache from disk + retry config
    final repo = ContentRepository();
    repo.loadEpgCacheFromDisk();
    repo.loadRetryConfig();

    // Step 5: Ready
    setState(() => _statusMessage = l10n?.splashReady ?? 'Ready!');
    AppLogger.breadcrumb('splash', 'Ready, navigating to home');

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _navigateTo(const HomeScreen());
  }

  Future<bool> _verifyPin(Profile profile) async {
    final l10n = AppLocalizations.of(context);
    bool verified = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinDialog(
        title: l10n?.entrerPinProfil ?? 'Enter PIN',
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

  void _navigateTo(Widget destination) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 120,
                      height: 120,
                    ),
                  )),
                  const SizedBox(height: 16),
                  const Text(
                    'UniStream',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_showLoading) ...[
                    const SizedBox(height: 32),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _statusMessage ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
