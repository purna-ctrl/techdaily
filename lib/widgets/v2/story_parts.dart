import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/story_categories.dart';
import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../models/story.dart';
import '../../services/v2/newsletter_service.dart';
import '../../services/v2/story_share.dart';
import '../v3/category_art.dart';
import '../v3/story_cards.dart';

/// Generated category artwork block (fallback art; see widgets/v3/category_art.dart).
class CategoryArt extends StatelessWidget {
  final String categoryId;
  final double height;
  final double radius;
  const CategoryArt({super.key, required this.categoryId, this.height = 96, this.radius = 14});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CategoryArtwork(categoryId: categoryId, borderRadius: BorderRadius.circular(radius)),
      );
}

class CategoryLabel extends StatelessWidget {
  final String categoryId;
  const CategoryLabel({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final c = storyCategoryById(categoryId);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(c.icon, size: 14, color: AppTheme.accentOf(context)),
      const SizedBox(width: 5),
      Text(c.label.toUpperCase(), style: AppTheme.kicker(size: 11.5, color: AppTheme.accentOf(context))),
    ]);
  }
}

class DevelopingBadge extends StatelessWidget {
  const DevelopingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Few or unconfirmed reports so far — details may change',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF2B2205),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF5C4A0B)),
        ),
        child: Text('DEVELOPING', style: AppTheme.kicker(size: 10.5, color: const Color(0xFFFFD166))),
      ),
    );
  }
}

String istTime(DateTime t) => '${DateFormat('d MMM, h:mm a').format(t.toUtc().add(const Duration(hours: 5, minutes: 30)))} IST';

/// "MONEY & FINTECH · DEVELOPING" + "2h ago · ET Tech, Mint".
class StoryMeta extends StatelessWidget {
  final Story story;
  final bool absoluteTime;
  const StoryMeta({super.key, required this.story, this.absoluteTime = false});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOf(context);
    final names = story.sourceNames;
    final when = absoluteTime ? istTime(story.publishedAt) : AppDateUtils.formatRelativeTime(story.publishedAt);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        CategoryLabel(categoryId: story.category),
        if (story.developing) const DevelopingBadge(),
      ]),
      const SizedBox(height: 6),
      Text(
        '$when · ${names.length > 1 ? '${names.length} sources: ' : ''}${names.join(', ')}',
        style: TextStyle(fontSize: 13, color: muted, height: 1.35),
      ),
    ]);
  }
}

class SectionBlock extends StatelessWidget {
  final String title;
  final Widget child;
  final bool highlight;
  final bool warning;
  const SectionBlock({super.key, required this.title, required this.child, this.highlight = false, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final border = warning
        ? const Color(0xFF7A2E12)
        : highlight
            ? AppTheme.accentOf(context)
            : AppTheme.borderOf(context);
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: warning ? const Color(0xFF1A1210) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(title, style: AppTheme.display(16, color: Theme.of(context).colorScheme.onSurface))),
          const SizedBox(height: 6),
          DefaultTextStyle.merge(style: const TextStyle(fontSize: 15, height: 1.5), child: child),
        ]),
      ),
    );
  }
}

class NumberedList extends StatelessWidget {
  final List<String> items;
  final bool bullets;
  const NumberedList({super.key, required this.items, this.bullets = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 22,
                child: Text(bullets ? '•' : '${i + 1}.',
                    style: AppTheme.numeric(15, color: AppTheme.accentOf(context), weight: FontWeight.w700)),
              ),
              Expanded(child: Text(items[i])),
            ]),
          ),
      ],
    );
  }
}

Future<void> openExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uri = Uri.tryParse(url);
  if (uri == null || !const {'https', 'http', 'tel', 'mailto'}.contains(uri.scheme)) return;
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  messenger?.showSnackBar(const SnackBar(content: Text('Couldn’t open the link')));
}

