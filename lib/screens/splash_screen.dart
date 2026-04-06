import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/colors.dart';
import '../core/logger.dart';
import '../l10n/app_localizations.dart';
import '../models/app_config.dart';
import '../models/profile.dart';
import '../services/xtream_api.dart';
import 'home/home_screen.dart';
import 'onboarding_screen.dart';
import 'profiles/profile_selector_screen.dart';

/// Allows injecting a custom HTTP client for testing.
@visibleForTesting
http.Client? splashHttpClient;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
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

    // Step 1: Check configuration
    final l10n = AppLocalizations.of(context);
    setState(() => _statusMessage = l10n?.splashLoadingConfig ?? 'Loading configuration...');
    AppLogger.breadcrumb('splash', 'Loading configuration');

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (!AppConfig.isConfigured) {
      _navigateTo(const OnboardingScreen());
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

    // Step 3: Profile selection (if multiple profiles)
    if (AppConfig.profiles.length > 1) {
      setState(() => _statusMessage = l10n?.splashReady ?? 'Ready!');
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      final selected = await Navigator.push<Profile>(
        context,
        MaterialPageRoute(builder: (_) => ProfileSelectorScreen(
          profiles: AppConfig.profiles,
          activeProfileId: AppConfig.activeProfileId,
        )),
      );
      if (!mounted) return;
      if (selected != null && selected.id != AppConfig.activeProfileId) {
        await AppConfig.switchProfile(selected.id);
      }
    }

    // Step 4: Load EPG cache from disk + retry config
    XtreamApi.loadEpgCacheFromDisk();
    XtreamApi.loadRetryConfig();

    // Step 5: Ready
    setState(() => _statusMessage = l10n?.splashReady ?? 'Ready!');
    AppLogger.breadcrumb('splash', 'Ready, navigating to home');

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _navigateTo(const HomeScreen());
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 120,
                      height: 120,
                    ),
                  ),
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
                    Text(
                      _statusMessage ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
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
