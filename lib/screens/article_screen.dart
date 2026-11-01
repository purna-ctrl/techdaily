import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../models/user_preferences.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/offline_cache_service.dart';
import '../services/reading_history_service.dart';
import '../services/share_service.dart';
import '../services/story_timeline_service.dart';
import '../widgets/article_image.dart';
import '../widgets/ask_ai_section.dart';
import '../widgets/listen_article_bar.dart';
import '../widgets/story_timeline_section.dart';
import '../widgets/story_widgets.dart';
import 'compare_stories_screen.dart';

/// Opens the exact original article URL in the external browser/app.
/// Returns false when the URL is missing/invalid or can't be launched.
Future<bool> launchOriginalArticle(String sourceUrl) async {
  final uri = Uri.tryParse(sourceUrl.trim());
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  } catch (_) {
    return false;
  }
}

/// Language options for the "In simple words" toggle.
class SimpleWordsLanguage {
  final String code;
  final String label;
  const SimpleWordsLanguage(this.code, this.label);

  static const all = [
    SimpleWordsLanguage('en', 'EN'),
    SimpleWordsLanguage('te', 'తెలుగు'),
    SimpleWordsLanguage('ta', 'தமிழ்'),
    SimpleWordsLanguage('hi', 'हिंदी'),
  ];

  /// Languages available for [article]: English plus any translations present.
  static List<SimpleWordsLanguage> availableFor(Article article) => [
        all.first,
        ...all.skip(1).where(
            (l) => (article.simpleExplanationTranslations[l.code] ?? '').trim().isNotEmpty),
      ];
}

class ArticleScreen extends StatefulWidget {
  final Article article;
  final ArticleRepository repository;
  final AuthRepository? authRepository;

  const ArticleScreen({
    super.key,
    required this.article,
    required this.repository,
    this.authRepository,
  });

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  final ReadingHistoryService _historyService = ReadingHistoryService();
  final StoryTimelineService _timelineService = StoryTimelineService();
  final OfflineCacheService _cacheService = OfflineCacheService();

  List<TimelineEntry> _timeline = [];
  List<Article> _allArticles = [];
  UserPreferences _preferences = UserPreferences.defaultPreferences();
  bool _isFollowingCategory = false;
  String _language = 'en';

  Article get article => widget.article;

  @override
  void initState() {
    super.initState();
    _historyService.recordRead(article);
    _loadContextData();
  }

