import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_utils.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/story_comparison_service.dart';
import '../widgets/source_badge.dart';
import 'article_screen.dart';

class CompareStoriesScreen extends StatelessWidget {
  final Article articleA;
  final Article articleB;
  final ArticleRepository repository;
  final AuthRepository? authRepository;

  const CompareStoriesScreen({
    super.key,
    required this.articleA,
    required this.articleB,
    required this.repository,
    this.authRepository,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    final comparisonService = StoryComparisonService();
    final result = comparisonService.compare(articleA, articleB);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STORY COMPARISON',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              'Cross-wire factual analysis',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Factual Takeaway Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF15151B) : const Color(0xFFEFECE4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppTheme.cyberCyan.withValues(alpha: 0.4) : theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.compare_arrows_rounded,
                          size: 18,
                          color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SYNTHESIS TAKEAWAY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.takeawaySummary,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Side-by-side or stacked stories
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildStoryCard(context, articleA, 'PERSPECTIVE A', theme, isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStoryCard(context, articleB, 'PERSPECTIVE B', theme, isDark)),
                  ],
                )
              else ...[
                _buildStoryCard(context, articleA, 'PERSPECTIVE A', theme, isDark),
                const SizedBox(height: 16),
                _buildStoryCard(context, articleB, 'PERSPECTIVE B', theme, isDark),
              ],
              const SizedBox(height: 20),

              // Key differences section
              _buildDifferencesSection(result, theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryCard(
    BuildContext context,
    Article article,
    String tag,
    ThemeData theme,
    bool isDark,
  ) {
    final catAccent = AppTheme.getCategoryAccent(article.category, isDark: isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.cyberCyan : theme.colorScheme.primary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              SourceBadge(sourceName: article.sourceName, fontSize: 9.5),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            article.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                article.category.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: catAccent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•  ${AppDateUtils.formatRelativeTime(article.publishedAt)}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            article.summary,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArticleScreen(
                      article: article,
                      repository: repository,
                      authRepository: authRepository,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('READ FULL DISPATCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifferencesSection(
    StoryComparisonResult result,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10141F) : const Color(0xFFF7F5F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY DIFFERENCES IN REPORTING FOCUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Points reported primarily by ${articleA.sourceName}:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          ...result.distinctPointsA.map(
            (p) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary)),
                  Expanded(child: Text(p, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.85)))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Points reported primarily by ${articleB.sourceName}:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          ...result.distinctPointsB.map(
            (p) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary)),
                  Expanded(child: Text(p, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.85)))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