/// "Read original" links — one per source.
class SourceLinks extends StatelessWidget {
  final Story story;
  final bool detailed;
  const SourceLinks({super.key, required this.story, this.detailed = false});

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentOf(context);
    if (!detailed) {
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in story.sources)
          ActionChip(
            avatar: Icon(Icons.open_in_new_rounded, size: 16, color: accent),
            label: Text('Read original · ${s.name}'),
            tooltip: s.title.isEmpty ? s.url : s.title,
            onPressed: () => openExternal(context, s.url),
          ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final s in story.sources)
        InkWell(
          onTap: () => openExternal(context, s.url),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 3), child: Icon(Icons.open_in_new_rounded, size: 16, color: accent)),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: s.name, style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
                  if (s.title.isNotEmpty) TextSpan(text: ': ${s.title}', style: TextStyle(color: accent)),
                  TextSpan(text: '  ·  ${istTime(s.publishedAt)}', style: TextStyle(fontSize: 12.5, color: AppTheme.mutedOf(context))),
                ])),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// WhatsApp (first), system share, save.
class StoryActions extends StatelessWidget {
  final Story story;
  const StoryActions({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final scope = StoriesScope.of(context);
    const share = StoryShare();
    return ListenableBuilder(
      listenable: scope.saved,
      builder: (context, _) {
        final saved = scope.saved.isSaved(story.id);
        return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton.icon(
            key: ValueKey('wa-${story.id}'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: const Color(0xFF0B0B0F)),
            onPressed: () => share.whatsapp(context, story),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('WhatsApp'),
          ),
          Builder(
            builder: (ctx) => OutlinedButton.icon(
              onPressed: () => share.system(ctx, story),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Share'),
            ),
          ),
          IconButton(
            key: ValueKey('save-${story.id}'),
            tooltip: saved ? 'Remove from saved' : 'Save story',
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              final now = !scope.saved.isSaved(story.original.id);
              final done = scope.saved.toggle(story);
              messenger?.showSnackBar(SnackBar(
                content: Text(now
                    ? (scope.saved.isGuest ? 'Saved on this device' : 'Saved to your account')
                    : 'Removed from saved'),
                duration: const Duration(seconds: 2),
              ));
              await done;
            },
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: saved ? AppTheme.accentOf(context) : null),
          ),
          IconButton(
            tooltip: 'Copy link',
            onPressed: () => share.copyLink(context, story),
            icon: const Icon(Icons.link_rounded),
          ),
        ]);
      },
    );
  }
}

/// Feed/list card (search, saved): compact image card.
class StoryCard extends StatelessWidget {
  final Story story;
  const StoryCard({super.key, required this.story});

  @override
  Widget build(BuildContext context) => CompactStoryCard(story: story);
}

/// Newsletter sign-up form (Settings + footer of story pages).
class NewsletterSignup extends StatefulWidget {
  final String source;
  final String? initialEmail;
  const NewsletterSignup({super.key, required this.source, this.initialEmail});

  @override
  State<NewsletterSignup> createState() => _NewsletterSignupState();
}

class _NewsletterSignupState extends State<NewsletterSignup> {
  late final TextEditingController _c = TextEditingController(text: widget.initialEmail ?? '');
  String? _error;
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _c.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await StoriesScope.of(context).newsletter.signUp(email, source: widget.source);
      if (!mounted) return;
      setState(() => _done = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is NewsletterException ? e.message : 'Could not sign you up right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Get “Today in 5” by email', style: AppTheme.display(17, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text('The five stories that matter, in simple words. Free. Unsubscribe any time.',
            style: TextStyle(fontSize: 13.5, color: AppTheme.mutedOf(context))),
        const SizedBox(height: 10),
        if (_done)
          Row(children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.accentOf(context)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Thanks! You’re on the list.', key: ValueKey('newsletter-done'))),
          ])
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                key: const ValueKey('newsletter-email'),
                controller: _c,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(hintText: 'you@example.com', errorText: _error, isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('newsletter-submit'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Sign up'),
            ),
          ]),
      ]),
    );
  }
}
