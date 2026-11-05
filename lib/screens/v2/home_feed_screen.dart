import 'package:flutter/material.dart';

import '../../core/constants/story_categories.dart';
import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../widgets/story_widgets.dart' show TechDailyWordmark, FriendlyState;
import '../../services/v2/story_translator.dart';
import '../../widgets/v3/language_widgets.dart';
import '../../widgets/v3/scam_widgets.dart';
import 'scam_check_screen.dart';
import '../../widgets/v3/story_cards.dart';
import '../../widgets/v3/story_rings.dart';
import '../../widgets/v3/ui.dart';
import 'reels_screen.dart';
import 'story_viewer_screen.dart';
import '../../l10n/app_language.dart' show tr;

/// Home: Today in 5 rings → pill category tabs → hero (#1) → Scam Radar →
/// Scam or Not? → per-category image rails → latest list. A category tab
/// shows that category's feature story and list.
class HomeFeedScreen extends StatefulWidget {
  /// Category id to open first (deep link `/app/c/<id>`).
  final String? initialCategory;
  const HomeFeedScreen({super.key, this.initialCategory});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  Future<StoryFeed>? _future;
  late String _tab = widget.initialCategory != null && isStoryCategoryId(widget.initialCategory!) ? widget.initialCategory! : kTopStories.id;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _parallax = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final o = _scroll.hasClients ? _scroll.offset : 0.0;
      if (o < 900) _parallax.value = (o * 0.18).clamp(-40, 90);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= StoriesScope.of(context).stories.loadFeed();
  }

  Future<void> _refresh() async {
    final f = StoriesScope.of(context).stories.loadFeed(refresh: true);
    setState(() => _future = f);
    await f.catchError((_) => StoryFeed.empty);
  }

  void _select(String id) {
    setState(() => _tab = id);
    if (_scroll.hasClients && _scroll.offset > 170) {
      _scroll.animateTo(170, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _parallax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = StoriesScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.topics, scope.translations]),
      builder: (context, _) {
        final hidden = scope.topics.value;
        final visible = scope.topics.visibleCategories;
        if (_tab != kTopStories.id && !visible.any((c) => c.id == _tab)) _tab = kTopStories.id;
        return Scaffold(
          backgroundColor: TD.bg,
          body: FutureBuilder<StoryFeed>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done && !snap.hasData) {
                return SafeArea(child: Column(children: [_header(context, const []), const Expanded(child: HomeSkeleton())]));
              }
              if (snap.hasError && !snap.hasData) {
                return SafeArea(
                  child: FriendlyState(
                    icon: Icons.wifi_off_rounded,
                    title: tr('Couldn’t load stories'),
                    message: tr('Check your connection and try again.'),
                    actionLabel: tr('Try again'),
                    onAction: _refresh,
                  ),
                );
              }
              final feed = snap.data ?? StoryFeed.empty;
              final top = feed.topStories().where((s) => !hidden.contains(s.category)).toList();
              return RefreshIndicator(
                onRefresh: _refresh,
                color: AppTheme.accentDark,
                edgeOffset: MediaQuery.paddingOf(context).top + 60,
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header(context, top))),
                    SliverToBoxAdapter(child: _rings(context, feed, hidden)),
                    SliverPersistentHeader(pinned: true, delegate: _PillBarDelegate(tabs: [kTopStories, ...visible], selected: _tab, onSelect: _select)),
                    ..._content(context, feed, top, visible),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, List<Story> reelStories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Row(children: [
        const TechDailyWordmark(size: 21),
        const Spacer(),
        const LanguageChip(),
        const SizedBox(width: 8),
        if (reelStories.isNotEmpty)
          FilledButton.icon(
            key: const ValueKey('open-reels'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0x1FFFFFFF),
              foregroundColor: TD.ink,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(side: BorderSide(color: TD.glassBorder)),
            ),
            onPressed: () => ReelsScreen.open(context, reelStories.take(40).toList()),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 18, color: Color(0xFFFF8255)),
            label: Text(tr('Reels')),
          ),
        IconButton(tooltip: tr('Refresh'), onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
      ]),
    );
  }

  Widget _rings(BuildContext context, StoryFeed feed, Set<String> hidden) {
    final scope = StoriesScope.of(context);
    final today = [
      for (final t in feed.today)
        if (!hidden.contains(t.category) && feed.bySlug(t.slug) != null) feed.bySlug(t.slug)!,
    ];
    final tx = scope.translations;
    final list = [for (final s in (today.isNotEmpty ? today : feed.topStories().where((s) => !hidden.contains(s.category)).take(5).toList())) tx.card(s)];
    return ListenableBuilder(
      listenable: scope.caughtUp,
      builder: (context, _) => StoryRings(
        stories: list,
        streak: scope.caughtUp.streak,
        caughtUp: scope.caughtUp.doneToday,
        onOpen: (i) => StoryViewerScreen.open(context, list, i),
      ),
    );
  }

  List<Widget> _content(BuildContext context, StoryFeed feed, List<Story> top, List<StoryCategory> visible) {
    if (top.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: FriendlyState(icon: Icons.newspaper_rounded, title: tr('No stories yet'), message: tr('New stories arrive every hour. Pull down to refresh.')),
          ),
        ),
      ];
    }
    if (_tab != kTopStories.id) return _categoryContent(context, feed, storyCategoryById(_tab));
    final tx = StoriesScope.of(context).translations;

    // Scam Radar: the newest scam story (when Scams & Security is visible); the
    // hero is the best-ranked story that isn't already on the radar.
    final scams = top.where((s) => s.isScam).toList()..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final scam = scams.isEmpty ? _noStory : scams.first;
    final hero = top.firstWhere((s) => s.id != scam.id, orElse: () => top.first);
    final rails = [
      for (final c in visible)
        if (feed.inCategory(c.id).isNotEmpty) (c, feed.inCategory(c.id).take(10).toList()),
    ];
    final shownInRails = {for (final r in rails) ...r.$2.map((s) => s.id)};
    final latest = top.where((s) => s.id != hero.id && s.id != scam.id && !shownInRails.contains(s.id)).take(20).toList();
    final latestAll = latest.isNotEmpty ? latest : top.skip(1).take(12).toList();

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: FadeSlideIn(
            child: ValueListenableBuilder<double>(
              valueListenable: _parallax,
              builder: (context, p, _) => HeroStoryCard(story: tx.card(hero), parallax: p, onTap: () => openStory(context, hero)),
            ),
          ),
        ),
      ),
      if (tx.lang != 'en' && tx.hasRecentFailure)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(alignment: Alignment.centerLeft, child: TranslationNote(status: TrStatus.failed, onRetry: () => setState(() {}))),
          ),
        ),
      if (!identical(scam, _noStory)) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 22)),
        SliverToBoxAdapter(child: FadeSlideIn(index: 1, child: ScamRadarCard(story: tx.card(scam)))),
      ] else ...[
        const SliverToBoxAdapter(child: SizedBox(height: 22)),
        const SliverToBoxAdapter(child: ScamCheckEntryCard()),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 18)),
      SliverToBoxAdapter(child: FadeSlideIn(index: 2, child: ScamOrNotCard(stories: feed.stories))),
      for (final (c, list) in rails) ...[
        SliverToBoxAdapter(
          child: SectionTitle(c.label, icon: c.icon, color: c.tint, action: tr('See all'), onAction: () => _select(c.id)),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 336,
            child: ListView.separated(
              key: PageStorageKey('rail-${c.id}'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => RailCard(story: tx.card(list[i]), onTap: () => openStory(context, list[i])),
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(child: SectionTitle(tr('Latest'), icon: Icons.bolt_rounded, color: const Color(0xFFFF8255))),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverList.builder(
          itemCount: latestAll.length,
          itemBuilder: (context, i) => _constrain(FadeSlideIn(index: i, child: CompactStoryCard(story: tx.card(latestAll[i])))),
        ),
      ),
    ];
  }

  List<Widget> _categoryContent(BuildContext context, StoryFeed feed, StoryCategory c) {
    final list = feed.inCategory(c.id);
    final tx = StoriesScope.of(context).translations;
    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: FriendlyState(icon: c.icon, title: '${c.label}: ${tr('No stories yet')}', message: tr('New stories arrive every hour. Pull down to refresh.')),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 14),
          child: ValueListenableBuilder<double>(
            valueListenable: _parallax,
            builder: (context, p, _) => HeroStoryCard(story: tx.card(list.first), parallax: p, onTap: () => openStory(context, list.first)),
          ),
        ),
      ),
      if (c.id == 'scams-security') ...[
        const SliverToBoxAdapter(child: ScamCheckEntryCard()),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        SliverToBoxAdapter(child: ScamOrNotCard(stories: feed.stories)),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
      ],
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverList.builder(
          itemCount: list.length - 1,
          itemBuilder: (context, i) => _constrain(FadeSlideIn(index: i, child: CompactStoryCard(story: tx.card(list[i + 1])))),
        ),
      ),
    ];
  }

  static Widget _constrain(Widget child) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: child));
}

