import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snack.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../routes/app_router.dart';
import 'edit_profile_screen.dart';
import 'info_screens.dart';

/// Screen 10 - profile and settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to use MealRescue.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final nav = context.read<NavProvider>();
    final auth = context.read<AuthProvider>();
    AppRouter.popToRoot(context);
    nav.index = 0;
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().profile;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initials(user.fullName),
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                Text(user.fullName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                Text(AppRoles.label(user.role),
                    style: const TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _Field(Icons.email_outlined, 'Email', user.email),
                _Field(Icons.phone_outlined, 'Phone',
                    user.phone.isEmpty ? 'Not set' : user.phone),
                _Field(Icons.badge_outlined, 'Account type',
                    AppRoles.label(user.role)),
                _Field(
                    Icons.business_outlined,
                    'Organisation',
                    user.organizationName.isEmpty
                        ? 'Not set'
                        : user.organizationName),
                _Field(
                    Icons.place_outlined,
                    'Default pickup area',
                    user.defaultPickupArea.isEmpty
                        ? 'Not set'
                        : user.defaultPickupArea),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => AppRouter.push(context, const EditProfileScreen()),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Profile'),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => AppRouter.push(context, const HelpScreen()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => AppRouter.push(context, const PrivacyScreen()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.red),
                  title: const Text('Logout',
                      style: TextStyle(color: AppColors.red)),
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.neutral, fontSize: 12)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
