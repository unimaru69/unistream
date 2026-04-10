import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../core/colors.dart';
import '../core/theme_colors.dart';
import '../providers/config_provider.dart';
import '../services/m3u_parser.dart';
import '../repositories/content_repository.dart';
import '../core/logger.dart';
import '../services/xtream_api.dart' show XtreamApi, httpGet;
import '../utils/api_error_localizer.dart';
import 'home/home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;
  bool _testing = false;
  bool? _testSuccess;

  @override
  void dispose() {
    _pageController.dispose();
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _importM3u() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      String content;
      if (bytes != null) {
        content = utf8.decode(bytes, allowMalformed: true);
      } else {
        final path = result.files.first.path;
        if (path == null) return;
        content = await File(path).readAsString();
      }
      final creds = parseM3uCredentials(content);
      if (creds == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.fichierM3uInvalide)),
          );
        }
        return;
      }
      _serverCtrl.text = creds.serverUrl;
      _userCtrl.text = creds.username;
      _passCtrl.text = creds.password;
      _goToPage(1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importReussi)),
        );
      }
    } catch (e, st) {
      AppLogger.warning('onboarding', 'M3U import failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fichierM3uInvalide)),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _testSuccess = null;
      _error = null;
    });
    try {
      final server = _serverCtrl.text.trim();
      final user = _userCtrl.text.trim();
      final pass = _passCtrl.text.trim();
      final url =
          '$server/player_api.php?username=$user&password=$pass';
      final r = await httpGet(url, maxRetries: 1,
          timeout: const Duration(seconds: 10));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final auth = data['user_info']?['auth'];
      setState(() {
        _testing = false;
        _testSuccess = auth == 1;
        if (auth != 1) _error = AppLocalizations.of(context)!.authEchouee;
      });
    } catch (e, st) {
      AppLogger.warning('onboarding', 'Connection test failed', error: e, stackTrace: st);
      setState(() {
        _testing = false;
        _testSuccess = false;
        _error = localizeApiError(XtreamApi.errorKey(e), AppLocalizations.of(context)!);
      });
    }
  }

  Future<void> _authenticate() async {
    final l10n = AppLocalizations.of(context)!;
    final server = _serverCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(configProvider.notifier).save(server, user, pass);
      final auth = await _repo.authenticate();
      if (auth['user_info']?['auth'] != 1) {
        setState(() {
          _error = l10n.authEchouee;
          _saving = false;
        });
        return;
      }
      if (!mounted) return;
      _goToPage(2);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      });
    } catch (e, st) {
      AppLogger.warning('onboarding', 'Authentication failed', error: e, stackTrace: st);
      setState(() {
        _error = localizeApiError(XtreamApi.errorKey(e), AppLocalizations.of(context)!);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildWelcomePage(context),
          _buildConfigPage(context),
          _buildSuccessPage(context),
        ],
      ),
      ),
    );
  }

  Widget _buildWelcomePage(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 100,
                height: 100,
              ),
            )),
            const SizedBox(height: 24),
            Text(
              l10n.bienvenue,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.configureServeur,
              textAlign: TextAlign.center,
              style: TextStyle(color: tc.textTertiary, fontSize: 15),
            ),
            const SizedBox(height: 48),
            FilledButton(
              onPressed: () => _goToPage(1),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child:
                  Text(l10n.commencer, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _importM3u,
              icon: const Icon(Icons.file_open, size: 18),
              label: Text(l10n.importerM3u),
              style: TextButton.styleFrom(
                foregroundColor: tc.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigPage(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.dns, size: 48, color: AppColors.primaryBlue),
                const SizedBox(height: 16),
                Text(
                  l10n.configureServeur,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _serverCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: l10n.serverUrlHint,
                    hintText: l10n.serverUrlHint,
                    prefixIcon: const Icon(Icons.dns, size: 20),
                    filled: true,
                    fillColor: tc.inputFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.tousChampRequis;
                    final uri = Uri.tryParse(v.trim());
                    if (uri == null || !uri.hasScheme) return l10n.urlInvalide;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _userCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: l10n.nomUtilisateur,
                    prefixIcon: const Icon(Icons.person, size: 20),
                    filled: true,
                    fillColor: tc.inputFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.tousChampRequis : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(fontSize: 14),
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
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.tousChampRequis : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(_error!,
                        style:
                            const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ],
                if (_testSuccess == true) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ExcludeSemantics(child: const Icon(Icons.check_circle, color: Colors.green, size: 20)),
                        const SizedBox(width: 8),
                        Text(l10n.connexionReussie,
                            style: const TextStyle(color: Colors.green, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find, size: 18),
                    label: Text(l10n.testerConnexion),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _authenticate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(l10n.connexion,
                          style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessPage(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(child: _SuccessCheckAnimation()),
          const SizedBox(height: 24),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.serveurConfigure,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: tc.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessCheckAnimation extends StatefulWidget {
  const _SuccessCheckAnimation();
  @override
  State<_SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<_SuccessCheckAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: const Icon(
        Icons.check_circle,
        size: 80,
        color: Colors.green,
      ),
    );
  }
}