final Story _noStory = Story(
  id: '',
  slug: '',
  headline: '',
  category: 'innovations',
  publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  sources: const [],
  whatHappened: '',
  affectsWho: '',
  whatToDo: const [],
  whatItMeans: '',
);

/// Pinned pill tab bar, each pill in its category colour.
class _PillBarDelegate extends SliverPersistentHeaderDelegate {
  final List<StoryCategory> tabs;
  final String selected;
  final void Function(String id) onSelect;
  _PillBarDelegate({required this.tabs, required this.selected, required this.onSelect});

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: TD.bg.withValues(alpha: 0.94),
        border: Border(bottom: BorderSide(color: overlapsContent || shrinkOffset > 0 ? TD.glassBorder : Colors.transparent)),
      ),
      // All pills are built (only 9), so every tab is reachable by keyboard and tests.
      child: SingleChildScrollView(
        key: const PageStorageKey('pill-tabs'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          for (final c in tabs) _pill(c),
        ]),
      ),
    );
  }

  Widget _pill(StoryCategory c) {
    final on = c.id == selected;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: on,
        button: true,
        child: AnimatedContainer(
          key: ValueKey('tab-${c.id}'),
          duration: const Duration(milliseconds: 220),
          height: 40,
          decoration: BoxDecoration(
            color: on ? c.color : const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? c.color : TD.glassBorder),
            boxShadow: on ? [BoxShadow(color: c.color.withValues(alpha: 0.45), blurRadius: 16)] : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onSelect(c.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(c.icon, size: 16, color: on ? TD.bg : c.tint),
                  const SizedBox(width: 6),
                  Text(c.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: on ? TD.bg : TD.ink)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_PillBarDelegate old) => old.selected != selected || old.tabs.length != tabs.length || !old.tabs.every(tabs.contains);
}
