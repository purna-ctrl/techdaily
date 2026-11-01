import 'package:flutter/material.dart';

import '../../core/constants/story_categories.dart';
import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/auth_user.dart';
import '../../widgets/v2/story_parts.dart';
import '../auth_screen.dart';
import '../legal_screen.dart';

/// Settings: topic filter, newsletter, optional sign-in, About.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = StoriesScope.of(context);
    final theme = Theme.of(context);
    Widget heading(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Semantics(header: true, child: Text(t, style: AppTheme.display(17, color: theme.colorScheme.onSurface))),
        );
    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: AppTheme.display(20, color: theme.colorScheme.onSurface))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 40), children: [
            heading('Topics'),
            Text('Choose which categories appear as tabs and in Top Stories. Saved on this device.',
                style: TextStyle(color: AppTheme.mutedOf(context), fontSize: 13.5)),
            const SizedBox(height: 6),
            ValueListenableBuilder<Set<String>>(
              valueListenable: scope.topics,
              builder: (context, hidden, _) => Column(children: [
                for (final c in kStoryCategories)
                  SwitchListTile(
                    key: ValueKey('topic-${c.id}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    secondary: Icon(c.icon, color: c.color),
                    title: Text(c.label),
                    value: !hidden.contains(c.id),
                    onChanged: (v) => scope.topics.setVisible(c.id, v),
                  ),
                if (hidden.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: scope.topics.showAll, child: const Text('Show all topics')),
                  ),
              ]),
            ),
            heading('Newsletter'),
            const NewsletterSignup(source: 'app-settings'),
            heading('Account'),
            StreamBuilder<AuthUser?>(
              stream: scope.auth.authStateChanges,
              initialData: scope.auth.currentUser,
              builder: (context, snap) {
                final user = snap.data;
                if (user == null) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.account_circle_outlined),
                    title: const Text('Sign in (optional)'),
                    subtitle: const Text('Keep saved stories on all your devices. Google or email.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthScreen(authRepository: scope.auth))),
                  );
                }
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.account_circle_rounded),
                  title: Text(user.displayName?.isNotEmpty == true ? user.displayName! : user.email),
                  subtitle: Text(user.email),
                  trailing: TextButton(onPressed: scope.auth.signOut, child: const Text('Sign out')),
                );
              },
            ),
            heading('About'),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About TechDaily'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pushNamed('/app/about'),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(doc: LegalDoc.privacy))),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms of use'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(doc: LegalDoc.terms))),
            ),
          ]),
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget p(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 15.5, height: 1.55)));
    Widget h(String t) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Semantics(header: true, child: Text(t, style: AppTheme.display(18, color: theme.colorScheme.onSurface))),
        );
    return Scaffold(
      appBar: AppBar(title: Text('About TechDaily', style: AppTheme.display(19, color: theme.colorScheme.onSurface))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const CategoryArt(categoryId: 'top-stories', height: 90),
            const SizedBox(height: 14),
            p('TechDaily explains technology news for everyday people in India, in simple words — AI, phones and gadgets, chips, startups and India tech, innovations, money and fintech, privacy, and scams & security.'),
            h('How a story is made'),
            p('Every hour we read dozens of news sites and official sources (RSS feeds). Reports about the same event are grouped into one story, and an AI model writes a short card in its own words: what happened, does it affect you, what to do, and what it means for you. Scam stories also explain how the trick works and the warning signs.'),
            p('We never copy articles or publisher photos. Every card links to all the original reports, so you can always read the full story at the source.'),
            h('“Developing” stories'),
            p('A Developing badge means there are few reports so far, the claim is not confirmed yet, or the card was written automatically before the AI version is ready. Details may change.'),
            h('Scams'),
            p('If you lost money to a scam in India, call 1930 (national cyber-crime helpline) immediately or report at cybercrime.gov.in, and call your bank to block your card or UPI.'),
            h('Contact'),
            p('Found a mistake? Use the “Read original” links to check the source, and tell us through the feedback address listed on the website.'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: () => openExternal(context, 'https://cybercrime.gov.in'), child: const Text('cybercrime.gov.in')),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// `/app/newsletter?email=...` — the static pages' no-JS signup lands here.
class NewsletterScreen extends StatelessWidget {
  final String? email;
  const NewsletterScreen({super.key, this.email});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Newsletter', style: AppTheme.display(19, color: theme.colorScheme.onSurface))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            NewsletterSignup(source: 'web-nojs', initialEmail: email),
          ]),
        ),
      ),
    );
  }
}
