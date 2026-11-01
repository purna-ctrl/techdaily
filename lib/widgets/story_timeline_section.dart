import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_utils.dart';
import '../models/article.dart';
import '../services/story_timeline_service.dart';
import 'source_badge.dart';

class StoryTimelineSection extends StatelessWidget {
  final Article currentArticle;
  final List<TimelineEntry> timeline;
  final void Function(Article) onSelectArticle;

  const StoryTimelineSection({
    super.key,
    required this.currentArticle,
    required this.timeline,
    required this.onSelectArticle,
  });

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151B) : const Color(0xFFF7F5F0),
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
              Icon(
                Icons.timeline_rounded,
                size: 18,
                color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'DEVELOPING STORY TIMELINE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chronological progression across related wires in the 48-hour window',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),

          // Timeline steps
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: timeline.length,
            itemBuilder: (context, index) {
              final entry = timeline[index];
              final isCurrent = entry.article.id == currentArticle.id;
              final isLast = index == timeline.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dot and connector column
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent
                                ? (isDark ? AppTheme.cyberCyan : theme.colorScheme.primary)
                                : (isDark ? const Color(0xFF2A2A33) : const Color(0xFFD6D1C4)),
                            border: Border.all(
                              color: isCurrent ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isDark ? const Color(0xFF2A2A33) : const Color(0xFFE3DFD5),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: isCurrent ? null : () => onSelectArticle(entry.article),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? (isDark
                                      ? AppTheme.cyberCyan.withValues(alpha: 0.08)
                                      : theme.colorScheme.primary.withValues(alpha: 0.06))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: isCurrent
                                  ? Border.all(
                                      color: isDark
                                          ? AppTheme.cyberCyan.withValues(alpha: 0.3)
                                          : theme.colorScheme.primary.withValues(alpha: 0.25),
                                    )
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      entry.stage.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                        color: isCurrent
                                            ? (isDark ? AppTheme.cyberCyan : theme.colorScheme.primary)
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '•  ${AppDateUtils.formatRelativeTime(entry.timestamp)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: const Text(
                                          'CURRENT VIEW',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.article.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SourceBadge(sourceName: entry.article.sourceName, fontSize: 9),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
