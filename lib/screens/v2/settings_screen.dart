import 'package:flutter/material.dart';

import '../../core/constants/story_categories.dart';
import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/auth_user.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/v2/story_parts.dart';
import '../../widgets/v3/language_widgets.dart' show LanguageOptions;
import 'scam_check_screen.dart';
import '../auth_screen.dart';
import '../legal_screen.dart';
import '../../l10n/app_language.dart' show tr;

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
      appBar: AppBar(title: Text(tr('Settings'), style: AppTheme.display(20, color: theme.colorScheme.onSurface))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 40), children: [
            heading(tr('Language')),
            Text(tr('Menus are translated here; stories are translated by AI when you open them.'),
                style: TextStyle(color: AppTheme.mutedOf(context), fontSize: 13.5)),
            const LanguageOptions(),
            heading(tr('Safety tools')),
            ListTile(
              key: const ValueKey('settings-scam-check'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.policy_rounded, color: Color(0xFFFF7683)),
              title: Text(tr('Scam checker')),
              subtitle: Text(tr('Paste a message and see if it’s a scam.')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => ScamCheckScreen.open(context),
            ),
            heading(tr('Topics')),
            Text(tr('Choose which categories appear as tabs and in Top Stories. Saved on this device.'),
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
                    child: TextButton(onPressed: scope.topics.showAll, child: Text(tr('Show all topics'))),
                  ),
              ]),
            ),
            heading(tr('Newsletter')),
            const NewsletterSignup(source: 'app-settings'),
            heading(tr('Account')),
            StreamBuilder<AuthUser?>(
              stream: scope.auth.authStateChanges,
              initialData: scope.auth.currentUser,
              builder: (context, snap) {
                final user = snap.data;
                if (user == null) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.account_circle_outlined),
                    title: Text(tr('Sign in (optional)')),
                    subtitle: Text(tr('Keep saved stories on all your devices. Google or email.')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthScreen(authRepository: scope.auth))),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.account_circle_rounded),
                      title: Text(user.displayName?.isNotEmpty == true ? user.displayName! : user.email),
                      subtitle: Text(user.email),
                      trailing: TextButton(onPressed: scope.auth.signOut, child: Text(tr('Sign out'))),
                    ),
                    ListTile(
                      key: const Key('delete-account'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                      title: Text(tr('Delete account'), style: TextStyle(color: Colors.redAccent)),
                      subtitle: Text(tr('Removes your account and synced saved stories.')),
                      onTap: () => _confirmDelete(context, scope.auth),
                    ),
                  ],
                );
              },
            ),
            heading(tr('About')),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(tr('About TechDaily')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pushNamed('/app/about'),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(tr('Privacy')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(doc: LegalDoc.privacy))),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.description_outlined),
              title: Text(tr('Terms of use')),
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
      appBar: AppBar(title: Text(tr('About TechDaily'), style: AppTheme.display(19, color: theme.colorScheme.onSurface))),
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
      appBar: AppBar(title: Text(tr('Newsletter'), style: AppTheme.display(19, color: theme.colorScheme.onSurface))),
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

Future<void> _confirmDelete(BuildContext context, AuthRepository auth) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text('This permanently deletes your TechDaily account and the saved stories synced to it. Stories saved on this device stay.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await auth.deleteAccount();
    messenger.showSnackBar(const SnackBar(content: Text('Your account was deleted.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
  }
}
