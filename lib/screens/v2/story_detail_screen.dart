import 'package:flutter/material.dart';

import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../services/v2/story_translator.dart';
import '../../widgets/story_widgets.dart' show FriendlyState;
import '../../services/v2/story_share.dart';
import '../../widgets/v2/story_parts.dart';
import '../../widgets/v3/jargon.dart';
import '../../widgets/v3/language_widgets.dart' show TranslationNote;
import '../../widgets/v3/story_image.dart';
import '../../widgets/v3/story_questions.dart';
import '../../widgets/v3/story_sections.dart';
import '../../widgets/v3/ui.dart';
import '../../core/constants/jargon.dart';
import '../../l10n/app_language.dart' show tr;

/// Full story, image-led: parallax hero with credit, card sections with
/// tap-to-explain jargon, animated "What to do" checklist, the scam template,
/// sources, newsletter, and the action bar (WhatsApp first · Save · Listen ·
/// Sources).
class StoryDetailScreen extends StatelessWidget {
  final Story story;
  const StoryDetailScreen({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final tx = StoriesScope.of(context).translations;
    return ListenableBuilder(listenable: tx, builder: (context, _) => _page(context, tx.full(story), tx));
  }

  Widget _page(BuildContext context, Story s, StoryTranslator tx) {
    final cat = s.categoryInfo;
    final pad = MediaQuery.paddingOf(context);
    final d = s.display;
    // Worked out only when the jargon chips scroll into view (and once per story).
    List<JargonEntry> words() => _words[s] ??=
        jargonIn([d.tldr, d.whatHappened, d.affectsWho, d.whatItMeans, ...d.whatToDo, d.goodToKnow, if (s.scam != null) s.scam!.howItWorks]);
    final sections = storySections(s);
    // Room below the content for the floating action bar (~68 px) + its margin + the safe area.
    final bottomRoom = 68 + 10 + pad.bottom + 28;
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
                tooltip: tr('Back'),
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
                  tooltip: tr('Copy link'),
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
                              child: Text(tr('SCAM ALERT'), style: AppTheme.kicker(size: 11, color: TD.bg).copyWith(fontWeight: FontWeight.w900)),
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
          // Lazy list: only the sections on screen are laid out on the first
          // frame, so the page appears at once and the rest builds as you scroll.
          SliverList(
            delegate: SliverChildListDelegate([
              if (tx.lang != 'en')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TranslationNote(status: tx.fullStatus(story), onRetry: () => tx.retry(story)),
                ),
              StoryTopBlock(story: s),
              const SizedBox(height: 4),
              for (var i = 0; i < sections.length; i++)
                FadeSlideIn(
                  index: i < 2 ? i : 2,
                  child: SectionCard(
                    title: sections[i].title,
                    icon: sections[i].icon,
                    color: sections[i].scam ? TD.red : cat.color,
                    scam: sections[i].scam,
                    highlight: sections[i].highlight,
                    child: sections[i].body,
                  ),
                ),
              SectionCard(
                title: tr('Ask about this'),
                icon: Icons.forum_rounded,
                color: cat.color,
                child: AskAboutThis(story: s, onOpenSources: () => showSourcesSheet(context, s)),
              ),
              Builder(builder: (context) {
                final w = words();
                return w.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(padding: const EdgeInsets.only(top: 18), child: JargonChips(entries: w, accent: cat.tint));
              }),
              SectionCard(
                title: s.sources.length > 1 ? tr('Read the originals') : tr('Read the original'),
                icon: Icons.link_rounded,
                color: cat.color,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SourceLinks(story: s, detailed: true),
                  const SizedBox(height: 6),
                  Text(
                    '${s.isFallback ? 'A simplified summary of the reports above — a fuller explanation is on its way.' : 'Written in simple words by AI from the reports above. Always check the original before acting on money or security advice.'}${s.image != null ? ' Image: ${s.image!.sourceName}, linked from the original report.' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: TD.muted, height: 1.45),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              const NewsletterSignup(source: 'app-story'),
              SizedBox(height: bottomRoom),
            ].map((w) => w is SizedBox ? constrained(w) : constrained(Align(alignment: Alignment.centerLeft, child: w))).toList()),
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

  static final Expando<List<JargonEntry>> _words = Expando('storyJargon');
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
  Story? _cached;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initial != null || _future != null) return;
    final repo = StoriesScope.of(context).stories;
    _cached = repo.cachedBySlug(widget.slug);
    if (_cached == null) _future = repo.getBySlug(widget.slug);
  }

  @override
  Widget build(BuildContext context) {
    // From the feed (or an already-loaded feed) the story is on screen in the
    // very first frame; only cold deep links wait for the network.
    final ready = widget.initial ?? _cached;
    if (ready != null) return StoryDetailScreen(story: ready);
    return FutureBuilder<Story?>(
      future: _future,
      builder: (context, snap) {
        if (snap.data != null) return StoryDetailScreen(story: snap.data!);
        final loading = snap.connectionState != ConnectionState.done;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: tr('Home'),
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
                  title: snap.hasError ? tr('Couldn’t load this story') : tr('Story not found'),
                  message: snap.hasError ? 'Check your connection and try again.' : 'It may be too old. Here’s what’s new instead.',
                  actionLabel: snap.hasError ? tr('Try again') : tr('Go to home'),
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
