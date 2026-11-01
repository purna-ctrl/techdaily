import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/article_ranking_service.dart';
import '../services/share_service.dart';
import '../widgets/article_image.dart';
import '../widgets/skeleton.dart';
import '../widgets/story_widgets.dart';
import 'article_screen.dart';

/// Trims [text] to at most [maxWords] words, adding an ellipsis if cut.
String trimToWords(String text, {int maxWords = 60}) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length <= maxWords) return words.join(' ');
  return '${words.take(maxWords).join(' ')}…';
}

/// Inshorts-style vertical swipe: one story per screen.
class QuickReadsScreen extends StatefulWidget {
  final ArticleRepository repository;
  final AuthRepository? authRepository;

  const QuickReadsScreen({super.key, required this.repository, this.authRepository});

  @override
  State<QuickReadsScreen> createState() => _QuickReadsScreenState();
}

class _QuickReadsScreenState extends State<QuickReadsScreen> {
  final PageController _pageController = PageController();
  List<Article> _articles = [];
  bool _loading = true;
  bool _error = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final all = await widget.repository.getArticles();
      final ranked = TransparentArticleRankingService().rankArticles(all);
      if (!mounted) return;
      setState(() {
        _articles = ranked;
        _loading = false;
        _page = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _open(Article a) {
    if (AppScope.maybeOf(context) != null) {
      openArticle(context, a);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArticleScreen(article: a, repository: widget.repository, authRepository: widget.authRepository),
      ));
    }
  }

  Future<void> _toggleSave(Article a) async {
    final uid = widget.authRepository?.currentUser?.uid ?? '';
    await widget.repository.toggleSaveArticle(uid, a.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quick Reads',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(24, color: theme.colorScheme.onSurface),
                    ),
                  ),
                  if (_articles.isNotEmpty)
                    Text(
                      '${_page + 1} / ${_articles.length}',
                      style: AppTheme.numeric(14, color: AppTheme.mutedOf(context)),
                    ),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _load,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Shimmer(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(children: [
            Expanded(flex: 5, child: SkeletonBox(height: double.infinity, radius: 24)),
            SizedBox(height: 16),
            SkeletonBox(height: 24),
            SizedBox(height: 10),
            SkeletonBox(height: 24),
            SizedBox(height: 20),
            Expanded(flex: 3, child: SkeletonBox(height: double.infinity)),
          ]),
        ),
      );
    }
    if (_error || _articles.isEmpty) {
      return FriendlyState(
        icon: _error ? Icons.wifi_off_rounded : Icons.bolt_rounded,
        title: _error ? 'Can’t load stories' : 'No quick reads yet',
        message: _error
            ? 'Check your connection and try again.'
            : 'New stories arrive through the day. Check back soon.',
        actionLabel: 'Try again',
        onAction: _load,
      );
    }
    return ValueListenableBuilder<Set<String>>(
      valueListenable: widget.repository.savedArticleIdsNotifier,
      builder: (context, saved, _) => PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _articles.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) => _QuickReadCard(
          article: _articles[i],
          isSaved: saved.contains(_articles[i].id),
          isLast: i == _articles.length - 1,
          onReadMore: () => _open(_articles[i]),
          onSave: () => _toggleSave(_articles[i]),
        ),
      ),
    );
  }
}

class _QuickReadCard extends StatelessWidget {
  final Article article;
  final bool isSaved;
  final bool isLast;
  final VoidCallback onReadMore;
  final VoidCallback onSave;

  const _QuickReadCard({
    required this.article,
    required this.isSaved,
    required this.isLast,
    required this.onReadMore,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = trimToWords(
      article.simpleExplanation.isNotEmpty ? article.simpleExplanation : article.summary,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 9,
                  child: Stack(fit: StackFit.expand, children: [
                    ArticleImage(article: article, iconSize: 52),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: Wrap(spacing: 8, children: [
                        if (article.isBreaking) const BreakingTag(),
                        CategoryTag(category: article.category, onImage: true),
                      ]),
                    ),
                  ]),
                ),
                Expanded(
                  flex: 11,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.display(21, color: theme.colorScheme.onSurface, height: 1.18),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Text(
                            text,
                            overflow: TextOverflow.fade,
                            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15.5, height: 1.55),
                          ),
                        ),
                        const SizedBox(height: 6),
                        StoryMeta(article: article),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: onReadMore,
                                child: const Text('Read more'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: isSaved ? 'Remove from saved' : 'Save',
                              onPressed: onSave,
                              icon: Icon(
                                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: isSaved ? AppTheme.accentOf(context) : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Builder(
                              builder: (btn) => IconButton.outlined(
                                tooltip: 'Share',
                                onPressed: () => const ShareService().shareArticle(btn, article),
                                icon: const Icon(Icons.ios_share_rounded),
                              ),
                            ),
                          ],
                        ),
                        if (!isLast)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.keyboard_arrow_up_rounded, color: AppTheme.mutedOf(context), size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
