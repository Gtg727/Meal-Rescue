import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../admin/admin_dashboard.dart';
import '../provider/provider_home.dart';
import '../receiver/receiver_home.dart';

/// Screen 3 - role-specific home dashboard.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().profile;
    if (user == null) return const SizedBox.shrink();
    if (user.isAdmin) return const AdminDashboard();
    if (user.isProvider) return const ProviderHome();
    return const ReceiverHome();
  }
}
