import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_snack.dart';
import '../../providers/auth_provider.dart';

/// Edit permitted profile fields. Role, email and verification status are
/// read-only here and also protected by the security rules.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _org;
  late final TextEditingController _area;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().profile!;
    _name = TextEditingController(text: u.fullName);
    _phone = TextEditingController(text: u.phone);
    _org = TextEditingController(text: u.organizationName);
    _area = TextEditingController(text: u.defaultPickupArea);
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _org, _area]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await auth.updateProfile(
        fullName: _name.text,
        phone: _phone.text,
        organizationName: _org.text,
        defaultPickupArea: _area.text,
      );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthProvider>().profile!;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppTheme.inputDecoration('Full name',
                      icon: Icons.person_outline),
                  validator: Validators.fullName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: u.email,
                  enabled: false,
                  decoration: AppTheme.inputDecoration('Email',
                      icon: Icons.email_outlined),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: AppRoles.label(u.role),
                  enabled: false,
                  decoration: AppTheme.inputDecoration('Account type',
                      icon: Icons.badge_outlined,
                      hint: 'Cannot be changed'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: AppTheme.inputDecoration('Phone',
                      icon: Icons.phone_outlined),
                  validator: Validators.phoneOptional,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _org,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppTheme.inputDecoration('Organisation name',
                      icon: Icons.business_outlined),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _area,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppTheme.inputDecoration('Default pickup area',
                      icon: Icons.place_outlined),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.white))
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
