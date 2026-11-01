import 'package:flutter/material.dart';

import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../widgets/story_widgets.dart' show FriendlyState;
import '../../widgets/v2/story_parts.dart';

/// Full story: card sections, scam template, sources, share/save, newsletter.
class StoryDetailScreen extends StatelessWidget {
  final Story story;
  const StoryDetailScreen({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = story;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            final nav = Navigator.of(context);
            nav.canPop() ? nav.pop() : nav.pushReplacementNamed('/');
          },
        ),
        title: Text(storyCategoryLabel(s), style: AppTheme.display(17, color: theme.colorScheme.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CategoryArt(categoryId: s.category, height: 84),
                  const SizedBox(height: 14),
                  StoryMeta(story: s, absoluteTime: true),
                  const SizedBox(height: 8),
                  Semantics(
                    header: true,
                    child: Text(s.headline, style: AppTheme.display(27, color: theme.colorScheme.onSurface, height: 1.15)),
                  ),
                  const SizedBox(height: 4),
                  SectionBlock(title: 'What happened', child: Text(s.whatHappened)),
                  SectionBlock(title: 'Does it affect me?', child: Text(s.affectsWho)),
                  if (s.scam != null) ...[
                    SectionBlock(title: 'How the trick works', warning: true, child: Text(s.scam!.howItWorks)),
                    SectionBlock(title: 'Warning signs', warning: true, child: NumberedList(items: s.scam!.warningSigns, bullets: true)),
                    SectionBlock(
                      title: 'What to do if you’re targeted',
                      warning: true,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        NumberedList(items: s.scam!.ifTargeted),
                        const SizedBox(height: 8),
                        Text('India: call the cyber-crime helpline 1930 or report at cybercrime.gov.in.',
                            style: TextStyle(fontSize: 13.5, color: AppTheme.mutedOf(context))),
                        Wrap(spacing: 8, children: [
                          TextButton(
                            onPressed: () => openExternal(context, 'https://cybercrime.gov.in'),
                            child: const Text('cybercrime.gov.in'),
                          ),
                          if (s.scam!.advisoryUrl != null)
                            OutlinedButton.icon(
                              onPressed: () => openExternal(context, s.scam!.advisoryUrl!),
                              icon: const Icon(Icons.verified_user_rounded, size: 18),
                              label: const Text('Official advisory'),
                            ),
                        ]),
                      ]),
                    ),
                  ],
                  SectionBlock(title: 'What to do', child: NumberedList(items: s.whatToDo)),
                  SectionBlock(title: 'What this means for you', highlight: true, child: Text(s.whatItMeans)),
                  SectionBlock(
                    title: s.sources.length > 1 ? 'Read the originals' : 'Read the original',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SourceLinks(story: s, detailed: true),
                      const SizedBox(height: 6),
                      Text(
                        s.isFallback
                            ? 'Short version written automatically from the report headline. An AI-written simple version will follow.'
                            : 'Written in simple words by AI from the reports above. Always check the original before acting on money or security advice.',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.mutedOf(context)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Text('Share this story', style: AppTheme.display(16, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  StoryActions(story: s),
                  const SizedBox(height: 22),
                  const NewsletterSignup(source: 'app-story'),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String storyCategoryLabel(Story s) => s.categoryInfo.label;
}

/// Loads a story by slug for deep links (`/app/story/<slug>`, `/story/<slug>`).
class StoryRouteScreen extends StatefulWidget {
  final String slug;
  final Story? initial;
  const StoryRouteScreen({super.key, required this.slug, this.initial});

  @override
  State<StoryRouteScreen> createState() => _StoryRouteScreenState();
}

class _StoryRouteScreenState extends State<StoryRouteScreen> {
  Future<Story?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= widget.initial != null ? Future.value(widget.initial) : StoriesScope.of(context).stories.getBySlug(widget.slug);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Story?>(
      future: _future,
      builder: (context, snap) {
        if (snap.data != null) return StoryDetailScreen(story: snap.data!);
        final loading = snap.connectionState != ConnectionState.done;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Home',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                final nav = Navigator.of(context);
                nav.canPop() ? nav.pop() : nav.pushReplacementNamed('/');
              },
            ),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : FriendlyState(
                  icon: snap.hasError ? Icons.wifi_off_rounded : Icons.article_outlined,
                  title: snap.hasError ? 'Couldn’t load this story' : 'Story not found',
                  message: snap.hasError ? 'Check your connection and try again.' : 'It may be too old. Here’s what’s new instead.',
                  actionLabel: snap.hasError ? 'Try again' : 'Go to home',
                  actionIcon: snap.hasError ? Icons.refresh_rounded : Icons.home_rounded,
                  onAction: snap.hasError
                      ? () => setState(() => _future = StoriesScope.of(context).stories.getBySlug(widget.slug))
                      : () => Navigator.of(context).pushReplacementNamed('/'),
                ),
        );
      },
    );
  }
}
