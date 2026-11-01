import '../models/article.dart';
import '../models/weekly_recap.dart';
import 'article_ranking_service.dart';

class WeeklyRecapService {
  final IArticleRankingService rankingService;

  WeeklyRecapService({IArticleRankingService? rankingService})
      : rankingService = rankingService ?? TransparentArticleRankingService();

  WeeklyRecap generateWeeklyRecap(List<Article> allArticles, {DateTime? relativeTo}) {
    final now = relativeTo ?? DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    // Filter to last 7 days; if collection is smaller or sparse, take up to 20 most recent
    var recent = allArticles.where((a) => a.publishedAt.isAfter(weekAgo)).toList();
    if (recent.length < 5) {
      recent = List.of(allArticles);
      recent.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      recent = recent.take(15).toList();
    }

    // Top stories ranked by transparent score
    final ranked = rankingService.rankArticles(recent, limit: 5);

    // Group by sector
    final breakdown = <String, List<Article>>{};
    for (final article in recent) {
      breakdown.putIfAbsent(article.category, () => []).add(article);
    }

    // Derive major milestones from top stories
    final milestones = <String>[];
    for (final art in ranked) {
      if (art.whatHappened.isNotEmpty) {
        milestones.add('${art.category.toUpperCase()}: ${art.whatHappened}');
      } else if (art.keyPoints.isNotEmpty) {
        milestones.add('${art.category.toUpperCase()}: ${art.keyPoints.first}');
      } else {
        milestones.add('${art.category.toUpperCase()}: ${art.title}');
      }
    }

    // Derive what to watch next week strictly from confirmed article points
    final whatToWatch = <String>[];
    final forwardKeywords = ['will', 'upcoming', 'next', 'roadmap', 'scheduled', 'expected', 'plans'];
    for (final art in recent) {
      for (final point in art.keyPoints) {
        final lp = point.toLowerCase();
        if (forwardKeywords.any((k) => lp.contains(k))) {
          final entry = '${art.category}: $point';
          if (!whatToWatch.contains(entry)) {
            whatToWatch.add(entry);
          }
        }
      }
      if (whatToWatch.length >= 4) break;
    }

    // If no explicit forward statements in text, state factual observation
    if (whatToWatch.isEmpty) {
      whatToWatch.add('Upcoming developments following this week\'s verified releases across ${breakdown.keys.take(3).join(", ")}.');
    }

    final startDate = recent.isNotEmpty
        ? recent.map((a) => a.publishedAt).reduce((a, b) => a.isBefore(b) ? a : b)
        : weekAgo;
    final endDate = recent.isNotEmpty
        ? recent.map((a) => a.publishedAt).reduce((a, b) => a.isAfter(b) ? a : b)
        : now;

    return WeeklyRecap(
      startDate: startDate,
      endDate: endDate,
      title: 'WEEK IN REVIEW • EXECUTIVE SYNTHESIS',
      topStories: ranked,
      sectorBreakdown: breakdown,
      majorMilestones: milestones.take(5).toList(),
      whatToWatchNextWeek: whatToWatch.take(4).toList(),
    );
  }
}
