import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

enum LegalDoc { terms, privacy }

/// Simple in-app Terms of Use / Privacy pages.
class LegalScreen extends StatelessWidget {
  final LegalDoc doc;
  const LegalScreen({super.key, required this.doc});

  static const _terms = <(String, String)>[
    ('Using TechDaily', 'TechDaily summarises technology news from public sources and links to the original article. Summaries and “In simple words” explanations are written to help you understand a story quickly; always check the original source before relying on details.'),
    ('Your account', 'You are responsible for keeping your sign-in details safe. You can delete saved stories at any time, and you can ask us to delete your account.'),
    ('AI features', 'Ask AI answers are generated from the article’s text and may be incomplete or wrong. They are not professional, legal, financial or medical advice.'),
    ('Content ownership', 'Original articles belong to their publishers. TechDaily shows short summaries with attribution and a link to the source.'),
    ('Changes', 'We may update these terms as the app evolves. Continuing to use TechDaily after an update means you accept the new terms.'),
  ];

  static const _privacy = <(String, String)>[
    ('What we collect', 'If you create an account we store your email, display name, saved stories and reading preferences. If you turn on notifications we store a device token so we can send alerts.'),
    ('On your device', 'Reading history, guest bookmarks and theme settings are stored locally on your device.'),
    ('Ask AI', 'Questions you ask are sent to our server together with the article ID to generate an answer. Don’t include personal information in questions.'),
    ('Sharing', 'We don’t sell your data. We use Google Firebase to run sign-in, storage and notifications.'),
    ('Your choices', 'You can turn notifications off in Profile, clear reading history, remove saved stories, or sign out at any time.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTerms = doc == LegalDoc.terms;
    final sections = isTerms ? _terms : _privacy;
    return Scaffold(
      appBar: AppBar(title: Text(isTerms ? 'Terms of Use' : 'Privacy Policy')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              for (final (title, body) in sections) ...[
                Text(title, style: AppTheme.display(18, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 6),
                Text(body, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15.5)),
                const SizedBox(height: 22),
              ],
              Text('Last updated November 2026', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