  Future<void> _loadContextData() async {
    try {
      final prefs = await _cacheService.getCachedPreferences();
      final articles = await widget.repository.getArticles();
      final timeline = _timelineService.getTimeline(article, articles);
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
        _allArticles = articles;
        _timeline = timeline;
        _isFollowingCategory = prefs.selectedCategories
            .any((c) => c.toLowerCase() == article.category.toLowerCase());
      });
    } catch (_) {}
  }

  Future<void> _toggleFollowCategory() async {
    final updatedList = List<String>.from(_preferences.selectedCategories);
    if (_isFollowingCategory) {
      updatedList.removeWhere((c) => c.toLowerCase() == article.category.toLowerCase());
    } else {
      updatedList.add(article.category);
    }
    final updated = _preferences.copyWith(selectedCategories: updatedList, updatedAt: DateTime.now());
    await _cacheService.cachePreferences(updated);
    if (!mounted) return;
    setState(() {
      _preferences = updated;
      _isFollowingCategory = !_isFollowingCategory;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isFollowingCategory
          ? 'Following ${article.category}'
          : 'Unfollowed ${article.category}'),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _toggleSave() async {
    final user = widget.authRepository?.currentUser;
    final nowSaved = await widget.repository.toggleSaveArticle(user?.uid ?? '', article.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(nowSaved
          ? (user == null ? 'Saved on this device — sign in to sync' : 'Saved')
          : 'Removed from saved'),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openOriginal() async {
    final ok = await launchOriginalArticle(article.sourceUrl);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open the original article.')),
      );
    }
  }

  void _showComparePicker() {
    final others = _allArticles.where((a) => a.id != article.id).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other stories to compare yet.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Compare with…', style: AppTheme.display(20, color: Theme.of(ctx).colorScheme.onSurface)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: others.length,
                itemBuilder: (_, i) {
                  final other = others[i];
                  return ListTile(
                    title: Text(other.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${other.sourceName} · ${other.category}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.compare_arrows_rounded),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CompareStoriesScreen(
                          articleA: article,
                          articleB: other,
                          repository: widget.repository,
                          authRepository: widget.authRepository,
                        ),
                      ));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final heroHeight = (width < 600 ? width * 0.78 : 420.0).clamp(240.0, 460.0);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: heroHeight,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: _CircleButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () {
                  final nav = Navigator.of(context);
                  if (nav.canPop()) {
                    nav.pop();
                  } else {
                    nav.pushReplacementNamed('/');
                  }
                },
              ),
            ),
            actions: [
              ValueListenableBuilder<Set<String>>(
                valueListenable: widget.repository.savedArticleIdsNotifier,
                builder: (context, saved, _) {
                  final isSaved = saved.contains(article.id);
                  return _CircleButton(
                    icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    tooltip: isSaved ? 'Remove from saved' : 'Save',
                    color: isSaved ? AppTheme.accent : null,
                    onPressed: _toggleSave,
                  );
                },
              ),
              const SizedBox(width: 6),
              Builder(
                builder: (btnContext) => _CircleButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Share',
                  onPressed: () => const ShareService().shareArticle(btnContext, article),
                ),
              ),
              const SizedBox(width: 6),
              _CircleButton(
                icon: Icons.compare_arrows_rounded,
                tooltip: 'Compare with another story',
                onPressed: _showComparePicker,
              ),
              const SizedBox(width: 10),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Hero(
                tag: 'article-image-${article.id}',
                child: ArticleImage(article: article, iconSize: 64),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppConstants.maxArticleWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: _buildBody(context, theme),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ListenArticleBar(article: article),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    final accent = AppTheme.accentOf(context);
    final domain = article.sourceDomain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (article.isBreaking) const BreakingTag(),
            CategoryTag(category: article.category),
            if (article.isIndia)
              const _PlainTag(label: 'India'),
            InkWell(
              onTap: _toggleFollowCategory,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_isFollowingCategory ? Icons.check_rounded : Icons.add_rounded, size: 16, color: accent),
                  const SizedBox(width: 4),
                  Text(_isFollowingCategory ? 'Following' : 'Follow',
                      style: AppTheme.kicker(color: accent, size: 12)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(article.title, style: AppTheme.display(30, color: theme.colorScheme.onSurface, height: 1.1)),
        const SizedBox(height: 12),
        StoryMeta(article: article, showReadTime: true),
        if (article.summary.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(article.summary, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: 22),
        _buildSimpleWordsCard(context, theme),
        if (article.whatHappened.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionLabel(label: 'What happened'),
          const SizedBox(height: 8),
          Text(article.whatHappened, style: theme.textTheme.bodyLarge),
        ],
        if (article.whyItMatters.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionLabel(label: 'Why it matters'),
          const SizedBox(height: 8),
          Text(article.whyItMatters, style: theme.textTheme.bodyLarge),
        ],
        if (article.keyPoints.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionLabel(label: 'Key points'),
          const SizedBox(height: 10),
          ...article.keyPoints.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 9, right: 12),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                    ),
                    Expanded(child: Text(p, style: theme.textTheme.bodyLarge)),
                  ],
                ),
              )),
        ],
        const SizedBox(height: 28),
        _buildSourceCard(context, theme, domain),
        if (_timeline.isNotEmpty) ...[
          const SizedBox(height: 28),
          StoryTimelineSection(
            currentArticle: article,
            timeline: _timeline,
            onSelectArticle: (a) {
              if (a.id == article.id) return;
              if (AppScope.maybeOf(context) != null) {
                Navigator.of(context).pushReplacementNamed(articleRoutePath(a.id), arguments: a);
              } else {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => ArticleScreen(
                    article: a,
                    repository: widget.repository,
                    authRepository: widget.authRepository,
                  ),
                ));
              }
            },
          ),
        ],
        const SizedBox(height: 28),
        AskAiSection(article: article),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSimpleWordsCard(BuildContext context, ThemeData theme) {
    final accent = AppTheme.accentOf(context);
    final languages = SimpleWordsLanguage.availableFor(article);
    final text = _language == 'en'
        ? (article.simpleExplanation.isNotEmpty ? article.simpleExplanation : article.summary)
        : (article.simpleExplanationTranslations[_language] ?? article.simpleExplanation);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: AppTheme.isDark(context) ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb_outline_rounded, color: accent, size: 20),
            const SizedBox(width: 8),
            Text('In simple words', style: AppTheme.display(18, color: theme.colorScheme.onSurface)),
          ]),
          if (languages.length > 1) ...[
            const SizedBox(height: 12),
            SegmentedButton<String>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: accent,
                selectedForegroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              segments: languages
                  .map((l) => ButtonSegment<String>(
                        value: l.code,
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(l.label)),
                      ))
                  .toList(),
              selected: {_language},
              onSelectionChanged: (s) => setState(() => _language = s.first),
            ),
          ],
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              text,
              key: ValueKey(_language),
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17.5, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(BuildContext context, ThemeData theme, String domain) {
    final hasLink = domain.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Source', style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            [
              if (article.sourceName.isNotEmpty) article.sourceName,
              if (hasLink) domain,
            ].join('  ·  '),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasLink ? _openOriginal : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                hasLink ? 'Read original on $domain' : 'Original link unavailable',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 18, height: 3, color: AppTheme.accentOf(context)),
      const SizedBox(width: 10),
      Text(label, style: AppTheme.display(20, color: Theme.of(context).colorScheme.onSurface)),
    ]);
  }
}

class _PlainTag extends StatelessWidget {
  final String label;
  const _PlainTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: AppTheme.kicker(color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  const _CircleButton({required this.icon, required this.tooltip, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: (dark ? AppTheme.ink : Colors.white).withValues(alpha: 0.88),
        foregroundColor: color ?? (dark ? AppTheme.darkInk : AppTheme.ink),
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}
