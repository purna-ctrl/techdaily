import '../core/constants/trusted_sources.dart';
import '../models/article.dart';

abstract class IArticleRankingService {
  List<Article> rankArticles(
    List<Article> articles, {
    List<String>? userInterests,
    int? limit,
  });

  double calculateScore(
    Article article, {
    List<String>? userInterests,
    DateTime? relativeTo,
  });

  Map<String, dynamic> explainScore(
    Article article, {
    List<String>? userInterests,
    DateTime? relativeTo,
  });

  List<Article> getTrendingArticles(
    List<Article> articles, {
    int limit = 5,
    DateTime? relativeTo,
  });
}

class TransparentArticleRankingService implements IArticleRankingService {
  @override
  double calculateScore(
    Article article, {
    List<String>? userInterests,
    DateTime? relativeTo,
  }) {
    final now = relativeTo ?? DateTime.now();
    final hoursSincePub = now.difference(article.publishedAt).inHours.clamp(0, 120);

    // 1. Recency Score (max 60 points; degrades gradually over 72 hours)
    final recencyScore = (60.0 - (hoursSincePub * 0.8)).clamp(0.0, 60.0);

    // 2. Breaking News Boost (+50 points)
    final breakingScore = article.isBreaking ? 50.0 : 0.0;

    // 3. Source Trust Boost (+20 points for verified official sources)
    final isTrustedSource = TrustedSourcesConfig.isTrusted(article.sourceName);
    final trustScore = isTrustedSource ? 20.0 : 5.0;

    // 4. User Interest Personalization Boost (+35 points)
    double interestScore = 0.0;
    if (userInterests != null && userInterests.isNotEmpty) {
      final matches = userInterests
          .any((cat) => cat.toLowerCase() == article.category.toLowerCase());
      if (matches) {
        interestScore = 35.0;
      }
    }

    // 5. AI Synthesis Verification (+10 points)
    final aiScore = article.aiProcessed ? 10.0 : 0.0;

    return recencyScore + breakingScore + trustScore + interestScore + aiScore;
  }

  @override
  Map<String, dynamic> explainScore(
    Article article, {
    List<String>? userInterests,
    DateTime? relativeTo,
  }) {
    final now = relativeTo ?? DateTime.now();
    final hoursSincePub = now.difference(article.publishedAt).inHours.clamp(0, 120);
    final recency = (60.0 - (hoursSincePub * 0.8)).clamp(0.0, 60.0);
    final breaking = article.isBreaking ? 50.0 : 0.0;
    final trust = TrustedSourcesConfig.isTrusted(article.sourceName) ? 20.0 : 5.0;
    final interest = (userInterests != null &&
            userInterests.any(
                (c) => c.toLowerCase() == article.category.toLowerCase()))
        ? 35.0
        : 0.0;
    final ai = article.aiProcessed ? 10.0 : 0.0;
    final total = recency + breaking + trust + interest + ai;

    return {
      'articleId': article.id,
      'totalScore': total,
      'breakdown': {
        'recency': recency,
        'breakingBoost': breaking,
        'sourceTrust': trust,
        'userInterestBoost': interest,
        'aiSynthesisBoost': ai,
      },
      'isBreaking': article.isBreaking,
      'category': article.category,
      'publishedAt': article.publishedAt.toIso8601String(),
    };
  }

  @override
  List<Article> rankArticles(
    List<Article> articles, {
    List<String>? userInterests,
    int? limit,
  }) {
    final scored = articles.map((article) {
      final score = calculateScore(article, userInterests: userInterests);
      return MapEntry(article, score);
    }).toList();

    // Sort descending by score
    scored.sort((a, b) => b.value.compareTo(a.value));

    final sortedArticles = scored.map((e) => e.key).toList();
    if (limit != null && limit > 0) {
      return sortedArticles.take(limit).toList();
    }
    return sortedArticles;
  }

  @override
  List<Article> getTrendingArticles(
    List<Article> articles, {
    int limit = 5,
    DateTime? relativeTo,
  }) {
    final now = relativeTo ?? DateTime.now();
    final scored = articles.map((article) {
      final score = calculateScore(article, userInterests: null, relativeTo: now);
      return MapEntry(article, score);
    }).toList();

    scored.sort((a, b) {
      final cmp = b.value.compareTo(a.value);
      if (cmp != 0) return cmp;
      return b.key.publishedAt.compareTo(a.key.publishedAt);
    });

    return scored.take(limit).map((e) => e.key).toList();
  }
}
