import 'package:flutter/material.dart';
import '../core/utils/date_utils.dart';
import '../models/article.dart';
import 'source_badge.dart';

import '../core/theme/app_theme.dart';

enum ArticleCardVariant {
  standard,
  lead,
  compact,
}

class ArticleCard extends StatefulWidget {
  final Article article;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;
  final ArticleCardVariant variant;

  const ArticleCard({
    super.key,
    required this.article,
    required this.isSaved,
    required this.onTap,
    required this.onToggleSave,
    this.variant = ArticleCardVariant.standard,
  });

  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.variant == ArticleCardVariant.lead) {
      return _buildLeadCard(context, theme, isDark);
    } else if (widget.variant == ArticleCardVariant.compact) {
      return _buildCompactCard(context, theme, isDark);
    }
    return _buildStandardCard(context, theme, isDark);
  }

  Widget _buildLeadCard(BuildContext context, ThemeData theme, bool isDark) {
    final catAccent = AppTheme.getCategoryAccent(widget.article.category, isDark: isDark);
    final isWide = MediaQuery.of(context).size.width >= 720;

    final contentPadding = EdgeInsets.all(isWide ? 22 : 18);
    final contentWidget = Padding(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeaderRow(theme, catAccent, isDark),
          const SizedBox(height: 8),
          Text(
            widget.article.title,
            style: theme.textTheme.displayMedium?.copyWith(
              fontSize: isWide ? 24 : 21,
              fontWeight: FontWeight.w800,
              height: 1.22,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.article.summary,
            maxLines: isWide ? 4 : null,
            overflow: isWide ? TextOverflow.ellipsis : null,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 12),
          _buildSimpleWordsCallout(theme, isDark),
          const SizedBox(height: 12),
          _buildFooter(theme),
        ],
      ),
    );

    Widget cardBody;
    if (isWide && widget.article.imageUrl != null) {
      cardBody = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 12,
            child: AspectRatio(
              aspectRatio: 16 / 11,
              child: _buildImage(height: double.infinity, width: double.infinity),
            ),
          ),
          Expanded(
            flex: 13,
            child: contentWidget,
          ),
        ],
      );
    } else {
      cardBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.article.imageUrl != null)
            _buildImage(height: 250, width: double.infinity),
          contentWidget,
        ],
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF15151B) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isHovered
                ? catAccent.withValues(alpha: 0.6)
                : (isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5)),
            width: _isHovered ? 1.2 : 0.8,
          ),
          boxShadow: _isHovered && isDark
              ? [
                  BoxShadow(
                    color: catAccent.withValues(alpha: 0.14),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: cardBody,
        ),
      ),
    );
  }

  Widget _buildStandardCard(BuildContext context, ThemeData theme, bool isDark) {
    final catAccent = AppTheme.getCategoryAccent(widget.article.category, isDark: isDark);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF15151B) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _isHovered
                ? catAccent.withValues(alpha: 0.6)
                : (isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5)),
            width: _isHovered ? 1.2 : 0.8,
          ),
          boxShadow: _isHovered && isDark
              ? [
                  BoxShadow(
                    color: catAccent.withValues(alpha: 0.12),
                    blurRadius: 14,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderRow(theme, catAccent, isDark),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.article.title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.28,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.article.summary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.article.imageUrl != null) ...[
                      const SizedBox(width: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _buildImage(height: 88, width: 96),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _buildSimpleWordsCallout(theme, isDark),
                const SizedBox(height: 10),
                _buildFooter(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context, ThemeData theme, bool isDark) {
    final catAccent = AppTheme.getCategoryAccent(widget.article.category, isDark: isDark);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF15151B) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _isHovered
                ? catAccent.withValues(alpha: 0.6)
                : (isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5)),
            width: _isHovered ? 1.1 : 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderRow(theme, catAccent, isDark),
                const SizedBox(height: 6),
                Text(
                  widget.article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFooter(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(ThemeData theme, Color catAccent, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: catAccent.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: catAccent.withValues(alpha: isDark ? 0.4 : 0.3),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  widget.article.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: catAccent,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${widget.article.readingTimeMinutes} MIN READ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            icon: Icon(
              widget.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size: 20,
              color: widget.isSaved
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            padding: EdgeInsets.zero,
            tooltip: widget.isSaved ? 'Remove bookmark' : 'Bookmark article',
            onPressed: widget.onToggleSave,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleWordsCallout(ThemeData theme, bool isDark) {
    final boxBg = isDark ? const Color(0xFF151821) : const Color(0xFFEFECE4);
    final borderColor = isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 13,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 5),
              Text(
                'IN SIMPLE WORDS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            widget.article.simpleExplanation,
            style: TextStyle(
              fontSize: 12,
              height: 1.42,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      children: [
        SourceBadge(sourceName: widget.article.sourceName, fontSize: 10),
        const SizedBox(width: 8),
        Text(
          '•',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
        const SizedBox(width: 8),
        Text(
          AppDateUtils.formatRelativeTime(widget.article.publishedAt),
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        if (widget.article.aiProcessed) ...[
          const SizedBox(width: 8),
          Text(
            '•',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 0.6,
              ),
            ),
            child: Text(
              'AI SYNTHESIS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImage({required double height, required double width}) {
    return AnimatedScale(
      scale: _isHovered ? 1.025 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: Image.network(
        widget.article.imageUrl!,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            width: width,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.newspaper_rounded,
                color: Theme.of(context).colorScheme.outline,
                size: height > 100 ? 40 : 24,
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            width: width,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}
