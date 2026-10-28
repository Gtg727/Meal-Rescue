import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/app_router.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Screen 1 - splash / onboarding.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism,
                    size: 64, color: AppColors.white),
              ),
              const SizedBox(height: 28),
              Text(
                kAppName,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                kTagline,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              const Text(
                'Restaurants, canteens and event organisers share surplus '
                'edible food. NGOs and volunteers reserve it and collect it '
                'before it goes to waste.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.neutral, height: 1.5),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => AppRouter.push(context, const RegisterScreen()),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => AppRouter.push(context, const LoginScreen()),
                child: const Text('Log In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
