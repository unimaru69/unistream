import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/logger.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/content_repository.dart';
import '../splash_screen.dart';
import 'auth_screen.dart';

/// Top-level gate that wraps the app's navigation.
///
/// - While loading → brand splash (gradient + logo + spinner).
/// - If not authenticated → [AuthScreen] (login/signup).
/// - If authenticated → [SplashScreen] (existing flow).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Demo mode: skip auth and go straight to splash which will auto-configure.
    if (kDemoMode) {
      return const SplashScreen();
    }

    final auth = ref.watch(authProvider);

    AppLogger.info(LogModule.ui,
        'AuthGate build: isLoading=${auth.isLoading}, '
        'isAuthenticated=${auth.isAuthenticated}, '
        'user=${auth.user?.email ?? "none"}');

    if (auth.isLoading) {
      return const _LoadingSplash();
    }

    if (!auth.isAuthenticated) {
      return const AuthScreen();
    }

    return const SplashScreen();
  }
}

class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'UniStream',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
