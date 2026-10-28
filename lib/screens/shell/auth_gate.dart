import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import '../../providers/auth_provider.dart';
import '../auth/onboarding_screen.dart';
import 'main_shell.dart';

/// Decides what to show from the auth state. Because every protected screen
/// lives below this widget, signing out immediately removes access (FR-11).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.initialized) {
      return const Scaffold(body: LoadingView(message: 'Loading MealRescue...'));
    }
    if (!auth.isSignedIn) return const OnboardingScreen();
    if (auth.profile == null) return _ProfileLoading(error: auth.profileError);
    return const MainShell();
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error == null) const CircularProgressIndicator(),
                if (error != null)
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.red),
                const SizedBox(height: 16),
                Text(
                  error ?? 'Setting up your account...',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.read<AuthProvider>().signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
