import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_utils.dart';
import '../models/article.dart';
import 'section_header.dart';
import 'source_badge.dart';

class TrendingNowSection extends StatelessWidget {
  final List<Article> articles;
  final Set<String> savedIds;
  final void Function(Article) onArticleTap;
  final void Function(Article) onToggleSave;

  const TrendingNowSection({
    super.key,
    required this.articles,
    required this.savedIds,
    required this.onArticleTap,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'TRENDING NOW',
          subtitle: 'Stories gaining the most momentum across the technology landscape.',
          icon: Icons.local_fire_department_rounded,
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: articles.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.8,
            color: isDark ? const Color(0xFF1E2433) : const Color(0xFFE3DFD5),
          ),
          itemBuilder: (context, index) {
            final article = articles[index];
            final rankNumber = (index + 1).toString().padLeft(2, '0');
            final isSaved = savedIds.contains(article.id);
            final catAccent = AppTheme.getCategoryAccent(article.category, isDark: isDark);

            return _TrendingItemRow(
              rank: rankNumber,
              article: article,
              catAccent: catAccent,
              isSaved: isSaved,
              isDark: isDark,
              onTap: () => onArticleTap(article),
              onToggleSave: () => onToggleSave(article),
            );
          },
        ),
      ],
    );
  }
}

class _TrendingItemRow extends StatefulWidget {
  final String rank;
  final Article article;
  final Color catAccent;
  final bool isSaved;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const _TrendingItemRow({
    required this.rank,
    required this.article,
    required this.catAccent,
    required this.isSaved,
    required this.isDark,
    required this.onTap,
    required this.onToggleSave,
  });

  @override
  State<_TrendingItemRow> createState() => _TrendingItemRowState();
}

class _TrendingItemRowState extends State<_TrendingItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark ? const Color(0xFF1E1E26) : const Color(0xFFEFECE4))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank indicator (01, 02, ...)
              Container(
                width: 38,
                alignment: Alignment.topLeft,
                child: Text(
                  widget.rank,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: widget.isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Content column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category & Reading Time Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.catAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: widget.catAccent.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            widget.article.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: widget.catAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.article.readingTimeMinutes} min read',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Headline
                    Text(
                      widget.article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: _isHovered
                            ? (widget.isDark ? AppTheme.cyberCyan : theme.colorScheme.primary)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Footer with Source & Time
                    Row(
                      children: [
                        SourceBadge(sourceName: widget.article.sourceName, fontSize: 9.5),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppDateUtils.formatRelativeTime(widget.article.publishedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bookmark action button
              IconButton(
                icon: Icon(
                  widget.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 20,
                  color: widget.isSaved
                      ? (widget.isDark ? AppTheme.cyberCyan : theme.colorScheme.primary)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                tooltip: widget.isSaved ? 'Remove from Saved' : 'Save Story',
                onPressed: widget.onToggleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
