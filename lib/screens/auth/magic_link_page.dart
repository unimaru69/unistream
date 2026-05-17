import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/colors.dart';
import '../../providers/auth_provider.dart';

/// Passwordless sign-in via email OTP.
///
/// Two-step flow on a single screen:
///   1. User enters their email → "Envoyer le code" → Supabase
///      mails a 6-digit OTP (`AuthService.sendMagicLink`).
///   2. Six-digit code input appears + auto-focuses → user types
///      the code → "Vérifier" → `AuthService.verifyMagicLinkCode`
///      logs them in. AuthGate picks up the session and routes.
///
/// Used primarily on macOS DMG builds where Sign in with Apple is
/// unavailable (Developer ID off-store can't carry restricted
/// entitlements — see `macos/Runner/Release.entitlements`).
class MagicLinkPage extends ConsumerStatefulWidget {
  const MagicLinkPage({super.key});

  @override
  ConsumerState<MagicLinkPage> createState() => _MagicLinkPageState();
}

class _MagicLinkPageState extends ConsumerState<MagicLinkPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).clearError();
    final ok = await ref
        .read(authProvider.notifier)
        .sendMagicLink(_emailCtrl.text.trim());
    if (ok && mounted) {
      setState(() => _sent = true);
      // Bring focus on the OTP field so the user can paste / type
      // the code without an extra tap.
      Future<void>.microtask(() {
        if (mounted) _codeFocus.requestFocus();
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    // Supabase OTP length is project-configurable (default 6, can be
    // 6 to 10). Don't hard-cap on the client — accept anything 6-10
    // digits and let Supabase verify return the real error.
    if (code.length < 6) return;
    ref.read(authProvider.notifier).clearError();
    final ok = await ref.read(authProvider.notifier).verifyMagicLinkCode(
          email: _emailCtrl.text.trim(),
          code: code,
        );
    if (ok && mounted) {
      // AuthGate listens to authState — popping back is enough,
      // the gate will then route to splash / home.
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.mail_lock_outlined,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Lien magique',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _sent
                                  ? 'Entrez le code reçu par email.'
                                  : 'Recevez un code par email pour vous connecter sans mot de passe.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Email
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              enabled: !_sent,
                              style: const TextStyle(color: Colors.white),
                              decoration: _input('Email', Icons.email_outlined),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Champ obligatoire';
                                }
                                if (!v.contains('@') || !v.contains('.')) {
                                  return 'Email invalide';
                                }
                                return null;
                              },
                            ),

                            if (_sent) ...[
                              const SizedBox(height: 16),
                              // OTP code — accept 6-10 digits.
                              // Supabase OTP length is project-
                              // configurable. We don't know it
                              // client-side, so allow up to 10
                              // and let Supabase verify reject
                              // wrong-length tokens with a real
                              // error message.
                              TextField(
                                controller: _codeCtrl,
                                focusNode: _codeFocus,
                                keyboardType: TextInputType.number,
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  letterSpacing: 6,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                textAlign: TextAlign.center,
                                decoration: _input(
                                  'Code reçu par email',
                                  Icons.password_outlined,
                                ).copyWith(counterText: ''),
                                onSubmitted: (_) => _verifyCode(),
                              ),
                            ],

                            const SizedBox(height: 16),

                            if (auth.error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.redAccent.withValues(alpha: 0.31),
                                  ),
                                ),
                                child: Text(
                                  auth.error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            FilledButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : (_sent ? _verifyCode : _sendCode),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _sent ? 'Vérifier' : 'Envoyer le code',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                            ),

                            if (_sent) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: auth.isLoading ? null : _sendCode,
                                child: const Text(
                                  'Renvoyer le code',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
    );
  }
}
