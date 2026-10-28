import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/donation_provider.dart';
import 'providers/moderation_provider.dart';
import 'providers/nav_provider.dart';
import 'providers/reservation_provider.dart';
import 'screens/shell/auth_gate.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'services/donation_service.dart';
import 'services/notification_service.dart';
import 'services/report_service.dart';
import 'services/reservation_service.dart';

class MealRescueApp extends StatelessWidget {
  const MealRescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services (plain objects talking to Firebase).
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DonationService>(create: (_) => DonationService()),
        Provider<ReservationService>(create: (_) => ReservationService()),
        Provider<ReportService>(create: (_) => ReportService()),
        Provider<AdminService>(create: (_) => AdminService()),
        Provider<NotificationService>(create: (_) => NotificationService()),

        // State.
        ChangeNotifierProvider<NavProvider>(create: (_) => NavProvider()),
        ChangeNotifierProvider<AuthProvider>(
          create: (c) => AuthProvider(
            c.read<AuthService>(),
            c.read<NotificationService>(),
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, DonationProvider>(
          create: (c) => DonationProvider(c.read<DonationService>()),
          update: (c, auth, previous) =>
              (previous ?? DonationProvider(c.read<DonationService>()))
                ..attach(auth.profile),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ReservationProvider>(
          create: (c) => ReservationProvider(c.read<ReservationService>()),
          update: (c, auth, previous) =>
              (previous ?? ReservationProvider(c.read<ReservationService>()))
                ..attach(auth.profile),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ModerationProvider>(
          create: (c) => ModerationProvider(
            c.read<ReportService>(),
            c.read<AdminService>(),
          ),
          update: (c, auth, previous) => (previous ??
              ModerationProvider(
                c.read<ReportService>(),
                c.read<AdminService>(),
              ))
            ..attach(auth.profile),
        ),
      ],
      child: MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}
