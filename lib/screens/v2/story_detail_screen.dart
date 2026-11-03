import 'package:flutter/material.dart';

import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../widgets/story_widgets.dart' show FriendlyState;
import '../../services/v2/story_share.dart';
import '../../widgets/v2/story_parts.dart';
import '../../widgets/v3/jargon.dart';
import '../../widgets/v3/story_image.dart';
import '../../widgets/v3/story_sections.dart';
import '../../widgets/v3/ui.dart';
import '../../core/constants/jargon.dart';

/// Full story, image-led: parallax hero with credit, card sections with
/// tap-to-explain jargon, animated "What to do" checklist, the scam template,
/// sources, newsletter, and the action bar (WhatsApp first · Save · Listen ·
/// Sources).
class StoryDetailScreen extends StatelessWidget {
  final Story story;
  const StoryDetailScreen({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final s = story;
    final cat = s.categoryInfo;
    final pad = MediaQuery.paddingOf(context);
    final words = jargonIn([s.whatHappened, s.affectsWho, s.whatItMeans, ...s.whatToDo, if (s.scam != null) s.scam!.howItWorks]);
    Widget constrained(Widget child) => Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child)),
        );
    return Scaffold(
      backgroundColor: TD.bg,
      body: Stack(children: [
        // Category glow behind the page
        Positioned(
          top: -120,
          right: -80,
          child: IgnorePointer(
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [cat.color.withValues(alpha: 0.22), Colors.transparent])),
            ),
          ),
        ),
        CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 470,
            backgroundColor: TD.bg,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton(
                tooltip: 'Back',
                style: IconButton.styleFrom(backgroundColor: const Color(0x990B0B0F)),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.canPop() ? nav.pop() : nav.pushReplacementNamed('/');
                },
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Copy link',
                  style: IconButton.styleFrom(backgroundColor: const Color(0x990B0B0F)),
                  onPressed: () => const StoryShare().copyLink(context, s),
                  icon: const Icon(Icons.link_rounded, color: Colors.white),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(fit: StackFit.expand, children: [
                ScrimmedImage(story: s, showCredit: false),
                if (s.image != null) Positioned(top: pad.top + 64, right: 12, child: ImageCredit(story: s)),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 728),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          CategoryChip(category: cat, glow: true),
                          if (s.developing) const DevelopingPill(),
                          if (s.isScam)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: TD.red, borderRadius: BorderRadius.circular(999)),
                              child: Text('SCAM ALERT', style: AppTheme.kicker(size: 11, color: TD.bg).copyWith(fontWeight: FontWeight.w900)),
                            ),
                        ]),
                        const SizedBox(height: 10),
                        Semantics(
                          header: true,
                          child: Text(s.headline,
                              maxLines: 6, overflow: TextOverflow.ellipsis, style: AppTheme.display(30, color: Colors.white, height: 1.1)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${istTime(s.publishedAt)} · ${s.sourceNames.length > 1 ? '${s.sourceNames.length} sources: ' : ''}${s.sourceNames.join(', ')}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFFD2CEC6), height: 1.35),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: constrained(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              FadeSlideIn(
                child: SectionCard(title: 'What happened', icon: Icons.newspaper_rounded, color: cat.color, child: JargonText(s.whatHappened, accent: cat.tint)),
              ),
              FadeSlideIn(
                index: 1,
                child: SectionCard(title: 'Does it affect me?', icon: Icons.person_search_rounded, color: cat.color, child: JargonText(s.affectsWho, accent: cat.tint)),
              ),
              if (s.scam != null) ScamSections(scam: s.scam!),
              SectionCard(title: 'What to do', icon: Icons.task_alt_rounded, color: cat.color, child: TickChecklist(items: s.whatToDo, color: cat.tint)),
              SectionCard(
                title: 'What this means for you',
                icon: Icons.lightbulb_rounded,
                color: cat.color,
                highlight: true,
                child: JargonText(s.whatItMeans, accent: cat.tint, style: const TextStyle(fontSize: 17.5, height: 1.5)),
              ),
              if (words.isNotEmpty) ...[
                const SizedBox(height: 18),
                JargonChips(entries: words, accent: cat.tint),
              ],
              SectionCard(
                title: s.sources.length > 1 ? 'Read the originals' : 'Read the original',
                icon: Icons.link_rounded,
                color: cat.color,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SourceLinks(story: s, detailed: true),
                  const SizedBox(height: 6),
                  Text(
                    '${s.isFallback ? 'Short version written automatically from the report headline. An AI-written simple version will follow.' : 'Written in simple words by AI from the reports above. Always check the original before acting on money or security advice.'}${s.image != null ? ' Image: ${s.image!.sourceName}, linked from the original report.' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: TD.muted, height: 1.45),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              const NewsletterSignup(source: 'app-story'),
              const SizedBox(height: 120),
            ])),
          ),
        ]),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: StoryActionBar(story: s)),
              ),
            ),
          ),
        ),
      ]),
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
