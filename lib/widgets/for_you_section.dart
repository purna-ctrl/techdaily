import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../models/user_preferences.dart';
import 'article_card.dart';
import 'section_header.dart';

class ForYouSection extends StatelessWidget {
  final List<Article> allArticles;
  final UserPreferences preferences;
  final Set<String> savedIds;
  final String userId;
  final bool isWide;
  final void Function(Article) onArticleTap;
  final void Function(Article) onToggleSave;
  final VoidCallback onCustomizeTopics;

  const ForYouSection({
    super.key,
    required this.allArticles,
    required this.preferences,
    required this.savedIds,
    required this.userId,
    required this.isWide,
    required this.onArticleTap,
    required this.onToggleSave,
    required this.onCustomizeTopics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // If no topics are explicitly followed yet, show the customization invite
    if (preferences.selectedCategories.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF10141F) : const Color(0xFFEFECE4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark
                ? AppTheme.cyberCyan.withValues(alpha: 0.3)
                : theme.colorScheme.primary.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.cyberCyan.withValues(alpha: 0.15)
                    : theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 22,
                color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personalize your feed',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Choose the technology topics that matter to you to get a tailored daily brief.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onCustomizeTopics,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              child: const Text('CUSTOMIZE'),
            ),
          ],
        ),
      );
    }

    // User has followed topics: filter articles
    final followedLower = preferences.selectedCategories.map((c) => c.toLowerCase()).toSet();
    final matching = allArticles
        .where((a) => followedLower.contains(a.category.toLowerCase()))
        .toList();

    if (matching.isEmpty) {
      return const SizedBox.shrink();
    }

    final topForYou = matching.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(
                title: 'FOR YOU',
                subtitle: 'Curated based on your followed topics (${preferences.selectedCategories.length} active).',
                icon: Icons.person_pin_rounded,
              ),
            ),
            TextButton.icon(
              onPressed: onCustomizeTopics,
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('EDIT TOPICS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Personalized items
        ...topForYou.map((article) {
          final catAccent = AppTheme.getCategoryAccent(article.category, isDark: isDark);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reason badge: "Because you follow [Category]"
                Container(
                  margin: const EdgeInsets.only(bottom: 4, left: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: catAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: catAccent.withValues(alpha: 0.3),
                      width: 0.7,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 11, color: catAccent),
                      const SizedBox(width: 4),
                      Text(
                        'BECAUSE YOU FOLLOW ${article.category.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: catAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                ArticleCard(
                  article: article,
                  isSaved: savedIds.contains(article.id),
                  variant: ArticleCardVariant.standard,
                  onTap: () => onArticleTap(article),
                  onToggleSave: () => onToggleSave(article),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
