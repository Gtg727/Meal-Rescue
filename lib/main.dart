import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/setup_required_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // `flutterfire configure` regenerates firebase_options.dart, so detect the
  // placeholder through the options themselves.
  if (DefaultFirebaseOptions.currentPlatform.apiKey == 'REPLACE_ME') {
    runApp(const _SetupApp(
      message: 'firebase_options.dart still contains placeholder values. '
          'Run "flutterfire configure" (see README) and rebuild.',
    ));
    return;
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(_SetupApp(message: 'Firebase failed to initialise: $e'));
    return;
  }

  runApp(const MealRescueApp());
}

class _SetupApp extends StatelessWidget {
  const _SetupApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: SetupRequiredScreen(message: message),
    );
  }
}
