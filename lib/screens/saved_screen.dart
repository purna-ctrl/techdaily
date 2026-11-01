import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../models/auth_user.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../widgets/story_widgets.dart';
import 'article_screen.dart';
import 'auth_screen.dart';

/// Saved stories. Works for guests (stored on this device) and for signed-in
/// readers (synced; guest saves are merged in on sign-in).
class SavedScreen extends StatefulWidget {
  final ArticleRepository repository;
  final AuthRepository authRepository;

  const SavedScreen({super.key, required this.repository, required this.authRepository});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final Map<String, Article> _cache = {};
  Set<String> _loadingFor = {};
  bool _error = false;

  @override
  void initState() {
    super.initState();
    widget.repository.savedArticleIdsNotifier.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.repository.savedArticleIdsNotifier.removeListener(_sync);
    super.dispose();
  }

  Future<void> _sync() async {
    final ids = widget.repository.savedArticleIdsNotifier.value;
    final missing = ids.where((id) => !_cache.containsKey(id)).toList();
    if (missing.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    setState(() {
      _loadingFor = missing.toSet();
      _error = false;
    });
    try {
      final fetched = await widget.repository.getArticlesByIds(missing);
      for (final a in fetched) {
        _cache[a.id] = a;
      }
      if (mounted) setState(() => _loadingFor = {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingFor = {};
          _error = true;
        });
      }
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

  void _signIn() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AuthScreen(authRepository: widget.authRepository),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<AuthUser?>(
          stream: widget.authRepository.authStateChanges,
          initialData: widget.authRepository.currentUser,
          builder: (context, authSnap) {
            final user = authSnap.data;
            return ValueListenableBuilder<Set<String>>(
              valueListenable: widget.repository.savedArticleIdsNotifier,
              builder: (context, ids, _) {
                final articles = ids.map((id) => _cache[id]).whereType<Article>().toList()
                  ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                        child: Row(
                          children: [
                            Text('Saved', style: AppTheme.display(28, color: theme.colorScheme.onSurface)),
                            const Spacer(),
                            if (ids.isNotEmpty)
                              Text(
                                '${ids.length} ${ids.length == 1 ? 'story' : 'stories'}',
                                style: AppTheme.numeric(14, color: AppTheme.mutedOf(context)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (user == null)
                      SliverToBoxAdapter(child: _guestBanner(theme)),
                    if (ids.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: FriendlyState(
                          icon: Icons.bookmark_border_rounded,
                          title: 'No saved stories yet',
                          message: 'Tap the bookmark on any story to keep it here for later.',
                        ),
                      )
                    else if (_error && articles.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: FriendlyState(
                          icon: Icons.wifi_off_rounded,
                          title: 'Couldn’t load saved stories',
                          message: 'Check your connection and try again.',
                          actionLabel: 'Try again',
                          onAction: _sync,
                        ),
                      )
                    else ...[
                      SliverList.builder(
                        itemCount: articles.length,
                        itemBuilder: (context, i) {
                          final a = articles[i];
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: Dismissible(
                                key: ValueKey('saved-${a.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  color: AppTheme.live.withValues(alpha: 0.12),
                                  child: const Icon(Icons.delete_outline_rounded, color: AppTheme.live),
                                ),
                                onDismissed: (_) => widget.repository
                                    .removeSavedArticle(user?.uid ?? '', a.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: CompactStoryTile(article: a, onTap: () => _open(a)),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (_loadingFor.isNotEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _guestBanner(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAltOf(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_iphone_rounded, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Saved on this device. Sign in to keep them on all your devices.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
              TextButton(onPressed: _signIn, child: const Text('Sign in')),
            ],
          ),
        ),
      ),
    );
  }
}
