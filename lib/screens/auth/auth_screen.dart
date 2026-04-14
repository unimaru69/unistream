import 'package:flutter/material.dart';
import '../../core/colors.dart';
import 'login_page.dart';
import 'signup_page.dart';

/// Main auth screen with toggle between Login and SignUp pages.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              LoginPage(onSwitchToSignup: () => _goToPage(1)),
              SignupPage(onSwitchToLogin: () => _goToPage(0)),
            ],
          ),
        ),
      ),
    );
  }
}
