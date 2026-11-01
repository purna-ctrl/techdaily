import '../models/article.dart';

class TimelineEntry {
  final Article article;
  final String stage;
  final DateTime timestamp;

  TimelineEntry({
    required this.article,
    required this.stage,
    required this.timestamp,
  });
}

class StoryTimelineService {
  /// Finds related articles for a given article within a 48-hour window.
  /// Returns empty list if no genuine related articles exist (never invents fake events).
  List<TimelineEntry> getTimeline(Article targetArticle, List<Article> allArticles) {
    final targetWords = _extractKeyTerms(targetArticle.title);
    if (targetWords.isEmpty) return [];

    final related = <Article>[];
    for (final candidate in allArticles) {
      if (candidate.id == targetArticle.id) continue;

      // Check if published within 48 hours of target
      final timeDiff = candidate.publishedAt.difference(targetArticle.publishedAt).abs();
      if (timeDiff.inHours > 48) continue;

      // Must match either category or have overlapping keywords
      final candidateWords = _extractKeyTerms(candidate.title);
      final hasWordOverlap = targetWords.any((w) => candidateWords.contains(w));
      final hasSameCategory = candidate.category.toLowerCase() == targetArticle.category.toLowerCase();

      if (hasWordOverlap || (hasSameCategory && timeDiff.inHours <= 24)) {
        related.add(candidate);
      }
    }

    if (related.isEmpty) {
      return []; // Cleanly hide if no related stories in the 48-hour developing window
    }

    // Combine target and related, sort chronologically ascending
    final combined = [targetArticle, ...related];
    combined.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));

    final entries = <TimelineEntry>[];
    for (int i = 0; i < combined.length; i++) {
      final art = combined[i];
      String stage;
      if (i == 0) {
        stage = 'Initial Wire Report';
      } else if (i == combined.length - 1) {
        stage = 'Latest Wire Dispatch';
      } else {
        stage = 'Developing Update';
      }

      entries.add(TimelineEntry(
        article: art,
        stage: stage,
        timestamp: art.publishedAt,
      ));
    }

    return entries;
  }

  Set<String> _extractKeyTerms(String text) {
    const stopWords = {
      'the', 'a', 'an', 'and', 'or', 'in', 'on', 'at', 'to', 'for', 'of', 'with',
      'by', 'from', 'is', 'are', 'was', 'were', 'new', 'how', 'why', 'what', 'after',
      'over', 'under', 'into', 'first', 'more', 'than', 'will', 'says', 'said'
    };

    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !stopWords.contains(w))
        .toSet();
  }
}
