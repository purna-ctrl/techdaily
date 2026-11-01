import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_scope.dart';
import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../models/user_preferences.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/article_ranking_service.dart';
import '../services/daily_brief_service.dart';
import '../services/home_feed_service.dart';
import '../services/offline_cache_service.dart';
import '../widgets/skeleton.dart';
import '../widgets/story_widgets.dart';
import 'article_screen.dart';
import 'category_screen.dart';
import 'daily_brief_screen.dart';
import 'profile_screen.dart';

/// Magazine-style home: lead story, breaking strip, trending rail, daily brief,
/// India, things to know and category sections — every story appears once.
class HomeScreen extends StatefulWidget {
  final ArticleRepository repository;
  final AuthRepository? authRepository;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final IArticleRankingService? rankingService;
  final OfflineCacheService? cacheService;
  final DailyBriefService? briefService;

  const HomeScreen({
    super.key,
    required this.repository,
    this.authRepository,
    required this.themeModeNotifier,
    this.rankingService,
    this.cacheService,
    this.briefService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeFeedComposer _composer;
  late final OfflineCacheService _cacheService;
  late final DailyBriefService _briefService;

  HomeFeed _feed = HomeFeed.empty;
  UserPreferences _prefs = UserPreferences.defaultPreferences();
  bool _isLoading = true;
  bool _isOffline = false;
  bool _hasError = false;
  String _filter = 'All';

  static const String _indiaFilter = 'India';

  @override
  void initState() {
    super.initState();
    _composer = HomeFeedComposer(rankingService: widget.rankingService);
    _cacheService = widget.cacheService ?? OfflineCacheService();
    _briefService = widget.briefService ?? DailyBriefService();
    _loadNews();
  }

  Future<void> _loadNews() async {
    if (_feed.isEmpty) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      _prefs = await _cacheService.getCachedPreferences();
      final all = await widget.repository.getArticles();
      if (all.isNotEmpty) await _cacheService.cacheArticles(all);
      _apply(all, offline: false);
    } catch (e) {
      debugPrint('Home feed load failed: $e');
      final cached = await _cacheService.getCachedArticles();
      if (cached.isNotEmpty) {
        _apply(cached, offline: true);
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _isOffline = true;
        });
      }
    }
  }

  void _apply(List<Article> all, {required bool offline}) {
    if (!mounted) return;
    setState(() {
      _feed = _composer.compose(all, userInterests: _prefs.selectedCategories);
      _isLoading = false;
      _hasError = false;
      _isOffline = offline;
      if (_filter == _indiaFilter && !_feed.all.any((a) => a.isIndia)) _filter = 'All';
    });
  }

  void _open(Article a) {
    if (AppScope.maybeOf(context) != null) {
      openArticle(context, a);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArticleScreen(
          article: a,
          repository: widget.repository,
          authRepository: widget.authRepository,
        ),
      ));
    }
  }

  void _openBrief() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DailyBriefScreen(
        repository: widget.repository,
        authRepository: widget.authRepository,
        briefService: _briefService,
      ),
    ));
  }

  void _openCategory(String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CategoryScreen(
        repository: widget.repository,
        authRepository: widget.authRepository,
        initialCategory: name,
      ),
    ));
  }

  Future<void> _openProfile() async {
    if (widget.authRepository == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfileScreen(
        authRepository: widget.authRepository!,
        themeModeNotifier: widget.themeModeNotifier,
        articleRepository: widget.repository,
      ),
    ));
    _loadNews();
  }

  List<String> get _chips {
    final present = _feed.all.map((a) => a.category).toSet();
    final ordered = HomeFeedComposer.categoryOrder
        .expand((e) => e.$2)
        .where(present.contains)
        .toList();
    return [
      'All',
      if (_feed.all.any((a) => a.isIndia)) _indiaFilter,
      ...ordered,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final dark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          const TechDailyWordmark(size: 22),
          const Spacer(),
          IconButton(
            tooltip: dark ? 'Light mode' : 'Dark mode',
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () =>
                widget.themeModeNotifier.value = dark ? ThemeMode.light : ThemeMode.dark,
          ),
          if (widget.authRepository != null)
            IconButton(
              tooltip: 'Profile & settings',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: _openProfile,
            ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) return const HomeSkeleton();

    if (_feed.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNews,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: c.maxHeight,
              child: _hasError
                  ? FriendlyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Can’t reach the newsroom',
                      message: 'Check your connection and try again. Stories you’ve opened before will show here when you’re offline.',
                      actionLabel: 'Try again',
                      onAction: _loadNews,
                    )
                  : FriendlyState(
                      icon: Icons.coffee_rounded,
                      title: 'Fresh stories are on the way',
                      message: 'Our newsroom updates through the day. Pull down or tap below to check for new stories.',
                      actionLabel: 'Refresh',
                      onAction: _loadNews,
                    ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNews,
      color: AppTheme.accentOf(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildDateLine(theme)),
          SliverToBoxAdapter(child: _buildChips()),
          if (_isOffline) SliverToBoxAdapter(child: _buildOfflineBanner(theme)),
          if (_filter == 'All')
            ..._buildMagazine(theme)
          else
            ..._buildFiltered(theme),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _constrained(Widget child, {EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16)}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SizedBox(
          width: double.infinity,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _buildDateLine(ThemeData theme) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return _constrained(
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEEE, d MMMM').format(now), style: AppTheme.kicker(color: AppTheme.mutedOf(context), size: 12)),
            const SizedBox(height: 4),
            Text(greeting, style: AppTheme.display(30, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildChips() {
    final chips = _chips;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = chips[i];
          final selected = label == _filter;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => setState(() => _filter = label),
          );
        },
      ),
    );
  }

  Widget _buildOfflineBanner(ThemeData theme) {
    return _constrained(
      Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('You’re offline — showing saved stories', style: theme.textTheme.bodySmall)),
          TextButton(onPressed: _loadNews, child: const Text('Retry')),
        ]),
      ),
    );
  }

  List<Widget> _buildMagazine(ThemeData theme) {
    final f = _feed;
    final out = <Widget>[];

    void add(Widget w, {double top = 28}) {
      out.add(SliverToBoxAdapter(child: _FadeIn(child: Padding(padding: EdgeInsets.only(top: top), child: w))));
    }

    if (f.lead != null) {
      add(_constrained(LeadStoryCard(article: f.lead!, onTap: () => _open(f.lead!))), top: 12);
    }

    if (f.breaking.isNotEmpty) {
      add(_constrained(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'Breaking',
            leading: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: AppTheme.live, shape: BoxShape.circle),
            ),
          ),
          ...f.breaking.map((a) => CompactStoryTile(article: a, onTap: () => _open(a))),
        ],
      )));
    }

    if (f.trending.isNotEmpty) {
      add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _constrained(const SectionTitle(title: 'Trending')),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: TrendingRail(articles: f.trending, onTap: _open),
            ),
          ),
        ],
      ));
    }

    add(_constrained(DailyBriefCard(
      storyCount: f.all.length < 10 ? f.all.length : 10,
      onTap: _openBrief,
    )));

    if (f.india.isNotEmpty) {
      add(_constrained(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'India',
            actionLabel: 'More',
            onAction: () => setState(() => _filter = _indiaFilter),
          ),
          ImageStoryCard(article: f.india.first, onTap: () => _open(f.india.first)),
          const SizedBox(height: 8),
          ...f.india.skip(1).map((a) => CompactStoryTile(article: a, onTap: () => _open(a))),
        ],
      )));
    }

    if (f.thingsToKnow.isNotEmpty) {
      add(_constrained(_ThingsToKnowCard(articles: f.thingsToKnow, onTap: _open)));
    }

    for (final section in f.sections) {
      add(_constrained(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: section.title,
            actionLabel: 'See all',
            onAction: () => _openCategory(section.categoryName),
          ),
          ImageStoryCard(article: section.articles.first, onTap: () => _open(section.articles.first)),
          const SizedBox(height: 8),
          ...section.articles.skip(1).map((a) => CompactStoryTile(article: a, onTap: () => _open(a))),
        ],
      )));
    }

    add(_constrained(Column(
      children: [
        Divider(color: AppTheme.borderOf(context)),
        const SizedBox(height: 8),
        Text(
          'Summaries link to their original sources. Tap “Read original” on any story.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    )));
    return out;
  }

  List<Widget> _buildFiltered(ThemeData theme) {
    final items = _filter == _indiaFilter
        ? _feed.all.where((a) => a.isIndia).toList()
        : _feed.all.where((a) => a.category.toLowerCase() == _filter.toLowerCase()).toList();
    if (items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: FriendlyState(
              icon: Icons.inbox_outlined,
              title: 'Nothing here yet',
              message: 'No $_filter stories right now. Check back soon.',
            ),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: _constrained(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ImageStoryCard(article: items.first, onTap: () => _open(items.first)),
          ),
        ),
      ),
      SliverList.builder(
        itemCount: items.length - 1,
        itemBuilder: (context, i) {
          final a = items[i + 1];
          return _constrained(CompactStoryTile(article: a, onTap: () => _open(a)));
        },
      ),
    ];
  }
}

class _ThingsToKnowCard extends StatelessWidget {
  final List<Article> articles;
  final ValueChanged<Article> onTap;
  const _ThingsToKnowCard({required this.articles, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.accentOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Things you should know'),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < articles.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppTheme.borderOf(context), indent: 16, endIndent: 16),
                InkWell(
                  onTap: () => onTap(articles[i]),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${i + 1}',
                            style: AppTheme.numeric(24, family: AppTheme.displayFont, color: accent).copyWith(height: 1.05),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                articles[i].title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.display(16, color: theme.colorScheme.onSurface, height: 1.22),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                articles[i].simpleExplanation.isNotEmpty
                                    ? articles[i].simpleExplanation
                                    : articles[i].summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One-shot fade + slight rise when a section first appears.
class _FadeIn extends StatelessWidget {
  final Widget child;
  const _FadeIn({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
    );
  }
}
