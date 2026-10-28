import 'package:flutter/material.dart';

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final (heading, body) in sections) ...[
            Text(heading,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => const _InfoPage(
        title: 'Help',
        sections: [
          (
            'How MealRescue works',
            'Providers post surplus food with a safe collection deadline. '
                'Receivers reserve portions, the provider accepts the request, '
                'the receiver collects the food and confirms, and the provider '
                'confirms the handover. Impact numbers update when a pickup is completed.'
          ),
          (
            'Why was my request not accepted?',
            'Requests wait for the provider. A provider may reject a request, '
                'or it can expire if the pickup deadline passes. Rejected, '
                'cancelled and expired requests release the portions for others.'
          ),
          (
            'Food safety',
            'Always check food before eating it. Do not eat anything that looks, '
                'smells or feels wrong. Check allergen and storage information on '
                'the listing. Use the flag icon to report unsafe or misleading listings.'
          ),
          (
            'Need more help?',
            'Contact your MealRescue administrator or the project maintainer.'
          ),
        ],
      );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _InfoPage(
        title: 'Privacy Policy',
        sections: [
          (
            'What we collect',
            'Your name, email, optional phone number, organisation name and '
                'default pickup area, plus the listings and reservations you create.'
          ),
          (
            'Who can see it',
            'Your name and organisation are visible to people you transact with. '
                'Your phone number is only used to coordinate a pickup you are part of. '
                'Your email is never shown to other users.'
          ),
          (
            'Your choices',
            'You can edit your details in Profile at any time. Location '
                'permission is never required: enter an address manually.'
          ),
          (
            'Demo notice',
            'This is a student MVP. Replace this text with your organisation\'s '
                'real privacy policy before a public release.'
          ),
        ],
      );
}
