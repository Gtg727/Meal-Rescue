import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Shown instead of the app when Firebase has not been configured yet.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.settings_suggest,
                  size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Firebase setup required',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(message),
              const SizedBox(height: 16),
              const Text('1. dart pub global activate flutterfire_cli'),
              const Text('2. flutterfire configure'),
              const Text('3. flutter run'),
            ],
          ),
        ),
      ),
    );
  }
}
