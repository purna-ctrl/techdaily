import 'package:flutter/material.dart';

import '../../core/constants/story_categories.dart';
import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../widgets/story_widgets.dart' show TechDailyWordmark, FriendlyState;
import '../../widgets/v2/story_parts.dart';

/// Home: category tab bar (Top Stories first) with "Today in 5" on top.
class HomeFeedScreen extends StatefulWidget {
  /// Category id to open first (deep link `/app/c/<id>`).
  final String? initialCategory;
  const HomeFeedScreen({super.key, this.initialCategory});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with TickerProviderStateMixin {
  Future<StoryFeed>? _future;
  TabController? _tabs;
  List<StoryCategory> _tabCats = const [];

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

  void _syncTabs(List<StoryCategory> visible) {
    final cats = [kTopStories, ...visible];
    if (_tabs != null && _tabCats.length == cats.length && _tabCats.every((c) => cats.contains(c))) return;
    final prevId = _tabCats.isNotEmpty && _tabs != null ? _tabCats[_tabs!.index].id : widget.initialCategory;
    _tabs?.dispose();
    var initial = cats.indexWhere((c) => c.id == prevId);
    if (initial < 0) initial = 0;
    _tabCats = cats;
    _tabs = TabController(length: cats.length, vsync: this, initialIndex: initial);
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = StoriesScope.of(context);
    return ValueListenableBuilder<Set<String>>(
      valueListenable: scope.topics,
      builder: (context, hidden, _) {
        _syncTabs(scope.topics.visibleCategories);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: const TechDailyWordmark(size: 20),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.accentOf(context),
              indicatorColor: AppTheme.accentOf(context),
              tabs: [for (final c in _tabCats) Tab(text: c.label)],
            ),
          ),
          body: FutureBuilder<StoryFeed>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done && !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError && !snap.hasData) {
                return FriendlyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Couldn’t load stories',
                  message: 'Check your connection and try again.',
                  actionLabel: 'Try again',
                  onAction: _refresh,
                );
              }
              final feed = snap.data ?? StoryFeed.empty;
              return TabBarView(
                controller: _tabs,
                children: [
                  for (final c in _tabCats)
                    _StoryList(
                      key: PageStorageKey('tab-${c.id}'),
                      stories: c.id == kTopStories.id
                          ? feed.topStories().where((s) => !hidden.contains(s.category)).toList()
                          : feed.inCategory(c.id),
                      today: c.id == kTopStories.id ? feed.today.where((t) => !hidden.contains(t.category)).toList() : const [],
                      category: c,
                      onRefresh: _refresh,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _StoryList extends StatelessWidget {
  final List<Story> stories;
  final List<TodayItem> today;
  final StoryCategory category;
  final Future<void> Function() onRefresh;
  const _StoryList({super.key, required this.stories, required this.today, required this.category, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final header = today.isNotEmpty ? 1 : 0;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: stories.isEmpty
          ? ListView(children: [
              const SizedBox(height: 40),
              FriendlyState(
                icon: category.icon,
                title: 'No ${category.label} stories yet',
                message: 'New stories arrive every hour. Pull down to refresh.',
              ),
            ])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
              itemCount: stories.length + header,
              itemBuilder: (context, i) {
                final child = i < header ? TodayInFiveCard(items: today) : StoryCard(story: stories[i - header]);
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: child),
                  ),
                );
              },
            ),
    );
  }
}
