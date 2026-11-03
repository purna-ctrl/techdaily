import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/date_utils.dart';
import '../models/article.dart';
import 'article_image.dart';

/// TechDaily wordmark: orange "TD" tile + name.
class TechDailyWordmark extends StatelessWidget {
  final double size;
  const TechDailyWordmark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 1.35,
          height: size * 1.35,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF5A1F), Color(0xFFFF3B4E), Color(0xFF8B5CF6)],
              stops: [0, 0.55, 1],
            ),
            borderRadius: BorderRadius.circular(size * 0.32),
            boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.35), blurRadius: size * 0.8)],
          ),
          child: Text(
            'TD',
            style: AppTheme.display(size * 0.68, color: Colors.white, height: 1),
          ),
        ),
        SizedBox(width: size * 0.4),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Tech'),
            TextSpan(text: 'Daily', style: TextStyle(color: AppTheme.isDark(context) ? const Color(0xFFFF8255) : AppTheme.accent)),
          ]),
          semanticsLabel: 'TechDaily',
          style: AppTheme.display(size, color: fg, height: 1),
        ),
      ],
    );
  }
}

/// Small category pill (the only place category colours appear).
class CategoryTag extends StatelessWidget {
  final String category;
  final bool onImage;
  const CategoryTag({super.key, required this.category, this.onImage = false});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.getCategoryAccent(category, isDark: AppTheme.isDark(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: onImage ? Colors.black.withValues(alpha: 0.45) : c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            category.isEmpty ? 'Tech' : category,
            style: AppTheme.kicker(
              size: 11,
              color: onImage ? Colors.white : Color.lerp(c, Theme.of(context).colorScheme.onSurface, 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// "LIVE"/"Breaking" pill.
class BreakingTag extends StatelessWidget {
  const BreakingTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.live, borderRadius: BorderRadius.circular(6)),
      child: Text('Breaking', style: AppTheme.kicker(color: Colors.white)),
    );
  }
}

/// "Source · 2h ago" line.
class StoryMeta extends StatelessWidget {
  final Article article;
  final Color? color;
  final bool showReadTime;
  const StoryMeta({super.key, required this.article, this.color, this.showReadTime = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.mutedOf(context);
    final parts = <String>[
      if (article.sourceName.isNotEmpty) article.sourceName,
      AppDateUtils.formatRelativeTime(article.publishedAt),
      if (showReadTime) '${article.readingTimeMinutes} min read',
    ];
    return Text(
      parts.join('  ·  '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTheme.numeric(12.5, weight: FontWeight.w500, color: c),
    );
  }
}

/// Section heading with optional action.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? leading;
  const SectionTitle({super.key, required this.title, this.actionLabel, this.onAction, this.leading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(title, style: AppTheme.display(22, color: theme.colorScheme.onSurface)),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel!),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Big image-led lead story with gradient overlay headline.
class LeadStoryCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  final Widget? trailing;
  const LeadStoryCard({super.key, required this.article, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final aspect = width < 600 ? 4 / 5 : 16 / 9;
    return Semantics(
      button: true,
      label: article.title,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: aspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'article-image-${article.id}',
                  child: ArticleImage(article: article, iconSize: 56),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x33000000), Color(0xE6000000)],
                      stops: [0.3, 0.55, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (article.isBreaking) const BreakingTag(),
                        CategoryTag(category: article.category, onImage: true),
                      ]),
                      const SizedBox(height: 12),
                      Text(
                        article.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.display(width < 400 ? 26 : 30, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: StoryMeta(
                              article: article,
                              color: Colors.white.withValues(alpha: 0.82),
                              showReadTime: true,
                            ),
                          ),
                          ?trailing,
                        ],
                      ),
                    ],
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

/// Horizontal "Trending" rail with large numerals.
class TrendingRail extends StatelessWidget {
  final List<Article> articles;
  final ValueChanged<Article> onTap;
  const TrendingRail({super.key, required this.articles, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.accentOf(context);
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: articles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final a = articles[i];
          return SizedBox(
            width: 272,
            child: Material(
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppTheme.borderOf(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(a),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: AppTheme.numeric(44, family: AppTheme.displayFont, color: accent)
                            .copyWith(height: 1),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CategoryTag(category: a.category),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                a.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.display(16, color: theme.colorScheme.onSurface, height: 1.2),
                              ),
                            ),
                            StoryMeta(article: a),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Row card: text left, square thumbnail right.
class CompactStoryTile extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  final int? number;
  const CompactStoryTile({super.key, required this.article, required this.onTap, this.number});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (number != null) ...[
              SizedBox(
                width: 30,
                child: Text(
                  '$number',
                  style: AppTheme.numeric(22, family: AppTheme.displayFont, color: AppTheme.accentOf(context)),
                ),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryTag(category: article.category),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.display(16.5, color: theme.colorScheme.onSurface, height: 1.22),
                  ),
                  const SizedBox(height: 6),
                  StoryMeta(article: article),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 92,
              height: 92,
              child: ArticleImage(
                article: article,
                iconSize: 26,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical image card used in category sections.
class ImageStoryCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  const ImageStoryCard({super.key, required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ArticleImage(article: article, iconSize: 36),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.display(18, color: theme.colorScheme.onSurface, height: 1.2),
                  ),
                  if (article.simpleExplanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.simpleExplanation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 10),
                  StoryMeta(article: article, showReadTime: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ink-coloured "Daily Brief" call-to-action card.
class DailyBriefCard extends StatelessWidget {
  final int storyCount;
  final VoidCallback onTap;
  const DailyBriefCard({super.key, required this.storyCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final bg = dark ? AppTheme.paper : AppTheme.ink;
    final fg = dark ? AppTheme.ink : AppTheme.paper;
    final minutes = (storyCount * 0.4).ceil().clamp(1, 15);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.bolt_rounded, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 6),
                      Text('Daily Brief', style: AppTheme.kicker(color: AppTheme.accent, size: 12)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'Today in tech, in simple words',
                      style: AppTheme.display(21, color: fg, height: 1.15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$storyCount stories  ·  $minutes min',
                      style: AppTheme.numeric(13, weight: FontWeight.w500, color: fg.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Friendly empty / error state with a retry button.
class FriendlyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;
  const FriendlyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.refresh_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.accentOf(context).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: AppTheme.accentOf(context)),
              ),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center,
                  style: AppTheme.display(22, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
