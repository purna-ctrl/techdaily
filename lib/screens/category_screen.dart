import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/categories.dart';
import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../models/user_preferences.dart';
import '../services/offline_cache_service.dart';
import '../core/app_scope.dart';
import '../widgets/follow_topics_sheet.dart';
import '../widgets/story_widgets.dart';
import 'article_screen.dart';

class CategoryScreen extends StatefulWidget {
  final ArticleRepository repository;
  final AuthRepository? authRepository;
  final String? initialCategory;

  const CategoryScreen({
    super.key,
    required this.repository,
    this.authRepository,
    this.initialCategory,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  Category? _selectedCategory;
  final OfflineCacheService _cacheService = OfflineCacheService();
  UserPreferences _preferences = UserPreferences.defaultPreferences();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    if (widget.initialCategory != null) {
      final match = AppCategories.all.firstWhere(
        (c) => c.name.toLowerCase() == widget.initialCategory!.toLowerCase(),
        orElse: () => AppCategories.aiAndMl,
      );
      _selectedCategory = match;
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await _cacheService.getCachedPreferences();
    if (mounted) setState(() => _preferences = prefs);
  }

  Future<void> _toggleCurrentCategoryFollow() async {
    if (_selectedCategory == null) return;
    final catName = _selectedCategory!.name;
    final list = List<String>.from(_preferences.selectedCategories);
    final isFollowing = list.any((c) => c.toLowerCase() == catName.toLowerCase());

    if (isFollowing) {
      list.removeWhere((c) => c.toLowerCase() == catName.toLowerCase());
    } else {
      list.add(catName);
    }

    final updated = _preferences.copyWith(
      selectedCategories: list,
      updatedAt: DateTime.now(),
    );

    await _cacheService.cachePreferences(updated);
    if (mounted) {
      setState(() => _preferences = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!isFollowing ? 'Now following $catName' : 'Unfollowed $catName'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _selectCategory(Category? category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _navigateToArticle(Article article) {
    if (AppScope.maybeOf(context) != null) {
      openArticle(context, article);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleScreen(
          article: article,
          repository: widget.repository,
          authRepository: widget.authRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide =
        MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          _selectedCategory == null ? 'Explore' : _selectedCategory!.name,
          style: AppTheme.display(_selectedCategory == null ? 28 : 22,
              color: theme.colorScheme.onSurface),
        ),
        leading: _selectedCategory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _selectCategory(null),
                tooltip: 'All categories',
              )
            : null,
        actions: [
          if (_selectedCategory != null) ...[
            TextButton.icon(
              onPressed: _toggleCurrentCategoryFollow,
              icon: Icon(
                _preferences.selectedCategories.any((c) =>
                        c.toLowerCase() == _selectedCategory!.name.toLowerCase())
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                size: 16,
              ),
              label: Text(
                _preferences.selectedCategories.any((c) =>
                        c.toLowerCase() == _selectedCategory!.name.toLowerCase())
                    ? 'Following'
                    : 'Follow',
              ),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Customize Topics',
              onPressed: () {
                FollowTopicsSheet.show(
                  context,
                  preferences: _preferences,
                  cacheService: _cacheService,
                  onUpdated: (newPrefs) => setState(() => _preferences = newPrefs),
                );
              },
            ),
          ],
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppConstants.maxContentWidth),
          child: _selectedCategory == null
              ? _buildCategoryGrid(theme, isWide)
              : _buildFilteredArticlesStream(theme),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(ThemeData theme, bool isWide) {
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Browse by topic',
                style: theme.textTheme.bodyMedium,
              ),
              TextButton.icon(
                onPressed: () {
                  FollowTopicsSheet.show(
                    context,
                    preferences: _preferences,
                    cacheService: _cacheService,
                    onUpdated: (newPrefs) => setState(() => _preferences = newPrefs),
                  );
                },
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('Customize'),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 3 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isWide ? 1.4 : 1.15,
          ),
          itemCount: AppCategories.all.length,
          itemBuilder: (context, index) {
            final cat = AppCategories.all[index];
            final catAccent = AppTheme.getCategoryAccent(cat.name, isDark: isDark);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppTheme.borderOf(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _selectCategory(cat),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: catAccent.withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: catAccent.withValues(alpha: isDark ? 0.4 : 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          cat.icon,
                          color: catAccent,
                          size: 22,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        cat.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilteredArticlesStream(ThemeData theme) {
    return StreamBuilder<List<Article>>(
      stream: widget.repository.watchArticlesByCategory(_selectedCategory!.name),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading category articles',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final filteredArticles = snapshot.data ?? [];

        if (filteredArticles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 54,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No articles published in ${_selectedCategory!.name} yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _selectCategory(null),
                    child: const Text('Back to all categories'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: filteredArticles.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_selectedCategory!.description, style: theme.textTheme.bodyMedium),
              );
            }
            final article = filteredArticles[i - 1];
            if (i == 1) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ImageStoryCard(article: article, onTap: () => _navigateToArticle(article)),
              );
            }
            return CompactStoryTile(article: article, onTap: () => _navigateToArticle(article));
          },
        );
      },
    );
  }
}
